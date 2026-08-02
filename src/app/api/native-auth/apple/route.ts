import { randomUUID } from "node:crypto";
import { db } from "@/lib/db";
import { apiError } from "@/lib/session";
import { encryptRefreshToken, exchangeAppleAuthorizationCode, issueNativeSession, verifyAppleIdentityToken } from "@/lib/native-auth";

export async function POST(request: Request) {
  try {
    const body = await request.json() as { identityToken?: string; authorizationCode?: string; nonce?: string; name?: string };
    if (!body.identityToken || !body.nonce) return Response.json({ error: "Apple credentials are required" }, { status: 400 });
    const apple = await verifyAppleIdentityToken(body.identityToken, body.nonce);
    const sql = db();
    const existing = await sql`select app_user_id, email, name from public.native_identities where provider = 'apple' and provider_subject = ${apple.subject}` as Array<{ app_user_id: string; email: string | null; name: string | null }>;
    let userId = existing[0]?.app_user_id;
    if (!userId && apple.email && apple.emailVerified) {
      const webUsers = await sql`select id::text as id from neon_auth.user where lower(email) = lower(${apple.email}) limit 1` as Array<{ id: string }>;
      userId = webUsers[0]?.id;
    }
    userId ??= randomUUID();

    let encryptedRefreshToken: string | null = null;
    if (body.authorizationCode) {
      const exchanged = await exchangeAppleAuthorizationCode(body.authorizationCode);
      if (exchanged?.refresh_token) encryptedRefreshToken = encryptRefreshToken(exchanged.refresh_token);
    }
    const displayName = body.name?.trim() || existing[0]?.name || null;
    const rows = await sql`
      insert into public.native_identities (app_user_id, provider, provider_subject, email, name, refresh_token_encrypted)
      values (${userId}, 'apple', ${apple.subject}, ${apple.email}, ${displayName}, ${encryptedRefreshToken})
      on conflict (provider, provider_subject) do update set
        email = coalesce(excluded.email, public.native_identities.email),
        name = coalesce(excluded.name, public.native_identities.name),
        refresh_token_encrypted = coalesce(excluded.refresh_token_encrypted, public.native_identities.refresh_token_encrypted),
        updated_at = now()
      returning app_user_id as id, email, name
    ` as Array<{ id: string; email: string | null; name: string | null }>;
    const session = await issueNativeSession(rows[0].id);
    return Response.json({ user: rows[0], token: session.token, expires_at: session.expiresAt.toISOString() });
  } catch (error) { return apiError(error); }
}
