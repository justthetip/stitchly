import "server-only";

import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "jose";
import { db } from "@/lib/db";

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_KEYS = createRemoteJWKSet(new URL(`${APPLE_ISSUER}/auth/keys`));
const SESSION_DAYS = 90;

export type NativeUser = { id: string; name: string | null; email: string | null };

export function hashToken(token: string) {
  return createHash("sha256").update(token).digest("hex");
}

export async function nativeUserForBearer(authorization: string | null): Promise<NativeUser | null> {
  if (!authorization?.startsWith("Bearer ")) return null;
  const token = authorization.slice(7).trim();
  if (!token) return null;
  const sql = db();
  const rows = await sql`
    update public.native_sessions s
    set last_used_at = now()
    from public.native_identities i
    where s.token_hash = ${hashToken(token)}
      and s.app_user_id = i.app_user_id
      and s.revoked_at is null
      and s.expires_at > now()
    returning s.app_user_id as id, i.name, i.email
  ` as NativeUser[];
  return rows[0] ?? null;
}

export async function verifyAppleIdentityToken(identityToken: string, rawNonce: string) {
  const audience = process.env.APPLE_CLIENT_ID ?? "com.lukejeffproduct.stitchly";
  const { payload } = await jwtVerify(identityToken, APPLE_KEYS, {
    issuer: APPLE_ISSUER,
    audience,
    algorithms: ["RS256"],
  });
  const expectedNonce = createHash("sha256").update(rawNonce).digest("hex");
  if (!payload.sub || payload.nonce !== expectedNonce) throw new Error("Apple identity could not be verified");
  return {
    subject: payload.sub,
    email: typeof payload.email === "string" ? payload.email : null,
    emailVerified: payload.email_verified === true || payload.email_verified === "true",
  };
}

export async function issueNativeSession(userId: string) {
  const token = randomBytes(32).toString("base64url");
  const expiresAt = new Date(Date.now() + SESSION_DAYS * 24 * 60 * 60 * 1000);
  const sql = db();
  await sql`insert into public.native_sessions (app_user_id, token_hash, expires_at) values (${userId}, ${hashToken(token)}, ${expiresAt.toISOString()})`;
  return { token, expiresAt };
}

function encryptionKey() {
  const secret = process.env.NATIVE_AUTH_SECRET;
  if (!secret) throw new Error("NATIVE_AUTH_SECRET is not configured");
  return createHash("sha256").update(secret).digest();
}

export function encryptRefreshToken(value: string) {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", encryptionKey(), iv);
  const encrypted = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
  return [iv, cipher.getAuthTag(), encrypted].map(part => part.toString("base64url")).join(".");
}

export function decryptRefreshToken(value: string) {
  const [iv, tag, encrypted] = value.split(".").map(part => Buffer.from(part, "base64url"));
  const decipher = createDecipheriv("aes-256-gcm", encryptionKey(), iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString("utf8");
}

async function appleClientSecret() {
  const keyId = process.env.APPLE_SIGN_IN_KEY_ID;
  const teamId = process.env.APPLE_TEAM_ID;
  const privateKey = process.env.APPLE_SIGN_IN_PRIVATE_KEY?.replace(/\\n/g, "\n");
  const clientId = process.env.APPLE_CLIENT_ID ?? "com.lukejeffproduct.stitchly";
  if (!keyId || !teamId || !privateKey) return null;
  const key = await importPKCS8(privateKey, "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId })
    .setIssuer(teamId)
    .setSubject(clientId)
    .setAudience(APPLE_ISSUER)
    .setIssuedAt()
    .setExpirationTime("180d")
    .sign(key);
}

async function appleTokenRequest(parameters: Record<string, string>) {
  const clientSecret = await appleClientSecret();
  if (!clientSecret) return null;
  const clientId = process.env.APPLE_CLIENT_ID ?? "com.lukejeffproduct.stitchly";
  const response = await fetch(`${APPLE_ISSUER}/auth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: clientId, client_secret: clientSecret, ...parameters }),
  });
  if (!response.ok) throw new Error("Apple token exchange failed");
  return response.json() as Promise<{ refresh_token?: string }>;
}

export async function exchangeAppleAuthorizationCode(code: string) {
  return appleTokenRequest({ code, grant_type: "authorization_code" });
}

export async function revokeAppleRefreshToken(token: string) {
  const clientSecret = await appleClientSecret();
  if (!clientSecret) return;
  const clientId = process.env.APPLE_CLIENT_ID ?? "com.lukejeffproduct.stitchly";
  const response = await fetch(`${APPLE_ISSUER}/auth/revoke`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: clientId, client_secret: clientSecret, token, token_type_hint: "refresh_token" }),
  });
  if (!response.ok) throw new Error("Apple credential revocation failed");
}
