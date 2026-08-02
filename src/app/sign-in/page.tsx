"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { authClient } from "@/lib/auth-client";
import { CraftArt } from "@/components/craft-art";

export default function SignInPage(){
  const router=useRouter(); const [mode,setMode]=useState<"in"|"up">("in"); const [busy,setBusy]=useState(false); const [error,setError]=useState("");
  async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();setBusy(true);setError("");const data=new FormData(e.currentTarget);const credentials={email:String(data.get("email")),password:String(data.get("password")),name:String(data.get("name")||"Maker")};const result=mode==="up"?await authClient.signUp.email(credentials):await authClient.signIn.email(credentials);setBusy(false);if(result.error)setError(result.error.message||"Something went wrong");else router.push("/");}
  return <div className="grid min-h-[calc(100dvh-6rem)] md:grid-cols-2">
    <div className="relative flex min-h-72 items-center justify-center overflow-hidden bg-[#f5a623]"><div className="stitch-pattern absolute inset-0 opacity-35"/><div className="absolute -left-12 -top-12 size-48 rounded-full bg-[#f58ba2]"/><CraftArt art="basket" className="relative size-64"/></div>
    <div className="flex items-center px-6 py-10 md:px-12"><div className="mx-auto w-full max-w-sm"><p className="font-heading text-3xl font-black">STITCHLY</p><h1 className="font-heading mt-8 text-2xl font-extrabold">{mode==="in"?"Welcome back, maker":"Make yourself at home"}</h1><p className="mt-1 text-sm text-muted-foreground">Your next instruction is waiting.</p>
      <button onClick={()=>authClient.signIn.social({provider:"google",callbackURL:"/"})} className="mt-6 w-full rounded-2xl border bg-white px-4 py-3 text-sm font-extrabold shadow-sm">Continue with Google</button>
      <div className="my-5 flex items-center gap-3 text-xs text-muted-foreground"><span className="h-px flex-1 bg-border"/>or use email<span className="h-px flex-1 bg-border"/></div>
      <form onSubmit={submit} className="space-y-3">{mode==="up"&&<input name="name" required placeholder="Your name" className="w-full rounded-2xl border bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-primary/30"/>}<input name="email" type="email" required placeholder="Email address" className="w-full rounded-2xl border bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-primary/30"/><input name="password" type="password" minLength={8} required placeholder="Password" className="w-full rounded-2xl border bg-white px-4 py-3 outline-none focus:ring-2 focus:ring-primary/30"/>{error&&<p className="text-sm font-semibold text-primary">{error}</p>}<button disabled={busy} className="w-full rounded-2xl bg-primary px-4 py-3.5 font-heading font-extrabold text-white disabled:opacity-50">{busy?"One moment…":mode==="in"?"Sign in":"Create account"}</button></form>
      <button onClick={()=>setMode(mode==="in"?"up":"in")} className="mt-5 text-sm font-bold text-primary">{mode==="in"?"New here? Create an account":"Already have an account? Sign in"}</button><button onClick={()=>router.push("/")} className="mt-5 block text-xs font-bold text-muted-foreground">Explore the demo first →</button>
    </div></div>
  </div>
}
