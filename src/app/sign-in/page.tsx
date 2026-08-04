"use client";

import { FormEvent, Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { authClient } from "@/lib/auth-client";
import { CraftArt } from "@/components/craft-art";

export default function SignInPage() {
  return <Suspense fallback={<p className="py-24 text-center text-sm font-bold text-muted-foreground">Opening sign in…</p>}><SignInForm /></Suspense>;
}

function SignInForm() {
  const router = useRouter();
  const search = useSearchParams();
  const [mode, setMode] = useState<"in" | "up">(search.get("mode") === "up" ? "up" : "in");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const requestedNext = search.get("next") || "/";
  const next = requestedNext.startsWith("/") && !requestedNext.startsWith("//") ? requestedNext : "/";

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setError("");
    const data = new FormData(event.currentTarget);
    const credentials = { email: String(data.get("email")), password: String(data.get("password")), name: String(data.get("name") || "Maker") };
    const result = mode === "up" ? await authClient.signUp.email(credentials) : await authClient.signIn.email(credentials);
    setBusy(false);
    if (result.error) setError(result.error.message || "Something went wrong");
    else router.replace(next);
  }

  return <div className="grid min-h-[calc(100dvh-6rem)] md:grid-cols-2">
    <div className="relative flex min-h-72 items-center justify-center overflow-hidden bg-[#f5a623]"><div className="stitch-pattern absolute inset-0 opacity-35"/><div className="absolute -left-12 -top-12 size-48 rounded-full bg-[#f58ba2]"/><CraftArt art="basket" className="relative size-64"/></div>
    <div className="flex items-center px-6 py-10 md:px-12"><div className="mx-auto w-full max-w-sm"><p className="font-heading text-3xl font-black">STITCHLY</p><h1 className="font-heading mt-8 text-2xl font-extrabold">{mode === "in" ? "Welcome back, maker" : "Make yourself at home"}</h1><p className="mt-1 text-sm text-muted-foreground">Sign in when you’re ready to save, sync, or upload.</p>
      <button disabled={busy} onClick={() => authClient.signIn.social({ provider: "google", callbackURL: next })} className="mt-6 w-full rounded-2xl border bg-white px-4 py-3 text-sm font-extrabold shadow-sm disabled:opacity-50">Continue with Google</button>
      <div className="my-5 flex items-center gap-3 text-xs text-muted-foreground"><span className="h-px flex-1 bg-border"/>or use email<span className="h-px flex-1 bg-border"/></div>
      <form onSubmit={submit} className="space-y-3">{mode === "up" && <input name="name" required placeholder="Your name" className="w-full rounded-2xl border bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-primary/30"/>}<input name="email" type="email" required placeholder="Email address" className="w-full rounded-2xl border bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-primary/30"/><input name="password" type="password" minLength={8} required placeholder="Password" className="w-full rounded-2xl border bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-primary/30"/>{error && <p className="text-sm font-semibold text-primary">{error}</p>}<button disabled={busy} className="w-full rounded-2xl bg-primary px-4 py-3.5 font-heading font-extrabold text-white disabled:opacity-50">{busy ? (mode === "up" ? "Creating your account…" : "Signing you in…") : mode === "in" ? "Sign in" : "Create account"}</button></form>
      <button disabled={busy} onClick={() => setMode(mode === "in" ? "up" : "in")} className="mt-5 text-sm font-bold text-primary disabled:opacity-50">{mode === "in" ? "New here? Create an account" : "Already have an account? Sign in"}</button><button disabled={busy} onClick={() => router.back()} className="mt-5 block text-xs font-bold text-muted-foreground disabled:opacity-50">← Keep exploring</button>
    </div></div>
  </div>;
}
