"use client";

import { Suspense, useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { AlertTriangle, Check, FileText, Pencil, Plus, Sparkles } from "lucide-react";
import { ScreenHeader } from "@/components/screen-header";
import {
  instructionLabel,
  type PatternInstructionRecord,
} from "@/lib/pattern-instructions";
import { cn } from "@/lib/utils";

type ParsedPayload = {
  pattern: { id: string; name: string; page_count: number | null };
  instructions: PatternInstructionRecord[];
};

export default function ReviewParsePage() {
  return (
    <Suspense fallback={<p className="py-24 text-center text-sm font-bold text-muted-foreground">Loading extracted instructions…</p>}>
      <ReviewParseInner />
    </Suspense>
  );
}

function ReviewParseInner() {
  const router = useRouter();
  const search = useSearchParams();
  const patternId = search.get("pattern");
  const [pattern, setPattern] = useState<ParsedPayload["pattern"] | null>(null);
  const [instructions, setInstructions] = useState<PatternInstructionRecord[]>([]);
  const [editing, setEditing] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    async function load() {
      try {
        const cached = sessionStorage.getItem("stitchly:parsed-pattern");
        if (cached) {
          const payload = JSON.parse(cached) as ParsedPayload;
          if (!patternId || payload.pattern.id === patternId) {
            if (!cancelled) {
              setPattern(payload.pattern);
              setInstructions(payload.instructions);
              setLoading(false);
            }
            return;
          }
        }
        if (!patternId) throw new Error("No parsed pattern was selected");
        const response = await fetch(`/api/patterns/${patternId}`);
        const payload = await response.json();
        if (!response.ok) throw new Error(payload.error || "Could not load parsed pattern");
        if (!cancelled) {
          setPattern(payload.pattern);
          setInstructions(payload.instructions);
          setLoading(false);
        }
      } catch (reason) {
        if (!cancelled) {
          setError(reason instanceof Error ? reason.message : "Could not load parsed pattern");
          setLoading(false);
        }
      }
    }
    load();
    return () => {
      cancelled = true;
    };
  }, [patternId]);

  async function save() {
    if (!pattern) return;
    setSaving(true);
    setError("");
    try {
      const response = await fetch(`/api/patterns/${pattern.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          instructions: instructions.map((instruction, index) => ({
            position: index + 1,
            section: instruction.section,
            sectionQuantity: instruction.section_quantity,
            sectionPosition: instruction.section_position,
            instructionKind: instruction.instruction_kind,
            sourceLabel: instruction.source_label,
            instructionNumber: instruction.instruction_number,
            instructionNumberEnd: instruction.instruction_number_end,
            instructions: instruction.instructions,
            notes: instruction.notes,
            stitchCount: instruction.stitch_count,
            optional: instruction.optional,
            sourceGroup: instruction.source_group,
            confidence: instruction.confidence,
          })),
        }),
      });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || "Could not save the reviewed instructions");
      sessionStorage.removeItem("stitchly:parsed-pattern");
      router.push(`/library/${pattern.id}`);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Could not save the reviewed instructions");
      setSaving(false);
    }
  }

  async function cancel() {
    if (pattern) await fetch(`/api/patterns/${pattern.id}`, { method: "DELETE" });
    sessionStorage.removeItem("stitchly:parsed-pattern");
    router.push("/library");
  }

  const sectionCount = useMemo(
    () => new Set(instructions.map((instruction) => instruction.section)).size,
    [instructions],
  );

  if (loading) return <div className="flex min-h-[60dvh] items-center justify-center text-sm font-bold text-muted-foreground">Loading extracted instructions…</div>;
  if (!pattern || !instructions.length) {
    return (
      <div className="mx-auto max-w-md px-5 py-20 text-center">
        <AlertTriangle className="mx-auto size-8 text-primary" />
        <h1 className="font-heading mt-4 text-2xl font-black">No instructions to review</h1>
        <p className="mt-2 text-sm text-muted-foreground">{error || "Try uploading the pattern again."}</p>
        <Link href="/library/upload" className="mt-6 inline-flex rounded-2xl bg-primary px-5 py-3 text-sm font-extrabold text-white">Choose another PDF</Link>
      </div>
    );
  }

  const low = instructions.filter((instruction) => instruction.confidence === "low").length;
  const medium = instructions.filter((instruction) => instruction.confidence === "medium").length;

  return (
    <div className="flex flex-col pb-32">
      <ScreenHeader
        back="/library/upload"
        title="Check your pattern guide"
        subtitle={`${sectionCount} sections · ${instructions.length} steps from ${pattern.page_count ?? "your"} pages`}
      />
      <div className="border-b bg-muted/40 px-5 py-3 md:px-8">
        <div className="flex items-center gap-3">
          <span className="flex size-10 items-center justify-center rounded-xl bg-white"><FileText className="size-4" /></span>
          <div className="min-w-0">
            <p className="truncate text-sm font-extrabold">{pattern.name}</p>
            <p className="text-xs text-muted-foreground">Sections keep repeated Round 1s in the right piece</p>
          </div>
        </div>
      </div>
      <div className="mx-auto w-full max-w-3xl px-5 pt-5 md:px-8">
        <div className="rounded-2xl border border-primary/20 bg-primary/5 p-4">
          <div className="flex gap-3">
            <Sparkles className="mt-0.5 size-4 shrink-0 text-primary" />
            <div>
              <p className="text-sm font-extrabold">Review the structure and wording</p>
              <p className="mt-1 text-xs leading-relaxed text-muted-foreground">
                {instructions.length - low - medium} clear, {medium} worth checking and {low} uncertain.
                Rounds, rows, setup, choices and assembly steps will each be explained in the reader.
              </p>
            </div>
          </div>
        </div>
        {error && <p className="mt-4 rounded-xl bg-red-50 p-3 text-sm font-bold text-red-700">{error}</p>}
        <div className="mt-5 space-y-3">
          {instructions.map((instruction, index) => {
            const previous = instructions[index - 1];
            const startsSection = !previous || previous.section !== instruction.section;
            return (
              <div key={`${instruction.position}-${index}`}>
                {startsSection && (
                  <div className="mb-2 mt-6 flex items-center gap-2">
                    <h2 className="font-heading text-lg font-black">{instruction.section}</h2>
                    {instruction.section_quantity > 1 && (
                      <span className="rounded-full bg-secondary px-2 py-1 text-[10px] font-black">Make {instruction.section_quantity}</span>
                    )}
                  </div>
                )}
                <InstructionCard
                  instruction={instruction}
                  editing={editing === index}
                  onEdit={() => setEditing(editing === index ? null : index)}
                  onChange={(next) =>
                    setInstructions((current) =>
                      current.map((item, itemIndex) => itemIndex === index ? next : item),
                    )
                  }
                />
              </div>
            );
          })}
        </div>
        <button
          onClick={() => {
            const previous = instructions.at(-1);
            setInstructions((current) => [
              ...current,
              {
                position: current.length + 1,
                section: previous?.section ?? "New section",
                section_quantity: previous?.section_quantity ?? 1,
                section_position: (previous?.section_position ?? 0) + 1,
                instruction_kind: "step",
                source_label: null,
                instruction_number: null,
                instruction_number_end: null,
                instructions: "",
                notes: null,
                stitch_count: null,
                optional: false,
                source_group: null,
                confidence: "medium",
              },
            ]);
          }}
          className="mt-4 flex w-full items-center justify-center gap-2 rounded-2xl border-2 border-dashed border-primary/25 bg-white px-4 py-3 text-sm font-extrabold text-primary"
        >
          <Plus className="size-4" />Add a missing instruction
        </button>
      </div>
      <div className="fixed inset-x-0 bottom-0 z-40 border-t bg-background/95 p-3 backdrop-blur">
        <div className="mx-auto flex max-w-2xl gap-3">
          <button onClick={cancel} disabled={saving} className="flex-1 rounded-2xl border bg-white px-4 py-3 text-sm font-extrabold">Discard</button>
          <button onClick={save} disabled={saving || instructions.some((instruction) => !instruction.section.trim() || !instruction.instructions.trim())} className="flex-1 rounded-2xl bg-primary px-4 py-3 text-sm font-extrabold text-white disabled:opacity-50">
            {saving ? "Saving…" : "Save pattern guide"}
          </button>
        </div>
      </div>
    </div>
  );
}

function InstructionCard({
  instruction,
  editing,
  onEdit,
  onChange,
}: {
  instruction: PatternInstructionRecord;
  editing: boolean;
  onEdit: () => void;
  onChange: (instruction: PatternInstructionRecord) => void;
}) {
  return (
    <div className={cn("rounded-2xl border bg-white p-4", instruction.confidence === "low" && "border-amber-300 bg-amber-50/40")}>
      <div className="flex items-center gap-2">
        <span className="text-xs font-black uppercase tracking-wider text-primary">{instructionLabel(instruction)}</span>
        {instruction.optional && <span className="rounded-full bg-muted px-2 py-1 text-[10px] font-bold">Optional</span>}
        <Confidence value={instruction.confidence} />
        <button onClick={onEdit} className="ml-auto flex size-8 items-center justify-center rounded-xl hover:bg-muted" aria-label={`Edit ${instructionLabel(instruction)}`}>
          <Pencil className="size-3.5" />
        </button>
      </div>
      {editing ? (
        <div className="mt-3 space-y-2">
          <textarea autoFocus value={instruction.instructions} onChange={(event) => onChange({ ...instruction, instructions: event.target.value })} rows={4} className="w-full resize-y rounded-xl border bg-background p-3 text-sm outline-none focus:ring-2 focus:ring-primary/30" />
          <div className="grid grid-cols-2 gap-2">
            <input value={instruction.section} onChange={(event) => onChange({ ...instruction, section: event.target.value })} placeholder="Section" className="min-w-0 rounded-xl border px-3 py-2 text-xs outline-none" />
            <select value={instruction.instruction_kind} onChange={(event) => onChange({ ...instruction, instruction_kind: event.target.value as PatternInstructionRecord["instruction_kind"] })} className="rounded-xl border bg-white px-3 py-2 text-xs outline-none">
              {["round", "row", "step", "setup", "instruction", "choice", "repeat", "technique"].map((kind) => <option key={kind} value={kind}>{kind}</option>)}
            </select>
            <input type="number" value={instruction.instruction_number ?? ""} onChange={(event) => onChange({ ...instruction, instruction_number: event.target.value ? Number(event.target.value) : null })} placeholder="Number" className="rounded-xl border px-3 py-2 text-xs outline-none" />
            <input type="number" value={instruction.stitch_count ?? ""} onChange={(event) => onChange({ ...instruction, stitch_count: event.target.value ? Number(event.target.value) : null })} placeholder="Stitches" className="rounded-xl border px-3 py-2 text-xs outline-none" />
          </div>
          <textarea value={instruction.notes ?? ""} onChange={(event) => onChange({ ...instruction, notes: event.target.value || null })} rows={2} placeholder="Helpful note (optional)" className="w-full resize-y rounded-xl border bg-background p-3 text-xs outline-none" />
          <label className="flex items-center gap-2 text-xs font-bold"><input type="checkbox" checked={instruction.optional} onChange={(event) => onChange({ ...instruction, optional: event.target.checked })} />Optional instruction</label>
        </div>
      ) : (
        <>
          <p className="mt-3 text-sm font-semibold leading-relaxed">{instruction.instructions}</p>
          {instruction.notes && <p className="mt-3 rounded-xl bg-secondary/45 p-3 text-xs leading-relaxed"><b>Pattern note:</b> {instruction.notes}</p>}
        </>
      )}
      <div className="mt-2 text-xs text-muted-foreground">
        {instruction.stitch_count != null
          ? `${instruction.stitch_count} stitches expected`
          : instruction.confidence === "low"
            ? "Please compare this instruction with the original PDF"
            : "No stitch count printed"}
      </div>
    </div>
  );
}

function Confidence({ value }: { value: PatternInstructionRecord["confidence"] }) {
  if (value === "high") return <span className="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-1 text-[10px] font-bold text-emerald-700"><Check className="size-3" />Clear</span>;
  if (value === "medium") return <span className="rounded-full bg-amber-100 px-2 py-1 text-[10px] font-bold text-amber-800">Check</span>;
  return <span className="inline-flex items-center gap-1 rounded-full bg-amber-200 px-2 py-1 text-[10px] font-bold text-amber-900"><AlertTriangle className="size-3" />Uncertain</span>;
}
