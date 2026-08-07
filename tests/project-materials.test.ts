import assert from "node:assert/strict";
import test from "node:test";
import { deriveProjectMaterials } from "../src/lib/project-materials.ts";

test("project materials combine structured metadata and explicit instruction evidence", () => {
  const materials = deriveProjectMaterials({ yarn: "DK yarn", tool: "3mm needles", instructions: ["Insert safety eyes, stuff, then sew the seam."] });
  assert.deepEqual(materials.map((material) => material.id), ["yarn", "tool", "safety-eyes", "stuffing", "yarn-needle"]);
});

test("project materials do not invent missing supplies", () => {
  assert.deepEqual(deriveProjectMaterials({ instructions: ["Work the next row."] }), []);
});
