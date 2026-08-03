import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import sharp from "sharp";
import { getDocumentProxy } from "unpdf";
import { createPatternCoverThumbnail } from "../src/lib/pattern-cover.ts";

test("creates a displayable JPEG from the embedded starter-pattern artwork", async () => {
  const bytes = new Uint8Array(await readFile("public/examples/stitchly-starter-headband.pdf"));
  const pdf = await getDocumentProxy(bytes);
  const thumbnail = await createPatternCoverThumbnail(pdf);

  assert.ok(thumbnail);
  const metadata = await sharp(thumbnail).metadata();
  assert.equal(metadata.format, "jpeg");
  assert.equal(metadata.width, 1200);
  assert.equal(metadata.height, 900);
});
