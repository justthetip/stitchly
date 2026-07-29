# Pattern extraction ground truth

The first extraction fixture is:

- Source: `original-pattern.pdf`
- Expected result: [`fixtures/pattern-extraction/lion.expected.json`](../fixtures/pattern-extraction/lion.expected.json)

The fixture is the product expectation, independently transcribed from the
rendered PDF. It is intentionally not shaped like the current parser output or
database tables.

## Structural decisions

1. A heading such as `Base square`, `Ears x2`, or `Muzzle` is a section.
2. `Rnd` and `Row` describe instruction kinds. They are not section names.
3. Instruction numbering is scoped to its section. Multiple sections can each
   contain `Rnd 1`.
4. Preserve the source label (`Rnd 1`, `Row 1`, or a numbered assembly step) so
   the app uses the pattern author's terminology.
5. Store the normalized kind separately (`round`, `row`, or `step`) so the app
   can explain and track each kind correctly.
6. Promote setup that the maker must perform into a trackable `setup`
   instruction. Keep explanatory section notes as metadata.
7. Keep instruction notes, optional status, and stitch counts as structured
   metadata rather than folding them into the instruction text.
8. A multiplier in a heading, such as `Ears x2`, becomes the section quantity.

## Scope of the first fixture

The expected actionable hierarchy is:

- Base square: 8 rounds
- Ears: 3 rounds, made twice
- Muzzle: 4 rounds
- Nose: 1 setup instruction plus 1 round
- Mane: section note plus 2 rounds
- Assembly: 5 steps

That is 6 sections and 24 guided instructions: 1 setup instruction, 18 rounds,
and 5 assembly steps. The source contains 23 numbered instructions; the extra
guide milestone is the unnumbered Nose setup that the maker must complete.
Making the ears twice does not duplicate its three source instructions.

Overview, materials, abbreviations, chart, and symbols are valuable pattern
reference content, but they are outside this first actionable-instruction
fixture. They can be added as typed reference sections after the core hierarchy
is reliable.

## Round versus row

Use the term found in the source pattern:

- A round is one complete loop around the work.
- A row is one line worked across the piece, commonly followed by turning.

The extractor should detect and retain the distinction. The interface can then
show contextual progress such as `Round 5 of 8` instead of converting all
instructions to generic rows.

## Acceptance criteria

An extractor matches this fixture when it:

- finds all 6 sections in source order;
- finds all 24 guided instructions in section order;
- assigns the correct instruction kind and section-local number;
- preserves each instruction's complete text without page headers, footers, or
  content from the next section;
- captures the 17 printed stitch counts and leaves the unprinted Mane Round 2
  count as `null`;
- identifies Base square Round 8 as optional;
- captures the Base square Round 5 note, promotes the Nose setup into a guided
  instruction, and captures the Mane note;
- captures `Ears x2` as quantity `2`; and
- does not treat references to another round, such as `Rnd 4` inside an
  instruction, as the start of a new instruction.

The section-first parser and `pattern_instructions` persistence model implement
this contract. Positions are global for project progress, while instruction
numbers remain local to their section, so several pieces can each begin at
`Rnd 1` without colliding.
