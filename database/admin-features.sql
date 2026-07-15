-- Rydder test-konto (gammel kode) så Brage kan lage en frisk admin-konto med ny kode
delete from users where lower(username) = 'bragepain';

create table if not exists broadcasts (
  id bigserial primary key,
  message text not null,
  created timestamptz default now(),
  active boolean default true
);
create table if not exists presence (
  user_id uuid primary key references users on delete cascade,
  username text,
  wave int default 0,
  last_seen timestamptz default now()
);
create table if not exists submissions (
  id bigserial primary key,
  user_id uuid references users on delete cascade,
  username text,
  kind text,
  data jsonb,
  created timestamptz default now(),
  handled boolean default false
);

alter table broadcasts enable row level security;
alter table presence enable row level security;
alter table submissions enable row level security;

create or replace function _is_admin_token(p_token uuid) returns boolean language sql stable security definer as
$fn$ select coalesce((select is_admin from users where token = p_token), false) $fn$;

create or replace function send_broadcast(p_token uuid, p_message text) returns json language plpgsql security definer as $fn$
begin
  if not _is_admin_token(p_token) then return json_build_object('ok', false, 'error', 'kun admin'); end if;
  update broadcasts set active = false where active = true;
  insert into broadcasts(message) values (p_message);
  return json_build_object('ok', true);
end $fn$;

create or replace function clear_broadcast(p_token uuid) returns json language plpgsql security definer as $fn$
begin
  if not _is_admin_token(p_token) then return json_build_object('ok', false); end if;
  update broadcasts set active = false where active = true;
  return json_build_object('ok', true);
end $fn$;

create or replace function get_broadcast() returns json language sql stable security definer as
$fn$ select coalesce((select json_build_object('message', message, 'created', created) from broadcasts where active = true order by created desc limit 1), json_build_object('message', null)) $fn$;

create or replace function heartbeat(p_token uuid, p_wave int) returns json language plpgsql security definer as $fn$
declare uid uuid; unm text;
begin
  select id, username into uid, unm from users where token = p_token;
  if uid is null then return json_build_object('ok', false); end if;
  insert into presence(user_id, username, wave, last_seen) values (uid, unm, coalesce(p_wave,0), now())
    on conflict (user_id) do update set wave = excluded.wave, last_seen = now(), username = excluded.username;
  return json_build_object('ok', true);
end $fn$;

create or replace function get_live_players(p_token uuid) returns json language plpgsql security definer as $fn$
begin
  if not _is_admin_token(p_token) then return json_build_object('ok', false, 'error', 'kun admin'); end if;
  return json_build_object('ok', true, 'players',
    coalesce((select json_agg(json_build_object('username', username, 'wave', wave, 'last_seen', last_seen) order by last_seen desc)
      from presence where last_seen > now() - interval '60 seconds'), '[]'));
end $fn$;

create or replace function submit_item(p_token uuid, p_kind text, p_data jsonb) returns json language plpgsql security definer as $fn$
declare uid uuid; unm text;
begin
  select id, username into uid, unm from users where token = p_token;
  if uid is null then return json_build_object('ok', false); end if;
  insert into submissions(user_id, username, kind, data) values (uid, unm, p_kind, p_data);
  return json_build_object('ok', true);
end $fn$;

create or replace function get_submissions(p_token uuid) returns json language plpgsql security definer as $fn$
begin
  if not _is_admin_token(p_token) then return json_build_object('ok', false, 'error', 'kun admin'); end if;
  return json_build_object('ok', true, 'items',
    coalesce((select json_agg(json_build_object('id', id, 'username', username, 'kind', kind, 'data', data, 'created', created) order by created desc)
      from submissions where handled = false), '[]'));
end $fn$;

-- Utstyrt skin (hvilken er PÅ) — følger med på tvers av maskiner
alter table users add column if not exists equipped jsonb not null default '{}';

create or replace function set_equipped(p_token uuid, p_cat text, p_key text) returns json language plpgsql security definer as $fn$
declare uid uuid;
begin
  select id into uid from users where token = p_token;
  if uid is null then return json_build_object('ok', false); end if;
  update users set equipped = jsonb_set(coalesce(equipped, '{}'), array[p_cat], to_jsonb(p_key)) where id = uid;
  return json_build_object('ok', true);
end $fn$;

create or replace function load_data(p_token uuid) returns json language plpgsql security definer as $fn$
declare uid uuid;
begin
  uid := _uid(p_token);
  if uid is null then return json_build_object('ok', false); end if;
  return json_build_object('ok', true,
    'slots', (select coalesce(json_agg(json_build_object('slot', slot, 'progress', progress)), '[]') from game_slots where user_id = uid),
    'skins', (select coalesce(json_agg(skin_id), '[]') from owned_skins where user_id = uid),
    'coins', (select amount from coins where user_id = uid),
    'is_admin', (select is_admin from users where id = uid),
    'equipped', (select equipped from users where id = uid));
end $fn$;

-- game_signup: Bragepain blir automatisk admin
create or replace function game_signup(p_username text, p_password text) returns json language plpgsql security definer as $fn$
declare u users;
begin
  if exists (select 1 from users where lower(username)=lower(p_username)) then
    return json_build_object('ok', false, 'error', 'Brukernavnet er opptatt');
  end if;
  insert into users(username, pass_hash, is_admin) values (p_username, crypt(p_password, gen_salt('bf')), lower(p_username)='bragepain') returning * into u;
  insert into coins(user_id) values (u.id);
  return json_build_object('ok', true, 'token', u.token, 'user_id', u.id, 'username', u.username, 'is_admin', u.is_admin);
end $fn$;
