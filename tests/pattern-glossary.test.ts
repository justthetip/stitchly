import assert from "node:assert/strict";
import test from "node:test";
import { glossarySegments, glossaryTermsIn } from "../src/lib/pattern-glossary.ts";

test("glossary matching preserves the exact source text", () => {
  const source = "K1, k2tog, then sc in each st.";
  assert.equal(glossarySegments(source).map((segment) => segment.text).join(""), source);
});

test("longer terms win and shorthand inside words stays untouched", () => {
  const segments = glossarySegments("k2tog while scanning the row");
  assert.deepEqual(segments.filter((segment) => segment.term).map((segment) => segment.term?.id), ["k2tog"]);
});

test("compact magic-ring counts open the magic-ring definition", () => {
  const segment = glossarySegments("mr6, then sc around").find((candidate) => candidate.text === "mr6");
  assert.equal(segment?.term?.id, "mr");
});

test("pattern glossary contains only terms found in its instructions", () => {
  const terms = glossaryTermsIn(["Ch 2. Sc 6 into 2nd ch from hook."]);
  assert.deepEqual(terms.map((term) => term.id), ["sc", "ch"]);
});
