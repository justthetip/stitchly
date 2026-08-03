"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { FileUp, Plus, Search } from "lucide-react";
import { ScreenHeader } from "@/components/screen-header";
import { CraftArt } from "@/components/craft-art";
import { PatternCover } from "@/components/pattern-cover";
import { authClient } from "@/lib/auth-client";
import { cn } from "@/lib/utils";

type Pattern = {
  id: string;
  name: string;
  designer: string | null;
  craft: "knit" | "crochet";
  total_instructions: number;
  page_count: number | null;
  created_at: string;
  cover_url: string | null;
};

export default function LibraryPage() {
  const session = authClient.useSession();
  const [patterns, setPatterns] = useState<Pattern[]>([]);
  const [query, setQuery] = useState("");
  const [craft, setCraft] = useState("All");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  useEffect(() => {
    if (session.isPending) return;
    if (!session.data?.user) {
      const timer = setTimeout(() => setLoading(false), 0);
      return () => clearTimeout(timer);
    }
    let cancelled = false;
    fetch("/api/patterns")
      .then(async (response) => {
        const payload = await response.json();
        if (!response.ok)
          throw new Error(payload.error || "Could not load your patterns");
        if (!cancelled) {
          setPatterns(payload.patterns);
          setLoading(false);
        }
      })
      .catch((reason) => {
        if (!cancelled) {
          setError(
            reason instanceof Error
              ? reason.message
              : "Could not load your patterns",
          );
          setLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [session.data?.user, session.isPending]);
  const filtered = useMemo(
    () =>
      patterns.filter(
        (pattern) =>
          (craft === "All" || pattern.craft === craft.toLowerCase()) &&
          `${pattern.name} ${pattern.designer ?? ""}`
            .toLowerCase()
            .includes(query.toLowerCase()),
      ),
    [craft, patterns, query],
  );
  return (
    <div className="pb-8">
      <ScreenHeader
        title="Your pattern library"
        right={
          <Link
            href="/library/upload"
            className="flex size-10 items-center justify-center rounded-2xl bg-primary text-white shadow-md shadow-primary/20"
          >
            <Plus className="size-5" />
          </Link>
        }
      />
      <div className="px-5 pt-5 md:px-8">
        {!session.isPending && !session.data?.user ? (
          <SignInState />
        ) : loading ? (
          <p className="py-20 text-center text-sm font-bold text-muted-foreground">
            Loading your private library…
          </p>
        ) : error ? (
          <p className="rounded-2xl bg-red-50 p-4 text-sm font-bold text-red-700">
            {error}
          </p>
        ) : patterns.length === 0 ? (
          <EmptyLibrary />
        ) : (
          <>
            <div className="flex items-center gap-3 rounded-2xl border bg-white px-4 py-3 shadow-sm">
              <Search className="size-4 text-muted-foreground" />
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="Pattern, designer or craft…"
                className="w-full bg-transparent text-sm outline-none"
              />
            </div>
            <div className="mt-4 flex gap-2">
              {["All", "Knit", "Crochet"].map((tag) => (
                <button
                  key={tag}
                  onClick={() => setCraft(tag)}
                  className={cn(
                    "rounded-full px-4 py-2 text-xs font-extrabold",
                    craft === tag
                      ? "bg-[#17324d] text-white"
                      : "border bg-card text-muted-foreground",
                  )}
                >
                  {tag}
                </button>
              ))}
            </div>
            <p className="mt-6 text-xs font-extrabold uppercase tracking-[.15em] text-primary">
              {filtered.length} {filtered.length === 1 ? "pattern" : "patterns"}
            </p>
            <div className="mt-3 grid grid-cols-2 gap-4 md:grid-cols-3">
              {filtered.map((pattern, index) => (
                <Link
                  key={pattern.id}
                  href={`/library/${pattern.id}`}
                  className="stitch-card overflow-hidden p-2.5 transition hover:-translate-y-1"
                >
                  <div
                    className={cn(
                      "relative aspect-square overflow-hidden rounded-2xl",
                      [
                        "bg-[#dff4fb]",
                        "bg-[#ffe6a8]",
                        "bg-[#ffd9df]",
                        "bg-[#e3f0d1]",
                      ][index % 4],
                    )}
                  >
                    <PatternCover
                      coverUrl={pattern.cover_url}
                      craft={pattern.craft}
                      index={index}
                      alt={`${pattern.name} cover`}
                    />
                  </div>
                  <div className="px-1 pb-1 pt-3">
                    <p className="font-heading line-clamp-2 text-sm font-extrabold leading-tight">
                      {pattern.name}
                    </p>
                    <p className="mt-1 truncate text-[11px] text-muted-foreground">
                      {pattern.designer ||
                        `${pattern.page_count ?? "?"}-page PDF`}
                    </p>
                    <p className="mt-2 text-[10px] font-bold uppercase tracking-wide text-primary">
                      {pattern.craft} · {pattern.total_instructions} steps
                    </p>
                  </div>
                </Link>
              ))}
            </div>
            {filtered.length === 0 && (
              <p className="py-16 text-center text-sm text-muted-foreground">
                No patterns match that search.
              </p>
            )}
          </>
        )}
      </div>
    </div>
  );
}
function SignInState() {
  return (
    <div className="py-14 text-center">
      <CraftArt art="basket" className="mx-auto size-52" />
      <h1 className="font-heading mt-4 text-3xl font-black">
        Your private library awaits
      </h1>
      <p className="mx-auto mt-2 max-w-sm text-sm text-muted-foreground">
        Sign in to see PDFs and projects stored against your account.
      </p>
      <Link
        href="/sign-in"
        className="mt-6 inline-flex rounded-2xl bg-primary px-6 py-3.5 text-sm font-extrabold text-white"
      >
        Sign in
      </Link>
    </div>
  );
}
function EmptyLibrary() {
  return (
    <div className="py-10 text-center">
      <div className="relative mx-auto flex size-64 items-center justify-center rounded-full bg-[#dff4fb]">
        <CraftArt art="basket" className="size-52" />
      </div>
      <h1 className="font-heading mt-5 text-3xl font-black">
        Bring your patterns together
      </h1>
      <p className="mx-auto mt-2 max-w-sm text-sm leading-relaxed text-muted-foreground">
        Upload your first PDF. Stitchly will read its actual instructions and
        prepare them for review.
      </p>
      <Link
        href="/library/upload"
        className="mt-6 inline-flex items-center gap-2 rounded-2xl bg-primary px-6 py-3.5 text-sm font-extrabold text-white"
      >
        <FileUp className="size-4" />
        Upload a PDF
      </Link>
    </div>
  );
}
