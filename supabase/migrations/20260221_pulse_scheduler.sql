-- Pulse scheduler: state + logs + push tokens

create table if not exists public.pulse_dispatch_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  daily_count integer not null default 0,
  last_day_utc date not null default (now() at time zone 'utc')::date,
  last_sent_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.pulse_dispatch_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  companion_id uuid references public.ai_companions(id) on delete set null,
  source text not null,
  intent text,
  tone text,
  topic text,
  script_hook text,
  dispatched boolean not null default false,
  pushed boolean not null default false,
  payload jsonb,
  created_at timestamptz not null default now()
);

create index if not exists pulse_dispatch_logs_user_created_idx
  on public.pulse_dispatch_logs (user_id, created_at desc);

create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('ios', 'android')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create index if not exists user_push_tokens_user_active_idx
  on public.user_push_tokens (user_id, active, updated_at desc);

-- Enable RLS
alter table public.pulse_dispatch_state enable row level security;
alter table public.pulse_dispatch_logs enable row level security;
alter table public.user_push_tokens enable row level security;

-- RLS policies
create policy if not exists "pulse_state_select_own"
  on public.pulse_dispatch_state
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy if not exists "pulse_logs_select_own"
  on public.pulse_dispatch_logs
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy if not exists "push_tokens_select_own"
  on public.user_push_tokens
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy if not exists "push_tokens_insert_own"
  on public.user_push_tokens
  for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy if not exists "push_tokens_update_own"
  on public.user_push_tokens
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- updated_at trigger (if helper exists in your DB)
do $$
begin
  if exists (select 1 from pg_proc where proname = 'update_updated_at_column') then
    execute 'drop trigger if exists set_user_push_tokens_updated_at on public.user_push_tokens';
    execute 'create trigger set_user_push_tokens_updated_at before update on public.user_push_tokens for each row execute function update_updated_at_column()';

    execute 'drop trigger if exists set_pulse_dispatch_state_updated_at on public.pulse_dispatch_state';
    execute 'create trigger set_pulse_dispatch_state_updated_at before update on public.pulse_dispatch_state for each row execute function update_updated_at_column()';
  end if;
end $$;

-- Optional: cron extension + hourly trigger by calling Edge Function
-- Fill in your project URL and secret before enabling.
-- create extension if not exists pg_cron;
-- create extension if not exists pg_net;
--
-- select cron.schedule(
--   'pulse-cron-hourly',
--   '5 * * * *',
--   $$
--   select net.http_post(
--     url := 'https://<your-project-ref>.supabase.co/functions/v1/pulse-cron',
--     headers := jsonb_build_object(
--       'Content-Type', 'application/json',
--       'x-cron-secret', '<PULSE_CRON_SECRET>'
--     ),
--     body := '{}'::jsonb
--   );
--   $$
-- );
