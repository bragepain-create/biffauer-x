-- ══════════════════════════════════════════════════════════════
-- BIFFAUER X · Komplett database-oppsett (Supabase / Postgres)
--
-- DETTE ER DEN ENESTE DATABASE-FILA. Den matcher den live databasen 1:1.
-- Idempotent: trygg å kjøre om igjen (create if not exists / create or replace).
--
-- NÅR TRENGER DU DENNE?
--   • Spillet KOBLER SEG ALLEREDE til en database (nøkkelen ligger i index.html).
--     Du trenger IKKE gjøre noe for å bruke den eksisterende databasen.
--   • Kjør denne KUN hvis du vil lage din EGEN database (nytt Supabase-prosjekt).
--     Da: kjør fila i Supabase → SQL Editor, og bytt URL + anon-nøkkel i index.html
--     (søk etter window.BX_DB øverst i den store <script>-blokka).
--
-- Uten database funker spillet fint lokalt (lagrer i nettleseren).
-- ══════════════════════════════════════════════════════════════

-- ─────────── TABELLER ───────────
create table if not exists users (
  id        uuid primary key default gen_random_uuid(),
  username  text not null,
  pass_hash text not null,
  is_admin  boolean not null default false,
  token     uuid not null default gen_random_uuid(),
  created   timestamptz default now()
);
create table if not exists game_slots (
  user_id  uuid references users on delete cascade,
  slot     int,
  progress jsonb not null default '{}',
  updated  timestamptz default now(),
  primary key (user_id, slot)
);
create table if not exists owned_skins (
  user_id uuid references users on delete cascade,
  skin_id text,
  primary key (user_id, skin_id)
);
create table if not exists coins (
  user_id uuid primary key references users on delete cascade,
  amount  int not null default 0
);
create table if not exists presence (
  user_id   uuid primary key references users on delete cascade,
  username  text,
  wave      int default 0,
  last_seen timestamptz default now()
);
create table if not exists admin_commands (
  id      bigserial primary key,
  cmd     text not null,
  created timestamptz default now()
);

-- ─────────── SIKKERHET (RLS på — kun funksjonene under kan lese/skrive) ───────────
alter table users         enable row level security;
alter table game_slots    enable row level security;
alter table owned_skins   enable row level security;
alter table coins         enable row level security;
alter table presence      enable row level security;
alter table admin_commands enable row level security;

-- ─────────── FUNKSJONER (hentet 1:1 fra live-databasen) ───────────

