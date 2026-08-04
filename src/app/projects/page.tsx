"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ArrowRight, CheckCircle2, Plus } from "lucide-react";
import { ScreenHeader } from "@/components/screen-header";
import { PatternArt, CraftArt } from "@/components/craft-art";
import { PatternCover } from "@/components/pattern-cover";
import { Progress } from "@/components/ui/progress";
import { authClient } from "@/lib/auth-client";
import { demoProjects } from "@/lib/demo-data";
type Project = {
  id: string;
  name: string;
  status: "planned" | "active" | "completed";
  current_instruction: number;
  pattern_name: string;
  total_instructions: number;
  craft: "knit" | "crochet";
  yarn: string | null;
  completed_at: string | null;
  cover_url: string | null;
};
export default function ProjectsPage() {
  const session = authClient.useSession();
  const [projects, setProjects] = useState<Project[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  useEffect(() => {
    if (session.isPending) return;
    if (!session.data?.user) {
      const timer = setTimeout(() => {
        setProjects(demoProjects);
        setLoading(false);
      }, 0);
      return () => clearTimeout(timer);
    }
    let cancelled = false;
    fetch("/api/projects")
      .then(async (response) => {
        const payload = await response.json();
        if (!response.ok)
          throw new Error(payload.error || "Could not load projects");
        if (!cancelled) {
          setProjects(payload.projects);
          setLoading(false);
        }
      })
      .catch((reason) => {
        if (!cancelled) {
          setError(
            reason instanceof Error
              ? reason.message
              : "Could not load projects",
          );
          setLoading(false);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [session.data?.user, session.isPending]);
  const active = projects.filter((project) => project.status !== "completed");
  const completed = projects.filter(
    (project) => project.status === "completed",
  );
  return (
    <div className="pb-10">
      <ScreenHeader
        title="Your projects"
        right={
          <Link
            href="/library"
            className="flex size-10 items-center justify-center rounded-2xl bg-primary text-white"
          >
            <Plus className="size-5" />
          </Link>
        }
      />
      <div className="px-5 pt-7 md:px-8">
        {loading ? (
          <p className="py-20 text-center text-sm font-bold text-muted-foreground">
            Loading projects…
          </p>
        ) : error ? (
          <p className="rounded-2xl bg-red-50 p-4 text-sm font-bold text-red-700">
            {error}
          </p>
        ) : projects.length === 0 ? (
          <EmptyProjects />
        ) : (
          <>
            <div className="relative overflow-hidden rounded-3xl bg-[#f58ba2] p-6 pr-40">
              <div className="stitch-pattern absolute inset-0 opacity-20" />
              <PatternArt
                index={3}
                className="absolute -bottom-12 -right-5 size-48"
              />
              <p className="relative text-xs font-extrabold uppercase tracking-[.15em] text-[#17324d]/60">
                Making now
              </p>
              <h1 className="font-heading relative mt-1 text-3xl font-black">
                {active.length} {active.length === 1 ? "work" : "works"}
                <br />
                in progress
              </h1>
            </div>
            <div className="mt-7 grid gap-4 md:grid-cols-2">
              {active.map((project, index) => {
                const pct = Math.min(
                  100,
                  Math.round(
                    (project.current_instruction / project.total_instructions) *
                      100,
                  ),
                );
                return (
                  <Link
                    key={project.id}
                    href={`/projects/${project.id}`}
                    className="stitch-card group overflow-hidden"
                  >
                    <div
                      className={`relative h-36 overflow-hidden ${index % 2 ? "bg-[#ffe6a8]" : "bg-[#dff4fb]"}`}
                    >
                    <PatternCover
                      coverUrl={project.cover_url}
                      craft={project.craft}
                      kind="project"
                      alt={`${project.pattern_name} cover`}
                    />
                      <span className="absolute left-4 top-4 rounded-full bg-white/90 px-3 py-1 text-xs font-extrabold">
                        {project.craft}
                      </span>
                    </div>
                    <div className="p-4">
                      <div className="flex items-start justify-between gap-3">
                        <div>
                          <h2 className="font-heading text-lg font-extrabold">
                            {project.name}
                          </h2>
                          <p className="text-xs text-muted-foreground">
                            {project.pattern_name}
                          </p>
                        </div>
                        <ArrowRight className="mt-1 size-4 text-primary" />
                      </div>
                      <div className="mt-4 flex items-center gap-3">
                        <Progress value={pct} className="h-2" />
                        <span className="text-xs font-extrabold">{pct}%</span>
                      </div>
                      <p className="mt-2 text-xs text-muted-foreground">
                        Ready at step {project.current_instruction}
                      </p>
                    </div>
                  </Link>
                );
              })}
            </div>
            {completed.length > 0 && (
              <>
                <h2 className="font-heading mt-9 text-xl font-extrabold">
                  Finished &amp; proud
                </h2>
                <div className="mt-3 space-y-3">
                  {completed.map((project) => (
                    <Link
                      key={project.id}
                      href={`/projects/${project.id}`}
                      className="stitch-card flex items-center gap-4 p-4"
                    >
                      <span className="flex size-11 items-center justify-center rounded-2xl bg-[#dcedc8] text-[#2e6b46]">
                        <CheckCircle2 className="size-5" />
                      </span>
                      <div className="flex-1">
                        <p className="font-heading text-sm font-extrabold">
                          {project.name}
                        </p>
                        <p className="text-xs text-muted-foreground">
                          {project.pattern_name}
                        </p>
                      </div>
                      <ArrowRight className="size-4 text-muted-foreground" />
                    </Link>
                  ))}
                </div>
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
}
function EmptyProjects() {
  return (
    <div className="py-8 text-center">
      <div className="relative mx-auto flex size-64 items-center justify-center rounded-full bg-[#ffe6a8]">
        <CraftArt art="yarn" className="size-48" />
      </div>
      <h1 className="font-heading mt-5 text-3xl font-black">
        No projects on the go
      </h1>
      <p className="mx-auto mt-2 max-w-sm text-sm leading-relaxed text-muted-foreground">
        Choose one of your real uploaded patterns to begin.
      </p>
      <Link
        href="/library"
        className="mt-6 inline-flex items-center gap-2 rounded-2xl bg-primary px-5 py-3.5 font-heading text-sm font-extrabold text-white"
      >
        <Plus className="size-4" />
        Choose a pattern
      </Link>
    </div>
  );
}
