"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import { useParams } from "next/navigation";
import { Camera, Check, ChevronLeft, ChevronRight, Eye, Lock, NotebookPen, Sparkles, Trash2, X } from "lucide-react";
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
import { loadProgress, saveProgress } from "@/lib/persistence";
import { GlossaryInstructionText, GlossarySheet } from "@/components/pattern-glossary";
import type { PatternGlossaryTerm } from "@/lib/pattern-glossary";
import { deleteStepPhoto, loadStepPhotos, saveStepPhoto, type ProjectPhoto } from "@/lib/project-photo-journal";

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
  const [selectedGlossaryTerm, setSelectedGlossaryTerm] = useState<PatternGlossaryTerm | null>(null);
  const [stepPhotos, setStepPhotos] = useState<ProjectPhoto[]>([]);
  const [selectedPhoto, setSelectedPhoto] = useState<ProjectPhoto | null>(null);
  const [savingPhoto, setSavingPhoto] = useState(false);
  const photoInput = useRef<HTMLInputElement>(null);

  useEffect(() => {
    const bundled = demoProject(params.id);
    if (bundled) {
      const timer = setTimeout(() => {
        setProject(bundled);
        const bundledInstructions = demoInstructions(bundled.pattern_id);
        const saved = loadProgress(bundled.id, bundled.current_instruction);
        setInstructions(bundledInstructions);
        setNotes([]);
        setIndex(Math.max(0, bundledInstructions.findIndex((instruction) => instruction.position === saved.row)));
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

  useEffect(() => {
    const position = instructions[index]?.position;
    if (!project || position == null) return;
    let cancelled = false;
    loadStepPhotos(project.id, position).then((photos) => { if (!cancelled) setStepPhotos(photos); }).catch(() => { if (!cancelled) setError("Private step photos could not load"); });
    return () => { cancelled = true; };
  }, [project, instructions, index]);

  async function capturePhoto(file: File | undefined) {
    if (!file || !project || !instructions[index] || savingPhoto) return;
    setSavingPhoto(true);
    try {
      const saved = await saveStepPhoto({ projectId: project.id, instructionPosition: instructions[index].position, section: instructions[index].section, image: file });
      setStepPhotos((current) => [saved, ...current]);
      setError("");
    } catch { setError("This photo could not be saved on your device"); }
    finally { setSavingPhoto(false); if (photoInput.current) photoInput.current.value = ""; }
  }

  async function removePhoto(photo: ProjectPhoto) {
    if (savingPhoto) return;
    setSavingPhoto(true);
    try { await deleteStepPhoto(photo.id); setStepPhotos((current) => current.filter((candidate) => candidate.id !== photo.id)); setSelectedPhoto(null); }
    catch { setError("This photo could not be deleted"); }
    finally { setSavingPhoto(false); }
  }

  async function move(nextIndex: number) {
    if (!project || !instructions[nextIndex]) return;
    setIndex(nextIndex);
    if (isDemoProject(project.id)) {
      const nextPosition = instructions[nextIndex].position;
      saveProgress(project.id, { row: nextPosition, notes: {} });
      setProject((current) => current ? { ...current, current_instruction: nextPosition } : current);
      setError("");
      return;
    }
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
      {isDemoProject(project.id) && (
        <div className="mx-3 mt-3 flex items-center gap-3 rounded-2xl border border-[#c23357]/40 bg-[#c23357]/10 px-4 py-3 text-[#082e59]">
          <Sparkles className="size-5 shrink-0 text-[#c23357]" />
          <div>
            <p className="font-heading text-xs font-black tracking-wide">DEMO PROJECT</p>
            <p className="text-[11px] font-semibold">Try every step · saved only on this device</p>
          </div>
        </div>
      )}
      <div className="px-5 pt-3">
        <Progress value={pct} className="h-1" />
        <div className="mt-1.5 flex justify-between text-[10px] text-muted-foreground">
          <span>Start</span><span>{isDemoProject(project.id) ? "Saved on this device" : saving ? "Syncing…" : "Synced"}</span><span>Done</span>
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
          <GlossaryInstructionText text={instruction.instructions} onSelect={setSelectedGlossaryTerm} className="font-heading mt-4 text-2xl font-extrabold leading-relaxed md:text-3xl" />
          {instruction.notes && <p className="mt-4 rounded-xl bg-[#ffe6a8]/65 p-3 text-xs font-semibold leading-relaxed"><b>Pattern note:</b> {instruction.notes}</p>}
          {instructionNotes.map((note) => <p key={note.id} className="mt-3 rounded-xl bg-secondary/60 p-3 text-xs font-semibold">Your note: {note.body}</p>)}
          <div className="mt-5 rounded-2xl bg-secondary/35 p-4">
            <div className="flex items-start justify-between gap-3">
              <div><p className="font-heading text-sm font-extrabold">What this step looked like</p><p className="mt-1 flex items-center gap-1 text-[11px] text-muted-foreground"><Lock className="size-3" /> Private · only on this device</p></div>
              <button type="button" disabled={savingPhoto} onClick={() => photoInput.current?.click()} className="flex shrink-0 items-center gap-2 rounded-full bg-primary px-3 py-2 text-xs font-extrabold text-white disabled:opacity-50"><Camera className="size-4" />{savingPhoto ? "Saving photo…" : "Take photo"}</button>
              <input ref={photoInput} type="file" accept="image/*" capture="environment" className="hidden" onChange={(event) => capturePhoto(event.target.files?.[0])} />
            </div>
            {stepPhotos.length > 0 ? <div className="mt-3 flex gap-2 overflow-x-auto">{stepPhotos.map((photo) => <button key={photo.id} type="button" onClick={() => setSelectedPhoto(photo)} className="size-20 shrink-0 overflow-hidden rounded-xl border bg-white"><PhotoImage photo={photo} /></button>)}</div> : <p className="mt-3 text-xs leading-relaxed text-muted-foreground">Add a photo after this step so you can compare your work when you return.</p>}
          </div>
          <div className="mt-5 flex flex-wrap gap-2">
            {session.data?.user ? <button onClick={() => setNoteOpen(true)} className="flex items-center gap-2 rounded-full border bg-background px-3 py-2 text-xs font-bold"><NotebookPen className="size-3.5" />Add note</button> : <AccountGateButton title="Create an account to add notes" message="Notes are private and stay attached to your saved project step." next={`/projects/${project.id}/reader`} className="flex items-center gap-2 rounded-full border bg-background px-3 py-2 text-xs font-bold"><NotebookPen className="size-3.5" />Add note</AccountGateButton>}
            {isDemoProject(project.id) ? <a href={demoPattern(project.pattern_id)?.pdf_url} target="_blank" rel="noreferrer" className="flex items-center gap-2 rounded-full border bg-background px-3 py-2 text-xs font-bold"><Eye className="size-3.5" />View original</a> : <a href={`/api/patterns/${project.pattern_id}/original`} target="_blank" rel="noreferrer" className="flex items-center gap-2 rounded-full border bg-background px-3 py-2 text-xs font-bold"><Eye className="size-3.5" />View original</a>}
          </div>
        </div>
      </div>
      {next && <Peek instruction={next} prefix="Coming up" />}
      <div className="sticky bottom-0 border-t bg-background/95 px-3 py-3 backdrop-blur">
        <div className="flex gap-2">
          <button onClick={() => move(index - 1)} disabled={!previous || saving} className={cn("flex w-14 items-center justify-center rounded-xl border bg-card", (!previous || saving) && "opacity-40")} aria-label="Previous instruction"><ChevronLeft className="size-5" /></button>
          {next || session.data?.user ? (
            <Button onClick={() => next ? move(index + 1) : finish()} disabled={saving} size="lg" className="flex-1">
              <Check className="mr-2 size-4" strokeWidth={3} />{next ? instruction.optional ? "Skip or complete — continue" : instruction.instruction_kind === "choice" ? "Chosen — continue" : `Done — next ${next.instruction_kind}` : "Finish project"}{next && <ChevronRight className="ml-1 size-4" />}
            </Button>
          ) : (
            <AccountGateButton title={next ? "Create an account to save your place" : "Create an account to complete projects"} message={next ? "Sign in to keep this step synced and resume it on any device." : "Sign in to save completion, progress, and notes to your maker space."} next={`/projects/${project.id}/reader`} className="flex min-h-10 flex-1 items-center justify-center rounded-lg bg-primary px-4 font-heading font-bold text-white">
              <Check className="mr-2 size-4" strokeWidth={3} />{next ? "Done — save my place" : "Finish project"}{next && <ChevronRight className="ml-1 size-4" />}
            </AccountGateButton>
          )}
        </div>
        <p className="mt-2 text-center text-[10px] text-muted-foreground">{isDemoProject(project.id) ? "Progress stays on this device · sign in when you want cloud sync" : "Progress saves securely to your account"}</p>
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
      <GlossarySheet term={selectedGlossaryTerm} onOpenChange={(open) => { if (!open) setSelectedGlossaryTerm(null); }} />
      <Sheet open={selectedPhoto != null} onOpenChange={(open) => { if (!open) setSelectedPhoto(null); }}>
        <SheetContent side="bottom" className="rounded-t-3xl">
          {selectedPhoto && <><SheetHeader><SheetTitle>Private step photo</SheetTitle><SheetDescription>{selectedPhoto.section} · step {selectedPhoto.instructionPosition} · {new Date(selectedPhoto.capturedAt).toLocaleString("en-GB")}</SheetDescription></SheetHeader><div className="px-4"><div className="mx-auto max-h-[55dvh] overflow-hidden rounded-2xl bg-muted"><PhotoImage photo={selectedPhoto} className="max-h-[55dvh] w-full object-contain" /></div><button type="button" disabled={savingPhoto} onClick={() => removePhoto(selectedPhoto)} className="mt-4 flex w-full items-center justify-center gap-2 rounded-xl border border-red-200 px-4 py-3 text-sm font-extrabold text-red-700"><Trash2 className="size-4" />{savingPhoto ? "Deleting photo…" : "Delete photo"}</button></div></>}
        </SheetContent>
      </Sheet>
    </div>
  );
}

function PhotoImage({ photo, className = "size-full object-cover" }: { photo: ProjectPhoto; className?: string }) {
  const url = useMemo(() => URL.createObjectURL(photo.image), [photo.image]);
  useEffect(() => () => URL.revokeObjectURL(url), [url]);
  // Private IndexedDB object URLs cannot be optimized by the Next image pipeline.
  // eslint-disable-next-line @next/next/no-img-element
  return <img src={url} alt={`Private project photo from ${photo.section}, step ${photo.instructionPosition}`} className={className} />;
}

function Peek({ instruction, prefix }: { instruction: PatternInstructionRecord; prefix: string }) {
  return (
    <div className="mx-5 mt-3 rounded-xl border border-dashed bg-card/50 p-3">
      <p className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">{prefix} — {instructionLabel(instruction)}</p>
      <p className="mt-1 line-clamp-1 text-xs text-muted-foreground">{instruction.instructions}</p>
    </div>
  );
}
