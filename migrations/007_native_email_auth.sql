alter table public.native_identities drop constraint if exists native_identities_provider_check;
alter table public.native_identities add constraint native_identities_provider_check
  check (provider in ('apple', 'email', 'web'));
