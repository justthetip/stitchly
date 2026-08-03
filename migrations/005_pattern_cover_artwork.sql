alter table public.patterns
  add column if not exists cover_blob_url text;

comment on column public.patterns.cover_blob_url is
  'Private owner-scoped Blob derivative selected from the uploaded PDF for pattern and project covers.';
