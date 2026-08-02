import { db } from "@/lib/db";
import { issueNativeSession } from "@/lib/native-auth";
import { apiError } from "@/lib/session";

type AuthUser = { id: string; email: string; name: string | null };
type AuthResponse = { user?: AuthUser; message?: string };

export async function POST(request: Request) {
  try {
    const body = await request.json() as { email?: string; password?: string; name?: string; mode?: "sign-in" | "sign-up" };
    const email = body.email?.trim().toLowerCase();
    const name = body.name?.trim();
    if (!email || !email.includes("@") || email.length > 254) return Response.json({ error: "Enter a valid email address." }, { status: 400 });
    if (!body.password || body.password.length < 8 || body.password.length > 128) return Response.json({ error: "Password must be between 8 and 128 characters." }, { status: 400 });
    if (body.mode === "sign-up" && (!name || name.length > 100)) return Response.json({ error: "Enter your name." }, { status: 400 });
    const origin = new URL(request.url).origin;
    const path = body.mode === "sign-up" ? "/api/auth/sign-up/email" : "/api/auth/sign-in/email";
    const authResponse = await fetch(new URL(path, origin), { method: "POST", headers: { "Content-Type": "application/json", Origin: origin }, body: JSON.stringify(body.mode === "sign-up" ? { email, password: body.password, name } : { email, password: body.password }), cache: "no-store" });
    const result = await authResponse.json().catch(() => ({})) as AuthResponse;
    if (!authResponse.ok || !result.user) return Response.json({ error: result.message ?? "Email sign-in failed." }, { status: authResponse.status });
    const sql = db();
    const rows = await sql`
      insert into public.native_identities (app_user_id, provider, provider_subject, email, name)
      values (${result.user.id}, 'email', ${result.user.id}, ${result.user.email}, ${result.user.name})
      on conflict (provider, provider_subject) do update set email = excluded.email, name = excluded.name, updated_at = now()
      returning app_user_id as id, email, name
    ` as Array<{ id: string; email: string | null; name: string | null }>;
    const session = await issueNativeSession(rows[0].id);
    return Response.json({ user: rows[0], token: session.token, expires_at: session.expiresAt.toISOString() });
  } catch (error) { return apiError(error); }
}
