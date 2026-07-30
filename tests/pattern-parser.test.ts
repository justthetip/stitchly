import assert from "node:assert/strict";
import { existsSync } from "node:fs";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { extractText, getDocumentProxy } from "unpdf";
import { parsePatternText } from "../src/lib/pattern-parser.ts";

async function parseLocalPdf(filename: string) {
  const path = join(homedir(), "Downloads", filename);
  if (!existsSync(path)) return null;
  const pdf = await getDocumentProxy(new Uint8Array(await readFile(path)));
  const extracted = await extractText(pdf);
  return parsePatternText(extracted.text, filename);
}

test("keeps repeated round numbers inside their own Lion sections", () => {
  const parsed = parsePatternText([
    "Lion\nanimal granny square\n",
    [
      "Base square",
      "Rnd 1 Start with Yellow. mr6 sc.",
      "Rnd 2 ch3, work around.",
      "Rnd 3 ch3, work around.",
      "Rnd 4 ch3, work around.",
      "Rnd 5 Note: Use back loops only. Join Cream and work around.",
      "Rnd 6 ch3, work around.",
      "Rnd 7 ch3, work around.",
      "Rnd 8 Optional round. Join Brown and work around.",
      "Ears x2",
      "Rnd 1 Start with Yellow. mr6 sc.",
      "Rnd 2 (sc in next st) * 2.",
      "Rnd 3 sc all around.",
      "Muzzle",
      "Rnd 1 Start with White. mr5 sc.",
      "Rnd 2 2sc in next 5 sts.",
      "Rnd 3 (sc in next st) * 5.",
      "Rnd 4 sc all around.",
      "Nose",
      "Start with Brown. ch3, turn.",
      "Rnd 1 Start from second ch from hook.",
      "Mane",
      "Note: Work this during assembly.",
      "Rnd 1 Join Orange and sc all around.",
      "Rnd 2 (4dc in next st) * 14.",
      "Assembly",
      "1. Stitch the nose onto the muzzle.",
      "2. Stitch the muzzle in place.",
      "3. Embroider the eyes.",
      "4. Crochet the mane.",
      "5. Stitch the ears in place.",
    ].join("\n"),
  ], "original-pattern.pdf");

  assert.equal(parsed.name, "Lion");
  assert.deepEqual(parsed.sections.map((section) => section.name), [
    "Base square",
    "Ears",
    "Muzzle",
    "Nose",
    "Mane",
    "Assembly",
  ]);
  assert.equal(parsed.totalInstructions, 24);
  assert.equal(parsed.sections[1].quantity, 2);
  assert.equal(parsed.instructions.filter((item) => item.instructionNumber === 1).length, 6);
  assert.equal(parsed.instructions.find((item) => item.sourceLabel === "Rnd 8")?.optional, true);
  assert.equal(parsed.instructions.find((item) => item.instructionKind === "setup")?.section, "Nose");
});

test("expands Whale round ranges and retains unnumbered work", () => {
  const parsed = parsePatternText([
    [
      "Mini Whale Crochet Pattern by The Crocheting",
      "Materials",
      "Yarn",
      "Abbreviations",
      "Sc = single crochet",
      "Body (make 1)",
      "Round 1: Using blue, ch 2. Sc 6 into the ring. (6)",
      "Round 2: Inc in each st around. (12)",
      "Round 3: *Sc in next st, inc.* Repeat around. (18)",
      "Round 4: Sc in each st around. (18)",
      "Rounds 5-6 [2 rounds]: repeat Round 4. F/o.",
      "*attach safety eyes between the 5th and 6th rows.*",
      "Belly (make 1)",
      "Round 1: Using white, ch 2. Sc 6 into the ring. (6)",
    ].join("\n"),
    [
      "Round 2: Inc in each st around. (12)",
      "Round 3: *Sc in next st, inc.* Repeat around. (18)",
      "F/o and leave a tail.",
      "Tail (make 1)",
      "Ch 3. Turn, sc into the next stitch. F/o.",
      "Assembly",
      "Sew the belly to the body. Weave in ends.",
      "Sew the tail to the body.",
      "Enjoy!",
    ].join("\n"),
  ], "Mini+Whale+Crochet+Pattern.pdf");

  assert.equal(parsed.name, "Mini Whale");
  assert.equal(parsed.designer, "The Crocheting");
  assert.equal(parsed.totalInstructions, 12);
  assert.deepEqual(parsed.sections.map((section) => section.name), ["Body", "Belly", "Tail", "Assembly"]);
  assert.deepEqual(
    parsed.instructions.filter((item) => item.sourceGroup === "round:5-6").map((item) => item.instructionNumber),
    [5, 6],
  );
  assert.equal(parsed.instructions.find((item) => item.section === "Tail")?.instructionKind, "instruction");
  assert.equal(parsed.instructions.filter((item) => item.section === "Assembly").length, 2);
  assert.deepEqual(
    parsed.instructions.slice(0, 4).map((item) => item.stitchCount),
    [6, 12, 18, 18],
  );
});

