-- =============================================================
-- CLIMBY LEAGUE — Supabase schema
-- Single migration: запусти всё одной командой в SQL Editor
-- =============================================================

-- Подчищаю старое если уже что-то было (для повторного запуска)
-- ВНИМАНИЕ: на проде это удалит данные. Для первого запуска ок.
drop table if exists public.reports cascade;
drop table if exists public.appeals cascade;
drop table if exists public.tickets cascade;
drop table if exists public.notifications cascade;
drop table if exists public.team_invites cascade;
drop table if exists public.match_confirmations cascade;
drop table if exists public.match_rounds cascade;
drop table if exists public.match_maps cascade;
drop table if exists public.matches cascade;
drop table if exists public.team_achievements cascade;
drop table if exists public.player_achievements cascade;
drop table if exists public.team_members cascade;
drop table if exists public.teams cascade;
drop table if exists public.profiles cascade;
drop table if exists public.seasons cascade;
drop table if exists public.divisions cascade;
drop table if exists public.news cascade;
drop type if exists role_kind cascade;
drop type if exists match_status cascade;
drop type if exists report_status cascade;
drop type if exists notif_kind cascade;
drop type if exists invite_status cascade;

-- =============================================================
-- ENUM-ТИПЫ
-- =============================================================

create type role_kind as enum ('captain', 'sniper', 'entry', 'support', 'substitute');
create type match_status as enum ('scheduled', 'preparing', 'live', 'finished', 'cancelled', 'disputed');
create type report_status as enum ('open', 'investigating', 'resolved', 'rejected');
create type notif_kind as enum ('match_soon', 'match_assigned', 'match_result', 'invite', 'achievement', 'system', 'rating');
create type invite_status as enum ('pending', 'accepted', 'declined', 'expired');

-- =============================================================
-- БАЗОВЫЕ СПРАВОЧНИКИ
-- =============================================================

-- Дивизионы (D1 Rookie, D2 Challenger, D3 Elite, D4 Pro)
create table public.divisions (
  id        text primary key,           -- 'd1', 'd2', 'd3', 'd4'
  name      text not null,
  emoji     text not null,
  capacity  int  not null,              -- сколько команд помещается
  is_open   boolean not null default false,
  sort_order int not null,
  created_at timestamptz not null default now()
);

-- Сезоны (Сезон 1 · Genesis, Сезон 2 и т.д.)
create table public.seasons (
  id         uuid primary key default gen_random_uuid(),
  number     int not null unique,
  name       text not null,             -- 'Genesis'
  starts_at  timestamptz not null,
  ends_at    timestamptz not null,
  is_active  boolean not null default false,
  prize_pool int default 0,             -- в рублях
  created_at timestamptz not null default now()
);

-- =============================================================
-- ПРОФИЛИ ИГРОКОВ
-- =============================================================
-- 1:1 с auth.users (Supabase Auth). При регистрации триггер создаёт строку.

create table public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  nick            text unique not null check (char_length(nick) between 3 and 16),
  handle          text unique,                                  -- @zekko_sn
  bio             text check (char_length(bio) <= 150),
  avatar_emoji    text default '🎮',                            -- если нет аватарки
  avatar_color    text default 'var(--accent)',                  -- цвет плашки
  region          text default 'RU',
  city            text,
  is_verified     boolean not null default false,                -- прошёл Verify через TG-бота
  standoff_id     text unique,                                   -- ID в Standoff 2
  telegram_id     bigint unique,                                 -- TG для уведомлений
  telegram_username text,
  preferred_role  role_kind default 'entry',
  current_elo     int not null default 2000,
  total_kd        numeric(4,2) default 1.00,
  total_wr        numeric(4,3) default 0.500,                    -- 0.500 = 50%
  total_mvp       int default 0,
  matches_played  int default 0,
  joined_at       timestamptz not null default now(),
  last_seen_at    timestamptz not null default now()
);

create index profiles_nick_idx on public.profiles (nick);
create index profiles_elo_idx on public.profiles (current_elo desc);

-- =============================================================
-- КОМАНДЫ
-- =============================================================

