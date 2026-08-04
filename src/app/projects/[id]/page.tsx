"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { ArrowRight, NotebookPen, Play, Sparkles } from "lucide-react";
import { ScreenHeader } from "@/components/screen-header";
import { PatternCover } from "@/components/pattern-cover";
import { Progress } from "@/components/ui/progress";
import { demoPattern, demoProject, isDemoProject } from "@/lib/demo-data";
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
  useEffect(() => {
    const bundled = demoProject(params.id);
    if (bundled) {
      const timer = setTimeout(() => {
        setProject(bundled);
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
              <p className="mt-1 text-xs font-semibold leading-relaxed">Tap through every step to experience the reader. Your place is saved only on this device.</p>
            </div>
          </div>
        )}
        <h1 className="font-heading mt-1 text-3xl font-black">
          {project.name}
        </h1>
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
            {isDemoProject(project.id) ? `Enter demo at step ${project.current_instruction}` : `Continue from step ${project.current_instruction}`}
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
