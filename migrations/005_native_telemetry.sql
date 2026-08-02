create table if not exists public.native_telemetry_events (
  id uuid primary key default gen_random_uuid(),
  owner_id text not null,
  event_name text not null check (event_name ~ '^[a-z0-9_]{1,64}$'),
  app_version text,
  build_number text,
  platform text not null default 'ios',
  properties jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists native_telemetry_owner_created_idx
  on public.native_telemetry_events(owner_id, created_at desc);

comment on table public.native_telemetry_events is
  'Minimal operational events. Pattern text, filenames, notes, and other user content are prohibited.';