create table public.teams (
  id            uuid primary key default gen_random_uuid(),
  name          text unique not null check (char_length(name) between 3 and 32),
  tag           text unique not null check (char_length(tag) between 2 and 5), -- VRN
  logo_initials text not null,                                   -- 'VR'
  logo_color    text not null default 'var(--accent)',
  bio           text check (char_length(bio) <= 200),
  region        text default 'RU',
  division_id   text references public.divisions(id) default 'd1',
  season_id     uuid references public.seasons(id),
  is_recruiting boolean default false,
  is_public_stats boolean default true,                          -- если false → "закрытая стата"
  -- агрегированные стата (обновляются триггерами после матчей)
  wr            numeric(4,3) default 0.500,
  matches_played int default 0,
  wins          int default 0,
  losses        int default 0,
  points        int default 0,                                   -- PTS в сезоне
  rank          int,                                              -- место в дивизионе
  current_streak int default 0,                                   -- +N побед / -N поражений
  created_by    uuid references public.profiles(id),
  created_at    timestamptz not null default now()
);

create index teams_division_idx on public.teams (division_id, points desc);
create index teams_rank_idx on public.teams (rank);

-- =============================================================
-- УЧАСТНИКИ КОМАНДЫ
-- =============================================================

create table public.team_members (
  team_id    uuid not null references public.teams(id) on delete cascade,
  player_id  uuid not null references public.profiles(id) on delete cascade,
  role       role_kind not null,
  is_captain boolean not null default false,
  joined_at  timestamptz not null default now(),
  left_at    timestamptz,
  primary key (team_id, player_id)
);

create index team_members_player_idx on public.team_members (player_id) where left_at is null;
create unique index team_one_captain_idx on public.team_members (team_id) where is_captain = true and left_at is null;

-- =============================================================
-- МАТЧИ
-- =============================================================

create table public.matches (
  id             uuid primary key default gen_random_uuid(),
  season_id      uuid not null references public.seasons(id),
  division_id    text not null references public.divisions(id),
  team_a_id      uuid not null references public.teams(id),
  team_b_id      uuid not null references public.teams(id),
  format         text not null default 'bo3' check (format in ('bo1', 'bo3', 'bo5')),
  status         match_status not null default 'scheduled',
  scheduled_at   timestamptz not null,
  started_at     timestamptz,
  finished_at    timestamptz,
  team_a_score   int default 0,
  team_b_score   int default 0,
  winner_id      uuid references public.teams(id),
  is_close_loss  boolean default false,                          -- 11:13 → close loss
  points_a       int default 0,                                  -- +10/-7/-5
  points_b       int default 0,
  created_at     timestamptz not null default now(),
  check (team_a_id <> team_b_id)
);

create index matches_status_idx on public.matches (status, scheduled_at);
create index matches_team_a_idx on public.matches (team_a_id);
create index matches_team_b_idx on public.matches (team_b_id);

-- Подтверждение результата матча капитанами
create table public.match_confirmations (
  match_id    uuid not null references public.matches(id) on delete cascade,
  team_id     uuid not null references public.teams(id),
  captain_id  uuid not null references public.profiles(id),
  confirmed   boolean not null default false,
  confirmed_at timestamptz,
  primary key (match_id, team_id)
);

-- Карты в матче (пик/бан и сыгранные)
create table public.match_maps (
  id          uuid primary key default gen_random_uuid(),
  match_id    uuid not null references public.matches(id) on delete cascade,
  map_name    text not null,                                     -- 'DUST', 'PROVINCE', etc
  map_emoji   text,
  order_index int not null,                                       -- 0, 1, 2, ...
  action      text not null check (action in ('ban', 'pick', 'decider')),
  actor_team_id uuid references public.teams(id),
  -- если карта была сыграна
  team_a_rounds int,
  team_b_rounds int,
  winner_id   uuid references public.teams(id),
  created_at  timestamptz not null default now()
);

-- =============================================================
-- ПРИГЛАШЕНИЯ В КОМАНДУ
-- =============================================================

create table public.team_invites (
  id          uuid primary key default gen_random_uuid(),
  team_id     uuid not null references public.teams(id) on delete cascade,
  inviter_id  uuid not null references public.profiles(id),
  invitee_id  uuid not null references public.profiles(id),
  role        role_kind not null,
  message     text,
  status      invite_status not null default 'pending',
  created_at  timestamptz not null default now(),
  expires_at  timestamptz default (now() + interval '7 days'),
  responded_at timestamptz,
  unique (team_id, invitee_id, status)
);

create index team_invites_invitee_idx on public.team_invites (invitee_id, status);

