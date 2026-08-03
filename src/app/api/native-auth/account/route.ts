import { headers } from "next/headers";
import { del } from "@vercel/blob";
import { db } from "@/lib/db";
import { apiError, requireUser } from "@/lib/session";
import { decryptRefreshToken, revokeAppleRefreshToken } from "@/lib/native-auth";

export async function DELETE() {
  try {
    const user = await requireUser();
    if (!(await headers()).get("authorization")?.startsWith("Bearer ")) return Response.json({ error: "Native authentication required" }, { status: 400 });
    const sql = db();
    const identities = await sql`select refresh_token_encrypted from public.native_identities where app_user_id = ${user.id} and provider = 'apple'` as Array<{ refresh_token_encrypted: string | null }>;
    const patternAssets = await sql`select blob_url, cover_blob_url from public.patterns where owner_id = ${user.id}` as Array<{ blob_url: string | null; cover_blob_url: string | null }>;
    if (identities[0]?.refresh_token_encrypted) await revokeAppleRefreshToken(decryptRefreshToken(identities[0].refresh_token_encrypted));
    await sql.transaction([
      sql`delete from public.project_notes where owner_id = ${user.id}`,
      sql`delete from public.projects where owner_id = ${user.id}`,
      sql`delete from public.patterns where owner_id = ${user.id}`,
      sql`delete from public.native_sessions where app_user_id = ${user.id}`,
      sql`delete from public.native_identities where app_user_id = ${user.id}`,
    ]);
    const assetUrls = patternAssets.flatMap((pattern) => [pattern.blob_url, pattern.cover_blob_url]).filter((url): url is string => Boolean(url));
    if (assetUrls.length) await del(assetUrls);
    return new Response(null, { status: 204 });
  } catch (error) { return apiError(error); }
}
