alter table public.project_notes
  add column if not exists client_mutation_id uuid;

create unique index if not exists project_notes_owner_project_client_mutation_idx
  on public.project_notes(owner_id, project_id, client_mutation_id)
  where client_mutation_id is not null;

comment on column public.project_notes.client_mutation_id is
  'Optional owner-scoped idempotency key supplied by an offline-capable client.';
