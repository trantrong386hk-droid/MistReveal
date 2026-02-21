# Pulse Scheduler Deployment

## What is included

- `functions/pulse-dispatch`: single-user dispatch endpoint (used by app + admin calls)
- `functions/pulse-cron`: batch dispatcher for hourly cron
- `functions/_shared/pulse-core.ts`: shared trigger + generation logic
- `migrations/20260221_pulse_scheduler.sql`: state/log/token tables + RLS
- `migrations/20260221_pulse_timezone.sql`: add timezone persistence for local quiet hours

## Required Edge secrets

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `PULSE_CRON_SECRET`
- Optional: `PUSH_WEBHOOK_URL`
- Optional: `PULSE_MODEL` (default `qwen-plus`)

## Deploy steps

1. Run SQL migrations.
2. Deploy functions:
   - `supabase functions deploy pulse-dispatch`
   - `supabase functions deploy pulse-cron`
3. Set function secrets.
4. Enable cron in SQL (uncomment block in migration and fill project URL + `PULSE_CRON_SECRET`).

## App behavior

- iOS app calls `pulse-dispatch` when entering chat foreground.
- App should pass `timezone` (IANA id, e.g. `Asia/Shanghai`) in request body.
- If server dispatch succeeds, app renders returned content immediately and does not double-write chat.
- If server dispatch fails, app falls back to local trigger logic.
- Cron uses stored timezone from `pulse_dispatch_state.timezone`; falls back to UTC if missing.

## API examples

Single user (authenticated user token):

```bash
curl -X POST "https://<project-ref>.supabase.co/functions/v1/pulse-dispatch" \
  -H "Authorization: Bearer <user_jwt>" \
  -H "Content-Type: application/json" \
  -d '{"source":"app_foreground","dry_run":false,"timezone":"Asia/Shanghai"}'
```

Cron batch:

```bash
curl -X POST "https://<project-ref>.supabase.co/functions/v1/pulse-cron" \
  -H "x-cron-secret: <PULSE_CRON_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{}'
```
