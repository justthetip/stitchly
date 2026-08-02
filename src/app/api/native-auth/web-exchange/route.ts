import { createHash, randomBytes } from "node:crypto";
import { db } from "@/lib/db";
import { apiError, requireUser } from "@/lib/session";

export async function POST(request: Request) {
  try {
    const user = await requireUser();
    const body = await request.json() as { challenge?: string };
    if (!body.challenge || !/^[A-Za-z0-9_-]{43}$/.test(body.challenge)) return Response.json({ error: "A valid app challenge is required" }, { status: 400 });
    const code = randomBytes(32).toString("base64url");
    const sql = db();
    await sql.transaction([
      sql`insert into public.native_identities (app_user_id, provider, provider_subject, email, name)
          values (${user.id}, 'web', ${user.id}, ${user.email ?? null}, ${user.name ?? null})
          on conflict (provider, provider_subject) do update set email = excluded.email, name = excluded.name, updated_at = now()`,
      sql`insert into public.native_exchange_codes (app_user_id, code_hash, pkce_challenge) values (${user.id}, ${createHash("sha256").update(code).digest("hex")}, ${body.challenge})`,
      sql`delete from public.native_exchange_codes where expires_at < now() or consumed_at is not null`,
    ]);
    return Response.json({ code });
  } catch (error) { return apiError(error); }
}
