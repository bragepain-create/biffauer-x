-- ═══════════════════════════════════════════════════════════════
-- BIFFAUER X · KUN online-spillere (admin ser hvem som spiller nå)
-- Bittelien og selvstendig. Kjør i Supabase → SQL Editor:
--   Ctrl+A → Delete → lim inn HELE → Run
-- ═══════════════════════════════════════════════════════════════

create table if not exists presence (
  user_id   uuid primary key references users on delete cascade,
  username  text,
  wave      int default 0,
  last_seen timestamptz default now()
);
alter table presence enable row level security;

-- Hjelper: er dette tokenet en admin?
create or replace function _is_admin_token(p_token uuid) returns boolean
language sql stable security definer as
$fn$ select coalesce((select is_admin from users where token = p_token), false) $fn$;

-- Spiller melder «jeg spiller nå» + hvilken bølge (kalles hvert 15. sek)
create or replace function heartbeat(p_token uuid, p_wave int) returns json
language plpgsql security definer as $fn$
declare uid uuid; unm text;
begin
  select id, username into uid, unm from users where token = p_token;
  if uid is null then return json_build_object('ok', false); end if;
  insert into presence(user_id, username, wave, last_seen)
    values (uid, unm, coalesce(p_wave, 0), now())
    on conflict (user_id) do update
      set wave = excluded.wave, last_seen = now(), username = excluded.username;
  return json_build_object('ok', true);
end $fn$;

-- Admin henter alle som har spilt de siste 60 sekundene
create or replace function get_live_players(p_token uuid) returns json
language plpgsql security definer as $fn$
begin
  if not _is_admin_token(p_token) then
    return json_build_object('ok', false, 'error', 'kun admin');
  end if;
  return json_build_object('ok', true, 'players', coalesce(
    (select json_agg(json_build_object('username', username, 'wave', wave, 'last_seen', last_seen)
            order by last_seen desc)
     from presence where last_seen > now() - interval '60 seconds'), '[]'));
end $fn$;
