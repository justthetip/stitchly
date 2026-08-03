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

test("renders the first page when a PDF has no extractable raster image", async () => {
  const vectorOnlyPdf = {
    _pdfInfo: {},
    numPages: 1,
    async getPage() {
      return {
        async getOperatorList() { return { fnArray: [], argsArray: [] }; },
        getViewport({ scale }: { scale: number }) { return { width: 600 * scale, height: 800 * scale }; },
        render({ canvasContext, viewport }: { canvasContext: { fillStyle: string; fillRect(x: number, y: number, width: number, height: number): void }; viewport: { width: number; height: number } }) {
          canvasContext.fillStyle = "#ffad21";
          canvasContext.fillRect(0, 0, viewport.width, viewport.height);
          return { promise: Promise.resolve() };
        },
      };
    },
  };

  const thumbnail = await createPatternCoverThumbnail(vectorOnlyPdf as never);
  assert.ok(thumbnail);
  const metadata = await sharp(thumbnail).metadata();
  assert.equal(metadata.format, "jpeg");
  assert.equal(metadata.width, 1200);
  assert.equal(metadata.height, 900);
});
