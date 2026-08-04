"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import { useParams } from "next/navigation";
import { FileText, Play, ShieldCheck } from "lucide-react";
import { ScreenHeader } from "@/components/screen-header";
import { PatternCover } from "@/components/pattern-cover";
import { AccountGateButton } from "@/components/account-gate";
import { authClient } from "@/lib/auth-client";
import { demoInstructions, demoPattern } from "@/lib/demo-data";
import {
  instructionLabel,
  type PatternInstructionRecord,
} from "@/lib/pattern-instructions";

type Pattern = {
  id: string;
  name: string;
  designer: string | null;
  craft: "knit" | "crochet";
  difficulty: string | null;
  yarn: string | null;
  tool: string | null;
  total_instructions: number;
  page_count: number | null;
  source: string;
  cover_url: string | null;
};

export default function PatternDetailPage() {
  const params = useParams<{ id: string }>();
  const session = authClient.useSession();
  const [pattern, setPattern] = useState<Pattern | null>(null);
  const [instructions, setInstructions] = useState<PatternInstructionRecord[]>(
    [],
  );
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const bundled = demoPattern(params.id);
    if (bundled) {
      const timer = setTimeout(() => {
        setPattern(bundled);
        setInstructions(demoInstructions);
        setLoading(false);
      }, 0);
      return () => clearTimeout(timer);
    }
    let cancelled = false;
    fetch(`/api/patterns/${params.id}`)
      .then(async (response) => {
        const payload = await response.json();
        if (!response.ok) throw new Error(payload.error || "Pattern not found");
        if (!cancelled) {
          setPattern(payload.pattern);
          setInstructions(payload.instructions);
          setLoading(false);
        }
      })
      .catch((reason) => {
        if (!cancelled) {
          setError(
            reason instanceof Error ? reason.message : "Pattern not found",
          );
          setLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [params.id]);

  const sections = useMemo(() => {
    const grouped = new Map<string, PatternInstructionRecord[]>();
    for (const instruction of instructions) {
      grouped.set(instruction.section, [
        ...(grouped.get(instruction.section) ?? []),
        instruction,
      ]);
    }
    return [...grouped.entries()];
  }, [instructions]);

  if (loading)
    return (
      <p className="py-24 text-center text-sm font-bold text-muted-foreground">
        Opening your pattern…
      </p>
    );
  if (!pattern) {
    return (
      <div className="px-5 py-24 text-center">
        <h1 className="font-heading text-2xl font-black">
          Pattern unavailable
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">{error}</p>
        <Link
          href="/library"
          className="mt-5 inline-flex text-sm font-extrabold text-primary"
        >
          Back to library
        </Link>
      </div>
    );
  }

  const uncertain = instructions.filter(
    (instruction) => instruction.confidence === "low",
  ).length;
  return (
    <div className="pb-10">
      <ScreenHeader back="/library" title={pattern.name} />
      <div className="mx-auto max-w-3xl px-5 pt-5 md:px-8">
        <div className="relative flex aspect-[16/8] items-center justify-center overflow-hidden rounded-3xl bg-[#dff4fb]">
          <div className="absolute -right-12 -top-12 size-48 rounded-full bg-[#f58ba2]/60" />
          <PatternCover
            coverUrl={pattern.cover_url}
            craft={pattern.craft}
            alt={`${pattern.name} cover`}
          />
        </div>
        <p className="mt-5 text-xs font-extrabold uppercase tracking-[.15em] text-primary">
          {pattern.craft} pattern
        </p>
        <h1 className="font-heading mt-1 text-3xl font-black">
          {pattern.name}
        </h1>
        <p className="mt-1 text-sm text-muted-foreground">
          {pattern.designer
            ? `Designed by ${pattern.designer}`
            : `Imported from a ${pattern.page_count ?? "multi"}-page PDF`}
        </p>
        <div className="mt-5 grid grid-cols-2 gap-3 md:grid-cols-4">
          <Stat label="Instructions" value={`${pattern.total_instructions}`} />
          <Stat label="Sections" value={`${sections.length}`} />
          <Stat
            label="Confidence"
            value={uncertain ? `${uncertain} to check` : "Reviewed"}
          />
          <Stat label="File" value={pattern.id === "pattern-demo" ? "Demo" : "Private"} />
        </div>
        <div className="mt-6 flex flex-col gap-3 sm:flex-row">
          {session.data?.user ? (
            <Link href={`/projects/new?pattern=${pattern.id}`} className="flex flex-1 items-center justify-center gap-2 rounded-2xl bg-primary px-5 py-4 font-heading text-sm font-extrabold text-white">
              <Play className="size-4" />Start a project
            </Link>
          ) : (
            <AccountGateButton title="Create an account to start a project" message="Projects save your yarn, notes, and place in the pattern across devices." next={`/projects/new?pattern=${pattern.id}`} className="flex flex-1 items-center justify-center gap-2 rounded-2xl bg-primary px-5 py-4 font-heading text-sm font-extrabold text-white">
              <Play className="size-4" />Start a project
            </AccountGateButton>
          )}
          {pattern.id === "pattern-demo" ? (
            <button disabled className="flex flex-1 items-center justify-center gap-2 rounded-2xl border bg-white px-5 py-4 font-heading text-sm font-extrabold opacity-60">
              <FileText className="size-4" />Demo PDF coming next
            </button>
          ) : (
            <a href={`/api/patterns/${pattern.id}/original`} target="_blank" rel="noreferrer" className="flex flex-1 items-center justify-center gap-2 rounded-2xl border bg-white px-5 py-4 font-heading text-sm font-extrabold">
              <FileText className="size-4" />Open original PDF
            </a>
          )}
        </div>

        <section className="mt-8">
          <p className="text-xs font-extrabold uppercase tracking-[.15em] text-primary">
            Pattern guide
          </p>
          <h2 className="font-heading mt-1 text-2xl font-black">
            What you’ll work through
          </h2>
          <div className="mt-4 space-y-3">
            {sections.map(([name, sectionInstructions]) => (
              <div key={name} className="stitch-card p-4">
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <h3 className="font-heading font-extrabold">{name}</h3>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {sectionInstructions[0].section_quantity > 1
                        ? `Make ${sectionInstructions[0].section_quantity} · `
                        : ""}
                      {sectionInstructions.length}{" "}
                      {sectionInstructions.length === 1
                        ? "instruction"
                        : "instructions"}
                    </p>
                  </div>
                  <span className="rounded-full bg-secondary px-3 py-1 text-xs font-black">
                    {instructionLabel(sectionInstructions[0])}
                  </span>
                </div>
                <p className="mt-3 line-clamp-2 text-sm font-semibold leading-relaxed">
                  {sectionInstructions[0].instructions}
                </p>
              </div>
            ))}
          </div>
        </section>

        <div className="mt-7 flex items-start gap-3 rounded-2xl bg-[#17324d] p-4 text-white">
          <ShieldCheck className="mt-0.5 size-5 shrink-0 text-[#59c3eb]" />
          <div>
            <p className="text-sm font-extrabold">{pattern.id === "pattern-demo" ? "Safe to explore" : "Private to your account"}</p>
            <p className="mt-1 text-xs leading-relaxed text-white/65">
              {pattern.id === "pattern-demo" ? "This bundled example is separate from private account data. Sign in only when you want to save or upload." : "The original is streamed through Stitchly only after ownership is checked. Its Blob URL is never public."}
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="stitch-card p-3">
      <p className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">
        {label}
      </p>
      <p className="font-heading mt-1 text-sm font-extrabold">{value}</p>
    </div>
  );
}