-- =============================================================
-- УВЕДОМЛЕНИЯ
-- =============================================================

create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  kind        notif_kind not null,
  title       text not null,
  body        text,
  link        text,                                              -- 'match:UUID' / 'team:UUID' / 'invites'
  is_read     boolean not null default false,
  is_urgent   boolean not null default false,
  created_at  timestamptz not null default now()
);

create index notifications_user_idx on public.notifications (user_id, is_read, created_at desc);

-- =============================================================
-- ДОСТИЖЕНИЯ
-- =============================================================

create table public.player_achievements (
  player_id   uuid not null references public.profiles(id) on delete cascade,
  code        text not null,                                     -- 'sniper_1', 'mvp_3_streak'
  title       text not null,
  description text,
  emoji       text not null,
  unlocked    boolean not null default false,
  unlocked_at timestamptz,
  primary key (player_id, code)
);

create table public.team_achievements (
  team_id     uuid not null references public.teams(id) on delete cascade,
  code        text not null,
  title       text not null,
  description text,
  emoji       text not null,
  unlocked    boolean not null default false,
  unlocked_at timestamptz,
  primary key (team_id, code)
);

-- =============================================================
-- РЕПОРТЫ / ТИКЕТЫ / АППЕЛЯЦИИ
-- =============================================================

create table public.reports (
  id            uuid primary key default gen_random_uuid(),
  reporter_id   uuid not null references public.profiles(id),
  target_nick   text not null,                                   -- кого репортят (могут быть на ник, не на id)
  target_id     uuid references public.profiles(id),
  match_id      uuid references public.matches(id),
  categories    text[] not null,                                 -- ['toxicity', 'cheats', ...]
  description   text not null,
  evidence_urls text[],
  status        report_status not null default 'open',
  resolved_by   uuid references public.profiles(id),
  resolution    text,
  created_at    timestamptz not null default now(),
  resolved_at   timestamptz
);

create index reports_status_idx on public.reports (status, created_at desc);

create table public.tickets (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id),
  topic       text not null,                                     -- 'tech', 'rules', 'ready_system', etc
  description text not null,
  evidence_urls text[],
  status      report_status not null default 'open',
  resolved_by uuid references public.profiles(id),
  resolution  text,
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);

create table public.appeals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id),
  ban_type    text not null,                                     -- 'temporary', 'league_ban', 'penalty', 'warn'
  ban_date    date,
  description text not null,
  evidence_urls text[],
  status      report_status not null default 'open',
  resolved_by uuid references public.profiles(id),
  resolution  text,
  created_at  timestamptz not null default now(),
  resolved_at timestamptz
);

-- =============================================================
-- НОВОСТИ
-- =============================================================

create table public.news (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  category    text not null,                                     -- 'patch', 'transfer', 'week', 'event', 'interview', 'guide', 'rules'
  title       text not null,
  emoji       text not null,
  preview     text not null,                                     -- короткое описание (2-3 предл)
  body        text not null,                                     -- полная статья (markdown/html)
  author_name text default 'Climby Staff',
  is_featured boolean default false,
  reading_min int default 3,
  views_count int default 0,
  published_at timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create index news_category_idx on public.news (category, published_at desc);
create index news_featured_idx on public.news (is_featured, published_at desc) where is_featured = true;

-- =============================================================
-- ТРИГГЕРЫ И ФУНКЦИИ
-- =============================================================

-- При регистрации в auth.users — автоматически создаём profile
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nick, handle)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'nick', 'player_' || substr(new.id::text, 1, 6)),
    coalesce(new.raw_user_meta_data->>'handle', '@player_' || substr(new.id::text, 1, 6))
  )
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- При апдейте last_seen
create or replace function public.update_last_seen()
returns trigger language plpgsql as $$
begin
  new.last_seen_at = now();
  return new;
end;
$$;

-- =============================================================
-- RLS — Row Level Security
-- =============================================================

alter table public.profiles enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;
alter table public.matches enable row level security;
alter table public.match_confirmations enable row level security;
alter table public.match_maps enable row level security;
alter table public.team_invites enable row level security;
alter table public.notifications enable row level security;
alter table public.player_achievements enable row level security;
alter table public.team_achievements enable row level security;
alter table public.reports enable row level security;
alter table public.tickets enable row level security;
alter table public.appeals enable row level security;
alter table public.news enable row level security;
alter table public.divisions enable row level security;
alter table public.seasons enable row level security;

