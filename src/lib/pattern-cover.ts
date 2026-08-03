import { put } from "@vercel/blob";
import sharp from "sharp";
import { extractImages, type getDocumentProxy } from "unpdf";

type PDFProxy = Awaited<ReturnType<typeof getDocumentProxy>>;

export async function createPatternCoverThumbnail(pdf: PDFProxy) {
  const candidates = [] as Array<{ data: Uint8ClampedArray; width: number; height: number; channels: 1 | 3 | 4 }>;
  for (let page = 1; page <= Math.min(pdf.numPages, 3); page += 1) {
    for (const image of await extractImages(pdf, page)) {
      const pixels = image.width * image.height;
      const ratio = image.width / image.height;
      if (pixels >= 160_000 && pixels <= 24_000_000 && ratio >= 0.5 && ratio <= 2) candidates.push(image);
    }
  }
  candidates.sort((a, b) => b.width * b.height - a.width * a.height);
  if (!candidates[0]) return null;
  const image = candidates[0];
  const thumbnail = await sharp(image.data, { raw: { width: image.width, height: image.height, channels: image.channels } })
    .rotate()
    .resize(1200, 900, { fit: "cover", position: "attention", withoutEnlargement: true })
    .jpeg({ quality: 82, mozjpeg: true })
    .toBuffer();
  return thumbnail;
}

export async function createPrivatePatternCover(pdf: PDFProxy, ownerId: string, patternId: string) {
  const thumbnail = await createPatternCoverThumbnail(pdf);
  if (!thumbnail) return null;
  const blob = await put(`patterns/${ownerId}/${patternId}/cover.jpg`, thumbnail, { access: "private", contentType: "image/jpeg", addRandomSuffix: false, allowOverwrite: true });
  return blob.url;
}
