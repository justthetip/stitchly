import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import { join } from "node:path";
import test from "node:test";

test("the bundled demo catalog contains three complete source patterns", async () => {
  const catalog = JSON.parse(
    await readFile(join(process.cwd(), "src/lib/demo-catalog.json"), "utf8"),
  ) as {
    patterns: Array<{
      id: string;
      name: string;
      totalInstructions: number;
      pdfResource: string;
      coverUrl: string;
    }>;
    instructions: Record<string, unknown[]>;
    project: { patternId: string };
  };

  assert.deepEqual(
    catalog.patterns.map((pattern) => pattern.name),
    ["Fruity Friends", "Mini Whale", "The Perfect Granny Square"],
  );
  assert.equal(catalog.project.patternId, "demo-fruity-friends");

  for (const pattern of catalog.patterns) {
    assert.ok(pattern.totalInstructions > 0);
    assert.equal(catalog.instructions[pattern.id].length, pattern.totalInstructions);
    await access(join(process.cwd(), "public/demo", `${pattern.pdfResource}.pdf`));
    await access(join(process.cwd(), "public", pattern.coverUrl));
    await access(join(process.cwd(), "ios/Stitchly/Demo", `${pattern.pdfResource}.pdf`));
  }
});
