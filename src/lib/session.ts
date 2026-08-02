import { auth } from "@/lib/auth-server";
import { headers } from "next/headers";
import { nativeUserForBearer } from "@/lib/native-auth";

export async function currentUser() {
  const nativeUser = await nativeUserForBearer((await headers()).get("authorization"));
  if (nativeUser) return nativeUser;
  const { data } = await auth.getSession();
  return data?.user ?? null;
}

export async function requireUser() {
  const user = await currentUser();
  if (!user) throw new Response("Authentication required", { status: 401 });
  return user;
}

export function apiError(error: unknown) {
  if (error instanceof Response) return error;
  console.error(error);
  return Response.json({ error: error instanceof Error ? error.message : "Unexpected error" }, { status: 500 });
}
