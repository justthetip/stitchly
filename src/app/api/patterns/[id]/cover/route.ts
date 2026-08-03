import { get } from "@vercel/blob";
import { db } from "@/lib/db";
import { apiError, requireUser } from "@/lib/session";

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const user = await requireUser(); const { id } = await params; const sql = db();
    const rows = await sql`select cover_blob_url from public.patterns where id = ${id} and owner_id = ${user.id}` as Array<{ cover_blob_url: string | null }>;
    if (!rows[0]?.cover_blob_url) return new Response(null, { status: 404 });
    const result = await get(rows[0].cover_blob_url, { access: "private" });
    if (!result?.stream || result.statusCode !== 200) return new Response(null, { status: 404 });
    return new Response(result.stream, { headers: { "Content-Type": "image/jpeg", "Cache-Control": "private, max-age=3600" } });
  } catch (error) { return apiError(error); }
}
