import { readdir, readFile, writeFile, mkdir } from "node:fs/promises";
import { basename, join } from "node:path";
import { extractText, getDocumentProxy } from "unpdf";
import { parsePatternText } from "../src/lib/pattern-parser.ts";

type CorpusResult =
  | {
      filename: string;
      status: "parsed";
      pages: number;
      name: string;
      designer: string | null;
      craft: "knit" | "crochet";
      sections: Array<{ name: string; quantity: number; instructionCount: number }>;
      totalInstructions: number;
      kinds: Record<string, number>;
      confidence: { high: number; medium: number; low: number };
      stitchCounts: number;
    }
  | {
      filename: string;
      status: "failed";
      error: string;
    };

const corpusRoot = join(process.cwd(), ".corpus", "lovecrafts");
const pdfRoot = join(corpusRoot, "pdfs");
const textRoot = join(corpusRoot, "text");
const expectationPath = join(
  process.cwd(),
  "fixtures",
  "pattern-extraction",
  "lovecrafts-corpus.expected.json",
);
await mkdir(textRoot, { recursive: true });

const filenames = (await readdir(pdfRoot))
  .filter((filename) => filename.toLowerCase().endsWith(".pdf"))
  .sort();

const results: CorpusResult[] = [];

for (const filename of filenames) {
  try {
    const file = new Uint8Array(await readFile(join(pdfRoot, filename)));
    const pdf = await getDocumentProxy(file);
    const extracted = await extractText(pdf);
    const pages = extracted.text;
    await writeFile(
      join(textRoot, `${basename(filename, ".pdf")}.txt`),
      pages.map((page, index) => `--- PAGE ${index + 1} ---\n${page}`).join("\n\n"),
    );

    const parsed = parsePatternText(pages, filename);
    const kinds = Object.fromEntries(
      [...new Set(parsed.instructions.map((item) => item.instructionKind))]
        .sort()
        .map((kind) => [
          kind,
          parsed.instructions.filter((item) => item.instructionKind === kind).length,
        ]),
    );

    results.push({
      filename,
      status: "parsed",
      pages: extracted.totalPages,
      name: parsed.name,
      designer: parsed.designer,
      craft: parsed.craft,
      sections: parsed.sections,
      totalInstructions: parsed.totalInstructions,
      kinds,
      confidence: {
        high: parsed.instructions.filter((item) => item.confidence === "high").length,
        medium: parsed.instructions.filter((item) => item.confidence === "medium").length,
        low: parsed.instructions.filter((item) => item.confidence === "low").length,
      },
      stitchCounts: parsed.instructions.filter((item) => item.stitchCount != null).length,
    });
  } catch (error) {
    results.push({
      filename,
      status: "failed",
      error: error instanceof Error ? error.message : String(error),
    });
  }
}

const expectations = JSON.parse(await readFile(expectationPath, "utf8")) as {
  patterns: Array<{ filename: string; minimumInstructionCount: number }>;
};
const regressions = expectations.patterns.flatMap((expected) => {
  const result = results.find((candidate) => candidate.filename === expected.filename);
  if (!result) return [`${expected.filename}: missing from the local corpus`];
  if (result.status !== "parsed") return [`${expected.filename}: failed to parse`];
  if (
    typeof result.totalInstructions !== "number" ||
    result.totalInstructions < expected.minimumInstructionCount
  ) {
    return [
      `${expected.filename}: extracted ${result.totalInstructions ?? 0}; expected at least ${expected.minimumInstructionCount}`,
    ];
  }
  return [];
});

const report = {
  generatedAt: new Date().toISOString(),
  corpusSize: filenames.length,
  parsed: results.filter((result) => result.status === "parsed").length,
  failed: results.filter((result) => result.status === "failed").length,
  expectedPatterns: expectations.patterns.length,
  regressions,
  results,
};

await writeFile(
  join(corpusRoot, "report.json"),
  `${JSON.stringify(report, null, 2)}\n`,
);

console.log(JSON.stringify(report, null, 2));
if (regressions.length) process.exitCode = 1;
