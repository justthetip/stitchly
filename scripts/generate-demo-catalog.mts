import { mkdir, readFile, writeFile } from "node:fs/promises";
import { basename, join } from "node:path";
import { extractText, getDocumentProxy } from "unpdf";
import { parsePatternText } from "../src/lib/pattern-parser.ts";

const sources = [
  {
    id: "demo-fruity-friends",
    path: join(process.cwd(), "ios/Stitchly/Demo/fruity-friends.pdf"),
    name: "Fruity Friends",
    designer: "Amanda Berry",
    difficulty: "Intermediate",
    craft: "knit" as const,
    yarn: "Paintbox Yarns Simply DK",
    tool: "3 mm needles",
    pdfResource: "fruity-friends",
    coverUrl: "/demo/fruity-friends-cover.png",
  },
  {
    id: "demo-mini-whale",
    path: join(process.cwd(), "ios/Stitchly/Demo/mini-whale.pdf"),
    name: "Mini Whale",
    designer: "The Crocheting",
    difficulty: "Beginner",
    craft: "crochet" as const,
    yarn: "Worsted weight yarn",
    tool: "Crochet hook",
    pdfResource: "mini-whale",
    coverUrl: "/demo/mini-whale-cover.png",
  },
  {
    id: "demo-perfect-granny-square",
    path: join(process.cwd(), "ios/Stitchly/Demo/perfect-granny-square.pdf"),
    name: "The Perfect Granny Square",
    designer: "Yay For Yarn",
    difficulty: "Advanced beginner",
    craft: "crochet" as const,
    yarn: "Any yarn weight",
    tool: "Matching crochet hook",
    pdfResource: "perfect-granny-square",
    coverUrl: "/demo/perfect-granny-square-cover.png",
  },
];

const patterns = [];
const instructions: Record<string, unknown[]> = {};

for (const source of sources) {
  const bytes = new Uint8Array(await readFile(source.path));
  const pdf = await getDocumentProxy(bytes);
  const extracted = await extractText(pdf);
  const parsed = parsePatternText(extracted.text, basename(source.path));
  patterns.push({
    id: source.id,
    name: source.name,
    designer: source.designer,
    craft: source.craft,
    difficulty: source.difficulty,
    yarn: source.yarn,
    tool: source.tool,
    totalInstructions: parsed.instructions.length,
    source: "Bundled demo PDF",
    pageCount: extracted.totalPages,
    coverUrl: source.coverUrl,
    pdfResource: source.pdfResource,
  });
  instructions[source.id] = parsed.instructions.map((instruction) => ({
    id: `${source.id}-instruction-${instruction.position}`,
    position: instruction.position,
    section: instruction.section,
    sectionQuantity: instruction.sectionQuantity,
    sectionPosition: instruction.sectionPosition,
    instructionKind: instruction.instructionKind,
    sourceLabel: instruction.sourceLabel,
    instructionNumber: instruction.instructionNumber,
    instructionNumberEnd: instruction.instructionNumberEnd,
    instructions: instruction.instructions,
    notes: instruction.notes,
    stitchCount: instruction.stitchCount,
    optional: instruction.optional,
    sourceGroup: instruction.sourceGroup,
    confidence: instruction.confidence,
  }));
}

const fruity = patterns[0];
const catalog = {
  patterns,
  instructions,
  project: {
    id: "demo-fruity-project",
    patternId: fruity.id,
    name: "My Fruity Friends",
    status: "active",
    yarn: "Paintbox Yarns Simply DK",
    currentInstruction: Math.min(4, fruity.totalInstructions),
    patternName: fruity.name,
    totalInstructions: fruity.totalInstructions,
    craft: fruity.craft,
    startedAt: "2026-08-01T09:00:00.000Z",
    lastWorkedAt: "2026-08-04T09:00:00.000Z",
    completedAt: null,
    coverUrl: fruity.coverUrl,
  },
};

for (const directory of ["ios/Stitchly/Demo", "public/demo", "src/lib"]) {
  await mkdir(join(process.cwd(), directory), { recursive: true });
  await writeFile(
    join(process.cwd(), directory, "demo-catalog.json"),
    `${JSON.stringify(catalog, null, 2)}\n`,
  );
}

console.log(
  patterns.map((pattern) => `${pattern.name}: ${pattern.totalInstructions} instructions`).join("\n"),
);
