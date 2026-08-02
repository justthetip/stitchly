"use client";

import { useEffect, useState } from "react";

export default function NativeConnectPage() {
  const [message, setMessage] = useState("Connecting Stitchly…");
  useEffect(() => {
    const challenge = new URLSearchParams(window.location.search).get("challenge");
    if (!challenge) { window.setTimeout(() => setMessage("This sign-in link is invalid."), 0); return; }
    fetch("/api/native-auth/web-exchange", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ challenge }) })
      .then(async response => {
        if (response.status === 401) {
          const next = `/native-connect?challenge=${encodeURIComponent(challenge)}`;
          window.location.replace(`/sign-in?next=${encodeURIComponent(next)}`);
          return null;
        }
        if (!response.ok) throw new Error("Stitchly could not connect this account.");
        return response.json() as Promise<{ code: string }>;
      })
      .then(result => { if (result) window.location.replace(`stitchly://auth?code=${encodeURIComponent(result.code)}`); })
      .catch(error => setMessage(error instanceof Error ? error.message : "Stitchly could not connect this account."));
  }, []);
  return <main className="flex min-h-screen items-center justify-center bg-[#ffb02b] px-6"><div className="max-w-sm rounded-3xl bg-white p-8 text-center shadow-xl"><p className="font-heading text-3xl font-black text-[#f2798f]">STITCHLY</p><p className="mt-4 font-semibold text-slate-700">{message}</p></div></main>;
}
