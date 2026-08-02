create table if not exists public.native_identities (
  id uuid primary key default gen_random_uuid(),
  app_user_id text not null,
  provider text not null check (provider in ('apple')),
  provider_subject text not null,
  email text,
  name text,
  refresh_token_encrypted text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_subject)
);

create table if not exists public.native_sessions (
  id uuid primary key default gen_random_uuid(),
  app_user_id text not null,
  token_hash text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  last_used_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index if not exists native_identities_user_idx
  on public.native_identities(app_user_id);
create index if not exists native_sessions_user_idx
  on public.native_sessions(app_user_id, expires_at desc);

comment on table public.native_identities is
  'Native platform identities mapped to the same owner IDs used by Stitchly data.';
comment on table public.native_sessions is
  'Revocable, hashed bearer sessions issued to native Stitchly clients.';