test("uses the Granny Square printer-friendly copy once and creates guidance blocks", () => {
  const pages = [
    "How to Crochet the Perfect Granny Square\nFor the Printer-Friendly Version, print pages 5-6.\nGranny Square\nRound 1: duplicate illustrated copy.",
    "Round 2: duplicate illustrated copy.",
    "Round 3: duplicate illustrated copy.",
    "Round 4: duplicate illustrated copy.",
    [
      "How to Crochet the Perfect Granny Square",
      "by Yay For Yarn",
      "Granny Square",
      "Ch 4. sl st in 4th ch from hook to form a ring.",
      "Round 1: CSDC in ring. You should have 20 sts.",
      "Round 2: CSDC in corner. You should have 36 sts.",
      "Round 3: CSDC in corner. You should have 52 sts.",
    ].join("\n"),
    [
      "Round 4: CSDC in corner. You should have 68 sts.",
      "Round 5: CSDC in corner. You should have 84 sts.",
      "Round 6: CSSC in corner and sc around.",
      "If you want to use the yarn tail, slip stitch to join.",
      "If you don't want to use the yarn tail, use an invisible join.",
      "If you want, you can continue to make the square as large as you like.",
      "You can also make the granny square multicolored.",
      "To Change Colors:",
      "Tie off and join the new colour.",
      "This pattern is intended for your personal use only.",
    ].join("\n"),
  ];
  const parsed = parsePatternText(pages, "granny-square.pdf");

  assert.equal(parsed.name, "How to Crochet the Perfect Granny Square");
  assert.equal(parsed.designer, "Yay For Yarn");
  assert.equal(parsed.totalInstructions, 10);
  assert.deepEqual(
    parsed.instructions.map((item) => item.instructionKind),
    ["setup", "round", "round", "round", "round", "round", "round", "choice", "repeat", "technique"],
  );
  assert.deepEqual(
    parsed.instructions.filter((item) => item.instructionKind === "round").map((item) => item.stitchCount),
    [20, 36, 52, 68, 84, null],
  );
  assert.equal(parsed.instructions.at(-1)?.optional, true);
});

test("preserves rows as rows instead of converting them to rounds", () => {
  const parsed = parsePatternText([
    "Simple Scarf\nBody\nRow 1: Cast on 20 stitches.\nRow 2: Knit across.\nRow 3: Turn and purl across.",
  ], "simple-scarf.pdf");

  assert.deepEqual(parsed.instructions.map((item) => item.instructionKind), ["row", "row", "row"]);
  assert.deepEqual(parsed.instructions.map((item) => item.instructionNumber), [1, 2, 3]);
});

test("parses shorthand rounds, ranges, and continued piece headings", () => {
  const parsed = parsePatternText([
    [
      "Colourful Mini Dino Crochet Pattern",
      "HEAD AND BODY",
      "R1: 6 dc in magic circle [6 sts]",
      "R2: inc in each stitch [12 sts]",
      "R3 - R5: dc in each stitch [12 sts]",
      "HEAD AND BODY (continued)",
      "R6: dec around [6 sts]",
      "TAIL (make 2)",
      "R1: 4 dc in magic circle [4 sts]",
    ].join("\n"),
  ], "colourful-mini-dino.pdf");

  assert.deepEqual(parsed.sections.map((section) => section.name), ["HEAD AND BODY", "TAIL"]);
  assert.equal(parsed.sections[1].quantity, 2);
  assert.deepEqual(
    parsed.instructions
      .filter((item) => item.section === "HEAD AND BODY")
      .map((item) => item.instructionNumber),
    [1, 2, 3, 4, 5, 6],
  );
  assert.deepEqual(
    parsed.instructions.slice(0, 2).map((item) => item.stitchCount),
    [6, 12],
  );
});

