"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { Check, ChevronLeft, ChevronRight, Eye, NotebookPen, X } from "lucide-react";
import { Progress } from "@/components/ui/progress";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import {
  instructionGuidance,
  instructionLabel,
  type PatternInstructionRecord,
} from "@/lib/pattern-instructions";
import { cn } from "@/lib/utils";
import { AccountGateButton } from "@/components/account-gate";
import { authClient } from "@/lib/auth-client";
import { demoInstructions, demoPattern, demoProject, isDemoProject } from "@/lib/demo-data";

type Project = {
  id: string;
  pattern_id: string;
  name: string;
  current_instruction: number;
  total_instructions: number;
  status: string;
};
type Note = { id: string; instruction_position: number | null; body: string };

export default function ReaderPage() {
  const params = useParams<{ id: string }>();
  const session = authClient.useSession();
  const [project, setProject] = useState<Project | null>(null);
  const [instructions, setInstructions] = useState<PatternInstructionRecord[]>([]);
  const [notes, setNotes] = useState<Note[]>([]);
  const [index, setIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [noteOpen, setNoteOpen] = useState(false);
  const [noteText, setNoteText] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const bundled = demoProject(params.id);
    if (bundled) {
      const timer = setTimeout(() => {
        setProject(bundled);
        const bundledInstructions = demoInstructions(bundled.pattern_id);
        setInstructions(bundledInstructions);
        setNotes([]);
        setIndex(Math.max(0, bundledInstructions.findIndex((instruction) => instruction.position === bundled.current_instruction)));
        setLoading(false);
      }, 0);
      return () => clearTimeout(timer);
    }
    let cancelled = false;
    fetch(`/api/projects/${params.id}`)
      .then(async (response) => {
        const payload = await response.json();
        if (!response.ok) throw new Error(payload.error || "Project not found");
        if (!cancelled) {
          setProject(payload.project);
          setInstructions(payload.instructions);
          setNotes(payload.notes);
          setIndex(Math.max(0, payload.instructions.findIndex(
            (instruction: PatternInstructionRecord) =>
              instruction.position === payload.project.current_instruction,
          )));
          setLoading(false);
        }
      })
      .catch((reason) => {
        if (!cancelled) {
          setError(reason instanceof Error ? reason.message : "Project not found");
          setLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [params.id]);

  async function move(nextIndex: number) {
    if (!project || !instructions[nextIndex]) return;
    setIndex(nextIndex);
    setSaving(true);
    try {
      const response = await fetch(`/api/projects/${project.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ currentInstruction: instructions[nextIndex].position }),
      });
      if (!response.ok) throw new Error("Progress could not sync");
      setProject((current) => current
        ? { ...current, current_instruction: instructions[nextIndex].position }
        : current);
      setError("");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Progress could not sync");
    } finally {
      setSaving(false);
    }
  }

  async function finish() {
    if (!project) return;
    setSaving(true);
    try {
      const response = await fetch(`/api/projects/${project.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ status: "completed" }),
      });
      if (!response.ok) throw new Error("Project could not be completed");
      setProject((current) => current ? { ...current, status: "completed" } : current);
      setError("");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Project could not be completed");
    } finally {
      setSaving(false);
    }
  }

  async function saveNote() {
    if (!project || !noteText.trim()) return;
    setSaving(true);
    try {
      const response = await fetch(`/api/projects/${project.id}/notes`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          instructionPosition: instructions[index].position,
          body: noteText,
        }),
      });
      const payload = await response.json();
      if (!response.ok) throw new Error(payload.error || "Note could not save");
      setNotes((current) => [payload.note, ...current]);
      setNoteText("");
      setNoteOpen(false);
      setError("");
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "Note could not save");
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <p className="py-24 text-center text-sm font-bold text-muted-foreground">Opening your saved place…</p>;
  if (!project || !instructions.length) {
    return (
      <div className="px-5 py-24 text-center">
        <h1 className="font-heading text-2xl font-black">Reader unavailable</h1>
        <p className="mt-2 text-sm text-muted-foreground">{error || "This project has no reviewed instructions."}</p>
        <Link href="/projects" className="mt-5 inline-flex text-sm font-extrabold text-primary">Back to projects</Link>
      </div>
    );
  }

  const instruction = instructions[index];
  const previous = index > 0 ? instructions[index - 1] : null;
  const next = index < instructions.length - 1 ? instructions[index + 1] : null;
  const pct = Math.round((index + 1) / instructions.length * 100);
  const instructionNotes = notes.filter(
    (note) => note.instruction_position === instruction.position,
  );
  const sectionInstructions = instructions.filter(
    (candidate) => candidate.section === instruction.section,
  );
  const sectionIndex = sectionInstructions.findIndex(
    (candidate) => candidate.position === instruction.position,
  );
  const label = instructionLabel(instruction);

  return (
    <div className="mx-auto flex min-h-[calc(100dvh-3rem)] max-w-3xl flex-col bg-background">
      <header className="flex items-center justify-between border-b border-border/70 bg-white/70 px-3 py-3 backdrop-blur">
        <Link href={`/projects/${project.id}`} className="flex size-9 items-center justify-center rounded-full" aria-label="Close reader"><X className="size-5" /></Link>
        <div className="text-center">
          <p className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">{project.name}</p>
          <p className="font-heading text-sm font-extrabold">{label} · {index + 1} of {instructions.length}</p>
        </div>
        <span className="flex size-9 items-center justify-center rounded-full bg-secondary text-[10px] font-black">{pct}%</span>
      </header>
      <div className="px-5 pt-3">
        <Progress value={pct} className="h-1" />
        <div className="mt-1.5 flex justify-between text-[10px] text-muted-foreground">
          <span>Start</span><span>{isDemoProject(project.id) ? "Demo · sign in to save" : saving ? "Syncing…" : "Synced"}</span><span>Done</span>
        </div>
      </div>
      {error && <p className="mx-5 mt-3 rounded-xl bg-red-50 p-2 text-center text-xs font-bold text-red-700">{error}</p>}
      <div className="px-5 pt-5">
        <div className="flex items-center gap-2">
          <p className="text-[10px] font-black uppercase tracking-widest text-primary">{instruction.section}</p>
          {instruction.section_quantity > 1 && <span className="rounded-full bg-secondary px-2 py-0.5 text-[10px] font-black">Make {instruction.section_quantity}</span>}
        </div>
        <p className="mt-1 text-xs text-muted-foreground">Instruction {sectionIndex + 1} of {sectionInstructions.length} in this section</p>
      </div>
      {previous && <Peek instruction={previous} prefix="Just done" />}
      <div className="flex flex-1 flex-col justify-center px-5 py-5">
        <div className="stitch-card relative overflow-hidden p-6 md:p-8">
          <div className="absolute right-0 top-0 h-full w-2 bg-[#f5a623]" />
          <div className="flex items-baseline justify-between gap-3">
            <div className="flex items-center gap-2">
              <p className="text-xs font-black uppercase tracking-widest text-primary">{label}</p>
              {instruction.optional && <span className="rounded-full bg-muted px-2 py-1 text-[10px] font-bold">Optional</span>}
            </div>
            {instruction.stitch_count != null && <span className="rounded-full bg-muted px-2 py-1 text-[10px] font-bold">{instruction.stitch_count} sts expected</span>}
          </div>
          <p className="mt-3 text-xs font-semibold leading-relaxed text-muted-foreground">{instructionGuidance(instruction)}</p>
          <p className="font-heading mt-4 text-2xl font-extrabold leading-relaxed md:text-3xl">{instruction.instructions}</p>
          {instruction.notes && <p className="mt-4 rounded-xl bg-[#ffe6a8]/65 p-3 text-xs font-semibold leading-relaxed"><b>Pattern note:</b> {instruction.notes}</p>}
          {instructionNotes.map((note) => <p key={note.id} className="mt-3 rounded-xl bg-secondary/60 p-3 text-xs font-semibold">Your note: {note.body}</p>)}
          <div className="mt-5 flex flex-wrap gap-2">
            {session.data?.user ? <button onClick={() => setNoteOpen(true)} className="flex items-center gap-2 rounded-full border bg-background px-3 py-2 text-xs font-bold"><NotebookPen className="size-3.5" />Add note</button> : <AccountGateButton title="Create an account to add notes" message="Notes are private and stay attached to your saved project step." next={`/projects/${project.id}/reader`} className="flex items-center gap-2 rounded-full border bg-background px-3 py-2 text-xs font-bold"><NotebookPen className="size-3.5" />Add note</AccountGateButton>}
            {isDemoProject(project.id) ? <a href={demoPattern(project.pattern_id)?.pdf_url} target="_blank" rel="noreferrer" className="flex items-center gap-2 rounded-full border bg-background px-3 py-2 text-xs font-bold"><Eye className="size-3.5" />View original</a> : <a href={`/api/patterns/${project.pattern_id}/original`} target="_blank" rel="noreferrer" className="flex items-center gap-2 rounded-full border bg-background px-3 py-2 text-xs font-bold"><Eye className="size-3.5" />View original</a>}
          </div>
        </div>
      </div>
      {next && <Peek instruction={next} prefix="Coming up" />}
      <div className="sticky bottom-0 border-t bg-background/95 px-3 py-3 backdrop-blur">
        <div className="flex gap-2">
          {session.data?.user ? <button onClick={() => move(index - 1)} disabled={!previous || saving} className={cn("flex w-14 items-center justify-center rounded-xl border bg-card", (!previous || saving) && "opacity-40")} aria-label="Previous instruction"><ChevronLeft className="size-5" /></button> : <AccountGateButton title="Create an account to save your place" message="Sign in to keep this step synced and resume it on any device." next={`/projects/${project.id}/reader`} className={cn("flex w-14 items-center justify-center rounded-xl border bg-card", !previous && "pointer-events-none opacity-40")}><ChevronLeft className="size-5" /><span className="sr-only">Previous instruction</span></AccountGateButton>}
          {session.data?.user ? (
            <Button onClick={() => next ? move(index + 1) : finish()} disabled={saving} size="lg" className="flex-1">
              <Check className="mr-2 size-4" strokeWidth={3} />{next ? instruction.optional ? "Skip or complete — continue" : instruction.instruction_kind === "choice" ? "Chosen — continue" : `Done — next ${next.instruction_kind}` : "Finish project"}{next && <ChevronRight className="ml-1 size-4" />}
            </Button>
          ) : (
            <AccountGateButton title={next ? "Create an account to save your place" : "Create an account to complete projects"} message={next ? "Sign in to keep this step synced and resume it on any device." : "Sign in to save completion, progress, and notes to your maker space."} next={`/projects/${project.id}/reader`} className="flex min-h-10 flex-1 items-center justify-center rounded-lg bg-primary px-4 font-heading font-bold text-white">
              <Check className="mr-2 size-4" strokeWidth={3} />{next ? "Done — save my place" : "Finish project"}{next && <ChevronRight className="ml-1 size-4" />}
            </AccountGateButton>
          )}
        </div>
        <p className="mt-2 text-center text-[10px] text-muted-foreground">{isDemoProject(project.id) ? "Explore freely · create an account when you want to save" : "Progress saves securely to your account"}</p>
      </div>
      <Sheet open={noteOpen} onOpenChange={setNoteOpen}>
        <SheetContent side="bottom" className="rounded-t-3xl">
          <SheetHeader>
            <SheetTitle>Note on {label}</SheetTitle>
            <SheetDescription>Record a modification, tool change or anything you want to remember.</SheetDescription>
          </SheetHeader>
          <div className="px-4">
            <textarea value={noteText} onChange={(event) => setNoteText(event.target.value)} rows={4} className="w-full resize-none rounded-xl border bg-background p-3 text-sm outline-none focus:ring-2 focus:ring-primary/30" placeholder={`What changed on ${label.toLowerCase()}?`} />
          </div>
          <SheetFooter><Button onClick={saveNote} disabled={saving || !noteText.trim()}>{saving ? "Saving…" : "Save note"}</Button></SheetFooter>
        </SheetContent>
      </Sheet>
    </div>
  );
}

function Peek({ instruction, prefix }: { instruction: PatternInstructionRecord; prefix: string }) {
  return (
    <div className="mx-5 mt-3 rounded-xl border border-dashed bg-card/50 p-3">
      <p className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">{prefix} — {instructionLabel(instruction)}</p>
      <p className="mt-1 line-clamp-1 text-xs text-muted-foreground">{instruction.instructions}</p>
    </div>
  );
}
