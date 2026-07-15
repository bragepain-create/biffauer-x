create extension if not exists pgcrypto;

drop table if exists game_slots cascade;
drop table if exists owned_skins cascade;
drop table if exists coins cascade;
drop table if exists profiles cascade;

create table users (
  id uuid primary key default gen_random_uuid(),
  username text unique not null,
  pass_hash text not null,
  is_admin boolean not null default false,
  token uuid not null default gen_random_uuid(),
  created timestamptz default now()
);
create table game_slots (
  user_id uuid references users on delete cascade,
  slot int not null check (slot between 0 and 3),
  progress jsonb not null default '{}',
  updated timestamptz default now(),
  primary key (user_id, slot)
);
create table owned_skins (
  user_id uuid references users on delete cascade,
  skin_id text not null,
  primary key (user_id, skin_id)
);
create table coins (
  user_id uuid primary key references users on delete cascade,
  amount int not null default 0
);

alter table users enable row level security;
alter table game_slots enable row level security;
alter table owned_skins enable row level security;
alter table coins enable row level security;

create or replace function game_signup(p_username text, p_password text)
returns json language plpgsql security definer as $fn$
declare u users;
begin
  if exists (select 1 from users where lower(username)=lower(p_username)) then
    return json_build_object('ok', false, 'error', 'Brukernavnet er opptatt');
  end if;
  insert into users(username, pass_hash) values (p_username, crypt(p_password, gen_salt('bf'))) returning * into u;
  insert into coins(user_id) values (u.id);
  return json_build_object('ok', true, 'token', u.token, 'user_id', u.id, 'username', u.username, 'is_admin', u.is_admin);
end $fn$;

create or replace function game_login(p_username text, p_password text)
returns json language plpgsql security definer as $fn$
declare u users;
begin
  select * into u from users where lower(username)=lower(p_username);
  if u.id is null or u.pass_hash <> crypt(p_password, u.pass_hash) then
    return json_build_object('ok', false, 'error', 'Feil brukernavn eller passord');
  end if;
  return json_build_object('ok', true, 'token', u.token, 'user_id', u.id, 'username', u.username, 'is_admin', u.is_admin);
end $fn$;

create or replace function _uid(p_token uuid) returns uuid language sql stable security definer as
$fn$ select id from users where token = p_token $fn$;

create or replace function save_slot(p_token uuid, p_slot int, p_progress jsonb)
returns json language plpgsql security definer as $fn$
declare uid uuid;
begin
  uid := _uid(p_token);
  if uid is null then return json_build_object('ok', false, 'error', 'ugyldig token'); end if;
  insert into game_slots(user_id, slot, progress, updated) values (uid, p_slot, p_progress, now())
    on conflict (user_id, slot) do update set progress = excluded.progress, updated = now();
  return json_build_object('ok', true);
end $fn$;

create or replace function load_data(p_token uuid)
returns json language plpgsql security definer as $fn$
declare uid uuid;
begin
  uid := _uid(p_token);
  if uid is null then return json_build_object('ok', false); end if;
  return json_build_object('ok', true,
    'slots', (select coalesce(json_agg(json_build_object('slot', slot, 'progress', progress)), '[]') from game_slots where user_id = uid),
    'skins', (select coalesce(json_agg(skin_id), '[]') from owned_skins where user_id = uid),
    'coins', (select amount from coins where user_id = uid),
    'is_admin', (select is_admin from users where id = uid));
end $fn$;

create or replace function add_skin(p_token uuid, p_skin text)
returns json language plpgsql security definer as $fn$
declare uid uuid;
begin
  uid := _uid(p_token);
  if uid is null then return json_build_object('ok', false); end if;
  insert into owned_skins(user_id, skin_id) values (uid, p_skin) on conflict do nothing;
  return json_build_object('ok', true);
end $fn$;

create or replace function set_coins(p_token uuid, p_amount int)
returns json language plpgsql security definer as $fn$
declare uid uuid;
begin
  uid := _uid(p_token);
  if uid is null then return json_build_object('ok', false); end if;
  insert into coins(user_id, amount) values (uid, p_amount)
    on conflict (user_id) do update set amount = excluded.amount;
  return json_build_object('ok', true);
end $fn$;
