-- Development reset: the previous flat row model cannot represent patterns
-- whose numbering restarts inside each piece. Existing data is test-only.
truncate table public.projects, public.patterns cascade;

drop table if exists public.pattern_rows;

alter table public.patterns
  rename column total_rows to total_instructions;

alter table public.projects
  rename column current_row to current_instruction;

alter table public.project_notes
  rename column row_number to instruction_position;

alter index if exists public.project_notes_project_row_idx
  rename to project_notes_project_instruction_idx;

create table public.pattern_instructions (
  id uuid primary key default gen_random_uuid(),
  pattern_id uuid not null references public.patterns(id) on delete cascade,
  position integer not null check (position > 0),
  section text not null,
  section_quantity integer not null default 1 check (section_quantity > 0),
  section_position integer not null check (section_position > 0),
  instruction_kind text not null check (
    instruction_kind in (
      'round',
      'row',
      'step',
      'setup',
      'instruction',
      'choice',
      'repeat',
      'technique'
    )
  ),
  source_label text,
  instruction_number integer check (instruction_number > 0),
  instruction_number_end integer check (instruction_number_end >= instruction_number),
  instructions text not null,
  notes text,
  stitch_count integer check (stitch_count >= 0),
  optional boolean not null default false,
  source_group text,
  confidence text not null check (confidence in ('high', 'medium', 'low')),
  unique (pattern_id, position)
);

create index pattern_instructions_pattern_order_idx
  on public.pattern_instructions(pattern_id, position);

comment on table public.pattern_instructions is
  'Section-first, ordered instructions extracted from a pattern.';
comment on column public.pattern_instructions.position is
  'Global reading order used for project progress.';
comment on column public.pattern_instructions.instruction_number is
  'Author-facing number scoped to its section, such as Round 1.';
comment on column public.projects.current_instruction is
  'Global pattern instruction position where the project resumes.';
comment on column public.project_notes.instruction_position is
  'Global pattern instruction position associated with the note.';
comment on table public.project_notes is
  'Project and instruction-specific maker notes.';
