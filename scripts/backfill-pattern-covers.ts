import { get } from "@vercel/blob";
import { neon } from "@neondatabase/serverless";
import { getDocumentProxy } from "unpdf";
import { createPrivatePatternCover } from "../src/lib/pattern-cover.ts";

const databaseUrl = process.env.DATABASE_URL;

async function main() {
  if (!databaseUrl) throw new Error("DATABASE_URL is not configured");
  const sql = neon(databaseUrl);
  const patterns = await sql`
    select id, owner_id, blob_url
    from public.patterns
    where cover_blob_url is null and blob_url is not null
    order by created_at
  ` as Array<{ id: string; owner_id: string; blob_url: string }>;

  let created = 0;
  let unsuitable = 0;
  let failed = 0;

  for (const pattern of patterns) {
    try {
      const result = await get(pattern.blob_url, { access: "private" });
      if (!result?.stream || result.statusCode !== 200 || result.blob.contentType !== "application/pdf") {
        failed += 1;
        continue;
      }
      const pdf = await getDocumentProxy(new Uint8Array(await new Response(result.stream).arrayBuffer()));
      const coverUrl = await createPrivatePatternCover(pdf, pattern.owner_id, pattern.id);
      if (!coverUrl) {
        unsuitable += 1;
        continue;
      }
      await sql`update public.patterns set cover_blob_url = ${coverUrl}, updated_at = now() where id = ${pattern.id} and cover_blob_url is null`;
      created += 1;
    } catch {
      failed += 1;
    }
  }

  console.log(JSON.stringify({ examined: patterns.length, created, unsuitable, failed }));
}

main().catch(() => {
  console.error("Pattern cover backfill failed.");
  process.exitCode = 1;
});
