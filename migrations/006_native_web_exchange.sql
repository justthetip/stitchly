alter table public.native_identities drop constraint if exists native_identities_provider_check;
alter table public.native_identities add constraint native_identities_provider_check
  check (provider in ('apple', 'web'));

create table if not exists public.native_exchange_codes (
  id uuid primary key default gen_random_uuid(),
  app_user_id text not null,
  code_hash text not null unique,
  pkce_challenge text not null,
  expires_at timestamptz not null default (now() + interval '5 minutes'),
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists native_exchange_codes_expiry_idx
  on public.native_exchange_codes(expires_at);