-- PROFILES: все могут читать, только сам себя — апдейтить
create policy "profiles_select_all" on public.profiles for select using (true);
create policy "profiles_update_self" on public.profiles for update using (auth.uid() = id);
create policy "profiles_insert_self" on public.profiles for insert with check (auth.uid() = id);

-- TEAMS: все могут читать публичные данные, изменять — только капитан
create policy "teams_select_all" on public.teams for select using (true);
create policy "teams_insert_authed" on public.teams for insert with check (auth.uid() = created_by);
create policy "teams_update_captain" on public.teams for update using (
  exists (
    select 1 from public.team_members
    where team_id = teams.id and player_id = auth.uid() and is_captain = true and left_at is null
  )
);

-- TEAM_MEMBERS: все могут читать, изменять — только капитан этой команды или сам игрок (выйти)
create policy "team_members_select_all" on public.team_members for select using (true);
create policy "team_members_insert_captain" on public.team_members for insert with check (
  exists (
    select 1 from public.team_members tm
    where tm.team_id = team_members.team_id
      and tm.player_id = auth.uid() and tm.is_captain = true and tm.left_at is null
  )
);
create policy "team_members_leave_self" on public.team_members for update using (
  auth.uid() = player_id or exists (
    select 1 from public.team_members tm
    where tm.team_id = team_members.team_id
      and tm.player_id = auth.uid() and tm.is_captain = true and tm.left_at is null
  )
);

-- MATCHES: все могут читать
create policy "matches_select_all" on public.matches for select using (true);

-- MATCH_CONFIRMATIONS: капитан подтверждает только за свою команду
create policy "match_confirmations_select_all" on public.match_confirmations for select using (true);
create policy "match_confirmations_captain" on public.match_confirmations for update using (
  auth.uid() = captain_id
);

-- MATCH_MAPS: публично читаемы
create policy "match_maps_select_all" on public.match_maps for select using (true);

-- INVITES: видны только адресату и капитану команды-отправителя
create policy "invites_select_involved" on public.team_invites for select using (
  auth.uid() = invitee_id or auth.uid() = inviter_id
);
create policy "invites_insert_captain" on public.team_invites for insert with check (
  exists (
    select 1 from public.team_members
    where team_id = team_invites.team_id and player_id = auth.uid() and is_captain = true and left_at is null
  )
);
create policy "invites_respond_invitee" on public.team_invites for update using (
  auth.uid() = invitee_id
);

-- NOTIFICATIONS: каждый видит только свои
create policy "notifs_select_self" on public.notifications for select using (auth.uid() = user_id);
create policy "notifs_update_self" on public.notifications for update using (auth.uid() = user_id);
create policy "notifs_delete_self" on public.notifications for delete using (auth.uid() = user_id);

-- ACHIEVEMENTS: все могут читать чужие, апдейтит только бэк (через service role)
create policy "player_achievements_select_all" on public.player_achievements for select using (true);
create policy "team_achievements_select_all" on public.team_achievements for select using (true);

-- REPORTS: репортер видит свои репорты, модераторы — все (модераторы через service role)
create policy "reports_select_self" on public.reports for select using (auth.uid() = reporter_id);
create policy "reports_insert_self" on public.reports for insert with check (auth.uid() = reporter_id);
create policy "tickets_select_self" on public.tickets for select using (auth.uid() = user_id);
create policy "tickets_insert_self" on public.tickets for insert with check (auth.uid() = user_id);
create policy "appeals_select_self" on public.appeals for select using (auth.uid() = user_id);
create policy "appeals_insert_self" on public.appeals for insert with check (auth.uid() = user_id);

-- NEWS, DIVISIONS, SEASONS: публично читаемы
create policy "news_select_all" on public.news for select using (true);
create policy "divisions_select_all" on public.divisions for select using (true);
create policy "seasons_select_all" on public.seasons for select using (true);

-- =============================================================
-- REAL-TIME подписки
-- =============================================================
-- Эти таблицы стоит включить в Realtime в дашборде Supabase:
-- - matches (для LIVE-обновлений счёта)
-- - match_maps (для пик/бан)
-- - match_confirmations
-- - notifications
-- - team_invites
--
-- Включается через UI: Database → Replication → climby_publication
