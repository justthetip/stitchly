import { createHash } from "node:crypto";
import { db } from "@/lib/db";
import { apiError } from "@/lib/session";
import { issueNativeSession } from "@/lib/native-auth";

export async function POST(request: Request) {
  try {
    const body = await request.json() as { code?: string; verifier?: string };
    if (!body.code || !body.verifier) return Response.json({ error: "Exchange credentials are required" }, { status: 400 });
    const challenge = createHash("sha256").update(body.verifier).digest("base64url");
    const sql = db();
    const rows = await sql`update public.native_exchange_codes set consumed_at = now() where code_hash = ${createHash("sha256").update(body.code).digest("hex")} and pkce_challenge = ${challenge} and expires_at > now() and consumed_at is null returning app_user_id` as Array<{ app_user_id: string }>;
    if (!rows[0]) return Response.json({ error: "This sign-in link is invalid or expired" }, { status: 401 });
    const identities = await sql`select app_user_id as id, email, name from public.native_identities where app_user_id = ${rows[0].app_user_id} and provider = 'web' limit 1` as Array<{ id: string; email: string | null; name: string | null }>;
    const session = await issueNativeSession(rows[0].app_user_id);
    return Response.json({ user: identities[0], token: session.token, expires_at: session.expiresAt.toISOString() });
  } catch (error) { return apiError(error); }
}
