import { put } from "@vercel/blob";
import sharp from "sharp";
import { extractImages, renderPageAsImage, type getDocumentProxy } from "unpdf";

type PDFProxy = Awaited<ReturnType<typeof getDocumentProxy>>;

const thumbnailWidth = 1200;
const thumbnailHeight = 900;

async function normalizeCover(input: Buffer | Uint8Array, raw?: { width: number; height: number; channels: 1 | 3 | 4 }) {
  return sharp(input, raw ? { raw } : undefined)
    .rotate()
    .flatten({ background: "#fff7df" })
    .resize(thumbnailWidth, thumbnailHeight, { fit: "cover", position: "attention" })
    .jpeg({ quality: 82, mozjpeg: true })
    .toBuffer();
}

export async function createPatternCoverThumbnail(pdf: PDFProxy) {
  const candidates = [] as Array<{ data: Uint8ClampedArray; width: number; height: number; channels: 1 | 3 | 4 }>;
  for (let page = 1; page <= Math.min(pdf.numPages, 5); page += 1) {
    try {
      for (const image of await extractImages(pdf, page)) {
        const pixels = image.width * image.height;
        const ratio = image.width / image.height;
        if (pixels >= 80_000 && pixels <= 40_000_000 && ratio >= 0.28 && ratio <= 3.5) candidates.push(image);
      }
    } catch {
      // A malformed embedded image must not prevent a rendered cover fallback.
    }
  }
  candidates.sort((a, b) => b.width * b.height - a.width * a.height);
  for (const image of candidates) {
    try {
      const pixels = Buffer.from(image.data.buffer, image.data.byteOffset, image.data.byteLength);
      return await normalizeCover(pixels, { width: image.width, height: image.height, channels: image.channels });
    } catch {
      // Try the next candidate before falling back to a full page render.
    }
  }

  try {
    const rendered = await renderPageAsImage(pdf, 1, { canvasImport: () => import("@napi-rs/canvas"), width: 1600 });
    return await normalizeCover(Buffer.from(rendered));
  } catch {
    return null;
  }
}

export async function createPrivatePatternCover(pdf: PDFProxy, ownerId: string, patternId: string) {
  const thumbnail = await createPatternCoverThumbnail(pdf);
  if (!thumbnail) return null;
  const blob = await put(`patterns/${ownerId}/${patternId}/cover.jpg`, thumbnail, { access: "private", contentType: "image/jpeg", addRandomSuffix: false, allowOverwrite: true });
  return blob.url;
}
