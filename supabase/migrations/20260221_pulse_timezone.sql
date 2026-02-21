-- Add timezone persistence for user-local quiet hours

alter table if exists public.pulse_dispatch_state
  add column if not exists timezone text;

create index if not exists pulse_dispatch_state_timezone_idx
  on public.pulse_dispatch_state (timezone);
