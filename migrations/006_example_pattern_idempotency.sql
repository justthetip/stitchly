create unique index if not exists patterns_one_stitchly_example_per_owner
  on public.patterns (owner_id)
  where source = 'Stitchly example';

comment on index public.patterns_one_stitchly_example_per_owner is
  'Prevents retries from creating duplicate first-party example patterns.';