test("parses ordinal and unnumbered follow-on rounds", () => {
  const parsed = parsePatternText([
    [
      "Essential String Shopping Bag",
      "BAG",
      "Using a 4.5mm hook make a magic loop.",
      "1st round 2 sc in each st around. | 12 sts.",
      "2nd round [2 sc in next st, 1 sc] 6 times. | 18 sts.",
      "3rd round [1 sc, 2 sc in next st, 1 sc] 6 times. | 24 sts.",
      "Net stitch set up round 1 sc, [ch 5, skip 3, 1 sc] around.",
      "Next round Ch 1, work into each chain space.",
      "Final round Sc around and fasten off.",
    ].join("\n"),
  ], "essential-string-shopping-bag.pdf");

  assert.equal(parsed.totalInstructions, 7);
  assert.deepEqual(
    parsed.instructions.map((item) => item.instructionKind),
    ["setup", "round", "round", "round", "round", "round", "round"],
  );
  assert.deepEqual(
    parsed.instructions.slice(1, 4).map((item) => item.stitchCount),
    [12, 18, 24],
  );
  assert.equal(parsed.instructions.at(-1)?.instructionNumber, null);
  assert.equal(parsed.instructions.at(-1)?.sourceLabel, "Final Round");
});

test("accepts row labels ending in a parenthesis", () => {
  const parsed = parsePatternText([
    [
      "Flaminia Top",
      "PANEL",
      "Row 1): starting from the 6th ch, crochet 1 sc.",
      "Row 2): 4 ch, turn and work across.",
      "Row 3): repeat the mesh pattern.",
    ].join("\n"),
  ], "flaminia-top.pdf");

  assert.deepEqual(
    parsed.instructions.map((item) => item.instructionKind),
    ["row", "row", "row"],
  );
  assert.deepEqual(
    parsed.instructions.map((item) => item.instructionNumber),
    [1, 2, 3],
  );
});

test("selects the English edition from a multilingual PDF", () => {
  const parsed = parsePatternText([
    "Baby Turtle\nBODY\nRnd 1: Make 6 sc in a magic ring. (6)",
    "Baby Turtle\nBODY continued\nRnd 2: Increase in each stitch around. (12)",
    "Bébé Tortue\nCORPS\nTour 1: Faire 6 mailles dans un cercle magique.",
    "Bébé Tortue\nCORPS suite\nTour 2: Faire une augmentation dans chaque maille.",
  ], "baby-turtle.pdf");

  assert.equal(parsed.name, "Baby Turtle");
  assert.equal(parsed.totalInstructions, 2);
  assert.ok(parsed.instructions.every((item) => !item.instructions.includes("Faire")));
});

test("matches the supplied Lion PDF", async (context) => {
  const parsed = await parseLocalPdf("original-pattern.pdf");
  if (!parsed) return context.skip("local sample PDF is not available");

  assert.equal(parsed.name, "Lion");
  assert.equal(parsed.designer, "Morgane Peng");
  assert.equal(parsed.totalInstructions, 24);
  assert.deepEqual(parsed.sections.map((section) => section.name), [
    "Base square",
    "Ears",
    "Muzzle",
    "Nose",
    "Mane",
    "Assembly",
  ]);
  assert.equal(parsed.instructions.filter((item) => item.instructionKind === "round").length, 18);
  assert.equal(parsed.instructions.filter((item) => item.instructionKind === "setup").length, 1);
  assert.equal(parsed.instructions.filter((item) => item.instructionKind === "step").length, 5);
});

test("matches the supplied Mini Whale PDF", async (context) => {
  const parsed = await parseLocalPdf("Mini+Whale+Crochet+Pattern.pdf");
  if (!parsed) return context.skip("local sample PDF is not available");

  assert.equal(parsed.name, "Mini Whale");
  assert.equal(parsed.designer, "The Crocheting");
  assert.equal(parsed.totalInstructions, 12);
  assert.deepEqual(parsed.sections.map((section) => section.name), [
    "Body",
    "Belly",
    "Tail",
    "Assembly",
  ]);
  assert.deepEqual(
    parsed.instructions
      .filter((item) => item.sourceGroup === "round:5-6")
      .map((item) => item.instructionNumber),
    [5, 6],
  );
});

test("matches the supplied printer-friendly Granny Square PDF", async (context) => {
  const filename = "70db787fcf6c955f838c8cf40d2df57552a8bffb.pdf";
  const parsed = await parseLocalPdf(filename);
  if (!parsed) return context.skip("local sample PDF is not available");

  assert.equal(parsed.name, "How to Crochet the Perfect Granny Square");
  assert.equal(parsed.designer, "Yay For Yarn");
  assert.equal(parsed.totalInstructions, 10);
  assert.deepEqual(
    parsed.instructions.map((item) => item.instructionKind),
    ["setup", "round", "round", "round", "round", "round", "round", "choice", "repeat", "technique"],
  );
});