CREATE OR REPLACE FUNCTION public._is_admin_token(p_token uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$ select coalesce((select is_admin from users where token = p_token), false) $function$;

CREATE OR REPLACE FUNCTION public._uid(p_token uuid)
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$ select id from users where token = p_token $function$;

CREATE OR REPLACE FUNCTION public.add_skin(p_token uuid, p_skin text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare uid uuid;
begin
  uid := _uid(p_token);
  if uid is null then return json_build_object('ok', false); end if;
  insert into owned_skins(user_id, skin_id) values (uid, p_skin) on conflict do nothing;
  return json_build_object('ok', true);
end $function$;

CREATE OR REPLACE FUNCTION public.game_login(p_username text, p_password text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare u users;
begin
  select * into u from users where lower(username)=lower(p_username);
  if u.id is null or u.pass_hash <> crypt(p_password, u.pass_hash) then
    return json_build_object('ok', false, 'error', 'Feil brukernavn eller passord');
  end if;
  return json_build_object('ok', true, 'token', u.token, 'user_id', u.id, 'username', u.username, 'is_admin', u.is_admin);
end $function$;

CREATE OR REPLACE FUNCTION public.game_signup(p_username text, p_password text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare u users;
begin
  if exists (select 1 from users where lower(username)=lower(p_username)) then
    return json_build_object('ok', false, 'error', 'Brukernavnet er opptatt');
  end if;
  insert into users(username, pass_hash, is_admin)
    values (p_username, crypt(p_password, gen_salt('bf')), lower(p_username)='bragepain')
    returning * into u;
  insert into coins(user_id) values (u.id);
  return json_build_object('ok', true, 'token', u.token, 'user_id', u.id, 'username', u.username, 'is_admin', u.is_admin);
end $function$;

CREATE OR REPLACE FUNCTION public.get_all_users(p_token uuid)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$ select case when _is_admin_token(p_token) then
  json_build_object('ok', true, 'users', coalesce(
    (select json_agg(json_build_object('username', username, 'is_admin', is_admin) order by lower(username)) from users), '[]'))
  else json_build_object('ok', false, 'error', 'kun admin') end $function$;

CREATE OR REPLACE FUNCTION public.get_commands(p_after bigint)
 RETURNS json
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$ select json_build_object('ok', true, 'cmds', coalesce(
  (select json_agg(json_build_object('id', id, 'cmd', cmd) order by id)
   from admin_commands where id > p_after and created > now() - interval '30 seconds'), '[]')) $function$;

CREATE OR REPLACE FUNCTION public.get_live_players(p_token uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not _is_admin_token(p_token) then
    return json_build_object('ok', false, 'error', 'kun admin');
  end if;
  return json_build_object('ok', true, 'players', coalesce(
    (select json_agg(json_build_object('username', username, 'wave', wave, 'last_seen', last_seen)
            order by last_seen desc)
     from presence where last_seen > now() - interval '60 seconds'), '[]'));
end $function$;

CREATE OR REPLACE FUNCTION public.heartbeat(p_token uuid, p_wave integer)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare uid uuid; unm text;
begin
  select id, username into uid, unm from users where token = p_token;
  if uid is null then return json_build_object('ok', false); end if;
  insert into presence(user_id, username, wave, last_seen)
    values (uid, unm, coalesce(p_wave, 0), now())
    on conflict (user_id) do update
      set wave = excluded.wave, last_seen = now(), username = excluded.username;
  return json_build_object('ok', true);
end $function$;

CREATE OR REPLACE FUNCTION public.load_data(p_token uuid)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare uid uuid;
begin
  uid := _uid(p_token);
  if uid is null then return json_build_object('ok', false); end if;
  return json_build_object('ok', true,
    'slots', (select coalesce(json_agg(json_build_object('slot', slot, 'progress', progress)), '[]') from game_slots where user_id = uid),
    'skins', (select coalesce(json_agg(skin_id), '[]') from owned_skins where user_id = uid),
    'coins', (select amount from coins where user_id = uid),
    'is_admin', (select is_admin from users where id = uid));
end $function$;

CREATE OR REPLACE FUNCTION public.save_slot(p_token uuid, p_slot integer, p_progress jsonb)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare uid uuid;
begin
  uid := _uid(p_token);
  if uid is null then return json_build_object('ok', false, 'error', 'ugyldig token'); end if;
  insert into game_slots(user_id, slot, progress, updated) values (uid, p_slot, p_progress, now())
    on conflict (user_id, slot) do update set progress = excluded.progress, updated = now();
  return json_build_object('ok', true);
end $function$;

CREATE OR REPLACE FUNCTION public.send_command(p_token uuid, p_cmd text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not _is_admin_token(p_token) then return json_build_object('ok', false, 'error', 'kun admin'); end if;
  insert into admin_commands(cmd) values (p_cmd);
  delete from admin_commands where id < (select coalesce(max(id),0) - 50 from admin_commands);
  return json_build_object('ok', true);
end $function$;

CREATE OR REPLACE FUNCTION public.set_coins(p_token uuid, p_amount integer)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare uid uuid;
begin
  uid := _uid(p_token);
  if uid is null then return json_build_object('ok', false); end if;
  insert into coins(user_id, amount) values (uid, p_amount)
    on conflict (user_id) do update set amount = excluded.amount;
  return json_build_object('ok', true);
end $function$;

CREATE OR REPLACE FUNCTION public.set_user_admin(p_token uuid, p_username text, p_admin boolean)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
begin
  if not _is_admin_token(p_token) then return json_build_object('ok', false, 'error', 'kun admin'); end if;
  update users set is_admin = p_admin where lower(username) = lower(p_username);
  return json_build_object('ok', true);
end $function$;
