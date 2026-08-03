import { db, type DbPattern } from "@/lib/db";
import { apiError, requireUser } from "@/lib/session";

export async function GET() {
  try {
    const user = await requireUser();
    const sql = db();
    const patterns = await sql`select id, owner_id, name, designer, craft, difficulty, yarn, tool, total_instructions, source, blob_url, page_count, created_at, updated_at, case when cover_blob_url is not null then '/api/patterns/' || id || '/cover' else null end as cover_url from public.patterns where owner_id = ${user.id} order by created_at desc` as DbPattern[];
    return Response.json({ patterns });
  } catch (error) { return apiError(error); }
}
