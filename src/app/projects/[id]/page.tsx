"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { ArrowRight, Check, Circle, FileText, ListChecks, NotebookPen, Play, Sparkles } from "lucide-react";
import { ScreenHeader } from "@/components/screen-header";
import { PatternCover } from "@/components/pattern-cover";
import { Progress } from "@/components/ui/progress";
import { demoInstructions, demoPattern, demoProject, isDemoProject } from "@/lib/demo-data";
import { deriveProjectMaterials } from "@/lib/project-materials";
import { loadMaterialChecks, saveMaterialChecks } from "@/lib/persistence";
type Project = {
  id: string;
  pattern_id: string;
  name: string;
  status: string;
  yarn: string | null;
  current_instruction: number;
  started_at: string;
  last_worked_at: string;
  pattern_name: string;
  total_instructions: number;
  craft: "knit" | "crochet";
  cover_url: string | null;
};
type Note = {
  id: string;
  instruction_position: number | null;
  body: string;
  created_at: string;
};
export default function ProjectDetailPage() {
  const params = useParams<{ id: string }>();
  const [project, setProject] = useState<Project | null>(null);
  const [notes, setNotes] = useState<Note[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [instructionText, setInstructionText] = useState<string[]>([]);
  const [patternTool, setPatternTool] = useState<string | null>(null);
  const [checkedMaterials, setCheckedMaterials] = useState<Set<string>>(new Set());
  useEffect(() => {
    const bundled = demoProject(params.id);
    if (bundled) {
      const timer = setTimeout(() => {
        setProject(bundled);
        setInstructionText(demoInstructions(bundled.pattern_id).map((instruction) => instruction.instructions));
        setPatternTool(demoPattern(bundled.pattern_id)?.tool ?? null);
        setCheckedMaterials(new Set(loadMaterialChecks(bundled.id)));
        setNotes([]);
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
          setNotes(payload.notes);
          setInstructionText((payload.instructions ?? []).map((instruction: { instructions: string }) => instruction.instructions));
          setCheckedMaterials(new Set(loadMaterialChecks(payload.project.id)));
          setLoading(false);
        }
      })
      .catch((reason) => {
        if (!cancelled) {
          setError(
            reason instanceof Error ? reason.message : "Project not found",
          );
          setLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [params.id]);
  if (loading)
    return (
      <p className="py-24 text-center text-sm font-bold text-muted-foreground">
        Loading project…
      </p>
    );
  if (!project)
    return (
      <div className="px-5 py-24 text-center">
        <h1 className="font-heading text-2xl font-black">
          Project unavailable
        </h1>
        <p className="mt-2 text-sm text-muted-foreground">{error}</p>
        <Link
          href="/projects"
          className="mt-5 inline-flex text-sm font-extrabold text-primary"
        >
          Back to projects
        </Link>
      </div>
    );
  const pct = Math.min(
    100,
    Math.round(
      (project.current_instruction / project.total_instructions) * 100,
    ),
  );
  const isExploreProject = isDemoProject(project.id) && project.status !== "completed";
  const materials = deriveProjectMaterials({ yarn: project.yarn, tool: patternTool, instructions: instructionText });
  function toggleMaterial(id: string) {
    setCheckedMaterials((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id); else next.add(id);
      saveMaterialChecks(project!.id, [...next]);
      return next;
    });
  }
  return (
    <div className="pb-10">
      <ScreenHeader back="/projects" title={project.name} />
      <div className="mx-auto max-w-3xl px-5 pt-5 md:px-8">
        <div className="relative flex aspect-[16/8] items-center justify-center overflow-hidden rounded-3xl bg-[#ffe6a8]">
          <div className="stitch-pattern absolute inset-0 opacity-30" />
          <PatternCover
            coverUrl={project.cover_url}
            craft={project.craft}
            kind="project"
            alt={`${project.pattern_name} cover`}
          />
        </div>
        <div className="mt-5 flex flex-wrap items-center gap-4">
          <Link href={`/library/${project.pattern_id}`} className="inline-flex items-center gap-1 text-xs font-extrabold text-primary">
            {project.pattern_name}<ArrowRight className="size-3" />
          </Link>
          {isDemoProject(project.id) ? <a href={demoPattern(project.pattern_id)?.pdf_url} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-xs font-extrabold text-primary">View original PDF<ArrowRight className="size-3" /></a> : <a href={`/api/patterns/${project.pattern_id}/original`} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 text-xs font-extrabold text-primary">View original PDF<ArrowRight className="size-3" /></a>}
        </div>
        {isDemoProject(project.id) && (
          <div className="mt-4 flex gap-3 rounded-2xl border border-[#c23357]/40 bg-[#c23357]/10 p-4 text-[#082e59]">
            <Sparkles className="mt-0.5 size-5 shrink-0 text-[#c23357]" />
            <div>
              <p className="font-heading text-sm font-black">You’re exploring a demo project</p>
              <p className="mt-1 text-xs font-semibold leading-relaxed">{isExploreProject ? "First see how an outside PDF became a clear, trackable project. Then try the reader; your place is saved only on this device." : "Review a finished example and its standardized instructions."}</p>
            </div>
          </div>
        )}
        <h1 className="font-heading mt-1 text-3xl font-black">
          {project.name}
        </h1>
        {isExploreProject && <ExploreTransformation project={project} />}
        <section className="mt-5 rounded-3xl border bg-white p-5" data-testid="project-materials">
          <p className="text-xs font-extrabold uppercase tracking-[.15em] text-primary">Before you make</p>
          <div className="mt-1 flex items-end justify-between gap-3">
            <h2 className="font-heading text-2xl font-black">Materials checklist</h2>
            {materials.length > 0 && <span className="text-xs font-bold text-muted-foreground">{checkedMaterials.size} of {materials.length} ready</span>}
          </div>
          <p className="mt-2 text-sm leading-relaxed text-muted-foreground">Check your setup when you start or return to this project. Your choices stay on this device.</p>
          {materials.length > 0 ? (
            <div className="mt-4 space-y-2">
              {materials.map((material) => {
                const checked = checkedMaterials.has(material.id);
                return <button key={material.id} type="button" onClick={() => toggleMaterial(material.id)} aria-pressed={checked} className="flex w-full items-start gap-3 rounded-2xl border p-4 text-left">
                  <span className={`mt-0.5 flex size-6 shrink-0 items-center justify-center rounded-full ${checked ? "bg-primary text-white" : "text-muted-foreground"}`}>{checked ? <Check className="size-4" strokeWidth={3} /> : <Circle className="size-6" />}</span>
                  <span><span className={checked ? "font-extrabold line-through opacity-60" : "font-extrabold"}>{material.name}</span>{material.detail && <span className="mt-1 block text-xs text-muted-foreground">{material.detail}</span>}</span>
                </button>;
              })}
            </div>
          ) : <p className="mt-4 rounded-2xl border border-dashed p-4 text-sm text-muted-foreground">No structured materials were found. Check the original PDF before starting; Stitchly won’t guess missing supplies.</p>}
        </section>
        <div className="stitch-card mt-5 p-5">
          <div className="flex items-baseline justify-between">
            <p className="text-xs font-bold uppercase tracking-wider text-muted-foreground">
              Progress
            </p>
            <p className="font-heading font-black">{pct}%</p>
          </div>
          <Progress value={pct} className="mt-3 h-2" />
          <div className="mt-2 flex justify-between text-xs text-muted-foreground">
            <span>
              Step {project.current_instruction} of {project.total_instructions}
            </span>
            <span>
              {isDemoProject(project.id) ? "Saved on this device" : <>Synced {new Date(project.last_worked_at).toLocaleDateString("en-GB", { day: "numeric", month: "short" })}</>}
            </span>
          </div>
          <Link
            href={`/projects/${project.id}/reader`}
            className="mt-5 flex w-full items-center justify-center rounded-2xl bg-primary px-5 py-4 font-heading text-sm font-extrabold text-white"
          >
            <Play className="mr-2 size-4" />
            {isExploreProject ? `Open the clear reader at step ${project.current_instruction}` : isDemoProject(project.id) ? "Review standardized instructions" : `Continue from step ${project.current_instruction}`}
          </Link>
        </div>
        <section className="mt-7">
          <div className="flex items-center justify-between">
            <h2 className="font-heading text-xl font-black">Notes</h2>
            <Link
              href={`/projects/${project.id}/reader`}
              className="flex items-center gap-1 text-xs font-extrabold text-primary"
            >
              <NotebookPen className="size-3.5" />
              Add in reader
            </Link>
          </div>
          {notes.length ? (
            <div className="mt-3 space-y-3">
              {notes.map((note) => (
                <div key={note.id} className="stitch-card p-4">
                  <p className="text-sm font-semibold leading-relaxed">
                    {note.body}
                  </p>
                  <p className="mt-2 text-xs text-muted-foreground">
                    {note.instruction_position
                      ? `Step ${note.instruction_position} · `
                      : ""}
                    {new Date(note.created_at).toLocaleDateString("en-GB", {
                      day: "numeric",
                      month: "short",
                    })}
                  </p>
                </div>
              ))}
            </div>
          ) : (
            <p className="mt-3 rounded-2xl border border-dashed bg-white p-5 text-sm text-muted-foreground">
              {isDemoProject(project.id) ? "Demo notes are read-only. Add a note in the reader to create an account." : "No notes yet. Add one against any instruction while making."}
            </p>
          )}
        </section>
        <section className="mt-7 grid grid-cols-2 gap-3">
          <Stat label="Yarn" value={project.yarn || "Not recorded"} />
          <Stat
            label="Started"
            value={new Date(project.started_at).toLocaleDateString("en-GB", {
              day: "numeric",
              month: "short",
              year: "numeric",
            })}
          />
        </section>
      </div>
    </div>
  );
}

function ExploreTransformation({ project }: { project: Project }) {
  const pdfUrl = demoPattern(project.pattern_id)?.pdf_url;
  return (
    <section
      data-testid="explore-project-transformation"
      className="mt-5 overflow-hidden rounded-3xl border border-[#59c3eb]/50 bg-[#dff4fb]/55 p-5"
    >
      <p className="text-xs font-extrabold uppercase tracking-[.15em] text-[#17324d]/60">
        From PDF to a project
      </p>
      <h2 className="font-heading mt-1 text-2xl font-black">
        This didn’t start as a step-by-step project
      </h2>
      <p className="mt-2 text-sm font-semibold leading-relaxed text-[#17324d]/75">
        It started as a pattern PDF from another website. Stitchly kept the original terminology, then organized it into a consistent format that remembers your place.
      </p>
      <div className="mt-5 grid gap-3 md:grid-cols-3">
        <a
          href={pdfUrl}
          target="_blank"
          rel="noreferrer"
          className="rounded-2xl bg-white p-4 shadow-sm transition-transform hover:-translate-y-0.5"
        >
          <TransformationNumber number={1} />
          <FileText className="mt-4 size-5 text-primary" aria-hidden="true" />
          <h3 className="font-heading mt-2 font-extrabold">The original PDF</h3>
          <p className="mt-1 text-xs leading-relaxed text-muted-foreground">Made for reading and printing, so finding your place means scanning pages again.</p>
          <span className="mt-3 inline-flex items-center gap-1 text-xs font-extrabold text-primary">Open PDF <ArrowRight className="size-3" /></span>
        </a>
        <Link
          href={`/library/${project.pattern_id}`}
          className="rounded-2xl bg-white p-4 shadow-sm transition-transform hover:-translate-y-0.5"
        >
          <TransformationNumber number={2} />
          <ListChecks className="mt-4 size-5 text-primary" aria-hidden="true" />
          <h3 className="font-heading mt-2 font-extrabold">A standardized pattern</h3>
          <p className="mt-1 text-xs leading-relaxed text-muted-foreground">Rows, rounds, setup, finishing, and source-order sections are laid out consistently.</p>
          <span className="mt-3 inline-flex items-center gap-1 text-xs font-extrabold text-primary">See the pattern <ArrowRight className="size-3" /></span>
        </Link>
        <div className="rounded-2xl bg-[#17324d] p-4 text-white shadow-sm">
          <TransformationNumber number={3} inverse />
          <Play className="mt-4 size-5 text-[#f58ba2]" aria-hidden="true" />
          <h3 className="font-heading mt-2 font-extrabold">A live project</h3>
          <p className="mt-1 text-xs leading-relaxed text-white/75">Your current step and progress are ready whenever you come back.</p>
          <span className="mt-3 block text-xs font-extrabold text-[#f58ba2]">The reader is the result ↓</span>
        </div>
      </div>
    </section>
  );
}

function TransformationNumber({ number, inverse = false }: { number: number; inverse?: boolean }) {
  return (
    <span className={`flex size-7 items-center justify-center rounded-full text-xs font-black ${inverse ? "bg-[#f58ba2] text-[#17324d]" : "bg-[#17324d] text-white"}`}>
      {number}
    </span>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="stitch-card p-4">
      <p className="text-[10px] font-bold uppercase tracking-wider text-muted-foreground">
        {label}
      </p>
      <p className="font-heading mt-1 text-sm font-extrabold">{value}</p>
    </div>
  );
}
