-- ══════════════════════════════════════════════════════════════
-- BIFFAUER X · Passord-glemt forespørsler (cross-device)
-- Kjør denne i Supabase SQL Editor (Ctrl+A, Delete, lim inn HELE, Run).
-- Gjør at "Glemt passord?" fra andre maskiner når Brage (admin).
-- Uten denne funker glemt-passord fortsatt LOKALT på egen maskin.
-- ══════════════════════════════════════════════════════════════

create table if not exists reset_requests (
  id        bigint generated always as identity primary key,
  username  text not null,
  realname  text not null,
  created   timestamptz not null default now(),
  resolved  boolean not null default false
);

alter table reset_requests enable row level security;

-- Hvem som helst (også ikke-innlogget) kan sende en forespørsel
create or replace function request_reset(p_username text, p_realname text, p_note text default '')
returns json language plpgsql security definer as $fn$
begin
  insert into reset_requests(username, realname) values (p_username, p_realname);
  return json_build_object('ok', true);
end $fn$;

-- Kun admin kan se forespørsler
create or replace function get_reset_requests(p_token uuid)
returns json language plpgsql security definer as $fn$
declare is_adm boolean;
begin
  select is_admin into is_adm from users where token = p_token;
  if not coalesce(is_adm, false) then return json_build_object('ok', false, 'error', 'kun admin'); end if;
  return json_build_object('ok', true, 'requests', coalesce(
    (select json_agg(json_build_object('id', id, 'username', username, 'realname', realname, 'created', created)
            from reset_requests where resolved = false order by created desc), '[]'::json));
end $fn$;

-- Admin markerer en forespørsel som ferdig
create or replace function resolve_reset(p_token uuid, p_id bigint)
returns json language plpgsql security definer as $fn$
declare is_adm boolean;
begin
  select is_admin into is_adm from users where token = p_token;
  if not coalesce(is_adm, false) then return json_build_object('ok', false, 'error', 'kun admin'); end if;
  update reset_requests set resolved = true where id = p_id;
  return json_build_object('ok', true);
end $fn$;
