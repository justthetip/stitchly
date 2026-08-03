"use client";

import { FormEvent, Suspense, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { PatternCover } from "@/components/pattern-cover";
import { ScreenHeader } from "@/components/screen-header";

type Pattern = {
  id: string;
  name: string;
  craft: "knit" | "crochet";
  total_instructions: number;
  cover_url: string | null;
};
export default function NewProjectPage() {
  return (
    <Suspense
      fallback={
        <p className="py-24 text-center text-sm font-bold text-muted-foreground">
          Preparing your project…
        </p>
      }
    >
      <NewProjectForm />
    </Suspense>
  );
}
function NewProjectForm() {
  const router = useRouter();
  const search = useSearchParams();
  const id = search.get("pattern");
  const [pattern, setPattern] = useState<Pattern | null>(null);
  const [name, setName] = useState("");
  const [yarn, setYarn] = useState("");
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  useEffect(() => {
    if (!id) return;
    let cancelled = false;
    fetch(`/api/patterns/${id}`)
      .then(async (response) => {
        const payload = await response.json();
        if (!response.ok) throw new Error(payload.error || "Pattern not found");
        if (!cancelled) {
          setPattern(payload.pattern);
          setName(`${payload.pattern.name} project`);
        }
      })
      .catch((reason) => {
        if (!cancelled)
          setError(
            reason instanceof Error ? reason.message : "Pattern not found",
          );
      });
    return () => {
      cancelled = true;
    };
  }, [id]);
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!pattern) return;
    setBusy(true);
    setError("");
    try {
      const response = await fetch("/api/projects", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ patternId: pattern.id, name, yarn, notes }),
      });
      const payload = await response.json();
      if (!response.ok)
        throw new Error(payload.error || "Could not create project");
      router.push(`/projects/${payload.project.id}/reader`);
    } catch (reason) {
      setError(
        reason instanceof Error ? reason.message : "Could not create project",
      );
      setBusy(false);
    }
  }
  if (!id)
    return (
      <div className="px-5 py-24 text-center">
        <h1 className="font-heading text-2xl font-black">
          Choose a pattern first
        </h1>
        <Link
          href="/library"
          className="mt-5 inline-flex text-sm font-extrabold text-primary"
        >
          Open your library
        </Link>
      </div>
    );
  if (!pattern)
    return (
      <p className="px-5 py-24 text-center text-sm font-bold text-muted-foreground">
        {error || "Loading pattern…"}
      </p>
    );
  return (
    <div className="pb-28">
      <ScreenHeader back={`/library/${pattern.id}`} title="Start a project" />
      <form onSubmit={submit} className="mx-auto max-w-2xl px-5 pt-6 md:px-8">
        <div className="stitch-card flex items-center gap-4 p-4">
          <div className="relative size-16 overflow-hidden rounded-2xl bg-accent">
            <PatternCover
              coverUrl={pattern.cover_url}
              craft={pattern.craft}
              alt={`${pattern.name} cover`}
            />
          </div>
          <div>
            <p className="font-heading font-extrabold">{pattern.name}</p>
            <p className="text-xs text-muted-foreground">
              {pattern.total_instructions} guided instructions
            </p>
            <a href={`/api/patterns/${pattern.id}/original`} target="_blank" rel="noreferrer" className="mt-1 inline-flex text-xs font-extrabold text-primary">
              View original PDF
            </a>
          </div>
        </div>
        <div className="mt-6 space-y-5">
          <Field label="Project name">
            <input
              value={name}
              onChange={(event) => setName(event.target.value)}
              required
              className="w-full rounded-2xl border bg-white px-4 py-3.5 outline-none focus:ring-2 focus:ring-primary/30"
            />
          </Field>
          <Field label="Yarn you’re using" hint="Optional">
            <input
              value={yarn}
              onChange={(event) => setYarn(event.target.value)}
              placeholder="Brand, colourway and dye lot"
              className="w-full rounded-2xl border bg-white px-4 py-3.5 outline-none focus:ring-2 focus:ring-primary/30"
            />
          </Field>
          <Field label="Project note" hint="Optional">
            <textarea
              value={notes}
              onChange={(event) => setNotes(event.target.value)}
              placeholder="Sizing, modifications or who it’s for"
              rows={4}
              className="w-full resize-none rounded-2xl border bg-white px-4 py-3.5 outline-none focus:ring-2 focus:ring-primary/30"
            />
          </Field>
        </div>
        {error && (
          <p className="mt-4 rounded-xl bg-red-50 p-3 text-sm font-bold text-red-700">
            {error}
          </p>
        )}
        <button
          disabled={busy || !name.trim()}
          className="mt-7 w-full rounded-2xl bg-primary px-5 py-4 font-heading font-extrabold text-white disabled:opacity-50"
        >
          {busy ? "Creating your project…" : "Create project & start making"}
        </button>
      </form>
    </div>
  );
}
function Field({
  label,
  hint,
  children,
}: {
  label: string;
  hint?: string;
  children: React.ReactNode;
}) {
  return (
    <label className="block">
      <span className="mb-2 flex items-center justify-between text-sm font-extrabold">
        <span>{label}</span>
        {hint && (
          <span className="text-xs font-normal text-muted-foreground">
            {hint}
          </span>
        )}
      </span>
      {children}
    </label>
  );
}
