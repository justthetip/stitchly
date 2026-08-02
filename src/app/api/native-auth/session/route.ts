import { headers } from "next/headers";
import { db } from "@/lib/db";
import { apiError, requireUser } from "@/lib/session";
import { hashToken } from "@/lib/native-auth";

export async function GET() {
  try { return Response.json({ user: await requireUser() }); }
  catch (error) { return apiError(error); }
}

export async function DELETE() {
  try {
    await requireUser();
    const authorization = (await headers()).get("authorization");
    if (authorization?.startsWith("Bearer ")) {
      const sql = db();
      await sql`update public.native_sessions set revoked_at = now() where token_hash = ${hashToken(authorization.slice(7).trim())}`;
    }
    return new Response(null, { status: 204 });
  } catch (error) { return apiError(error); }
}
