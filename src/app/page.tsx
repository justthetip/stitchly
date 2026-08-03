"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { ArrowRight, BookOpen, FileUp, Play, Sparkles } from "lucide-react";
import { CraftArt } from "@/components/craft-art";
import { PatternCover } from "@/components/pattern-cover";
import { Progress } from "@/components/ui/progress";
import { authClient } from "@/lib/auth-client";
type Project = {
  id: string;
  name: string;
  status: string;
  current_instruction: number;
  pattern_name: string;
  total_instructions: number;
  craft: "knit" | "crochet";
  cover_url: string | null;
};
export default function HomePage() {
  const session = authClient.useSession();
  const [projects, setProjects] = useState<Project[]>([]);
  const [loaded, setLoaded] = useState(false);
  useEffect(() => {
    if (session.isPending) return;
    if (!session.data?.user) {
      const timer = setTimeout(() => setLoaded(true), 0);
      return () => clearTimeout(timer);
    }
    let cancelled = false;
    fetch("/api/projects")
      .then((response) => (response.ok ? response.json() : { projects: [] }))
      .then((payload) => {
        if (!cancelled) {
          setProjects(payload.projects ?? []);
          setLoaded(true);
        }
      });
    return () => {
      cancelled = true;
    };
  }, [session.data?.user, session.isPending]);
  const active = projects.filter((project) => project.status !== "completed");
  const current = active[0];
  return (
    <div className="pb-10">
      <header className="relative overflow-hidden bg-[#f5a623] px-5 pb-9 pt-8 md:px-10">
        <div className="stitch-pattern absolute inset-0 opacity-35" />
        <div className="relative flex items-start justify-between">
          <div>
            <p className="text-xs font-bold uppercase tracking-[.18em] text-[#17324d]/65">
              {session.data?.user
                ? `Welcome, ${session.data.user.name?.split(" ")[0] || "maker"}`
                : "Your craft corner"}
            </p>
            <h1 className="font-heading mt-1 text-3xl font-black">
              What shall we make?
            </h1>
          </div>
          <Link
            href="/account"
            className="flex size-11 items-center justify-center rounded-2xl bg-white font-heading text-sm font-black text-primary shadow-sm"
          >
            {session.data?.user?.name?.[0] || "You"}
          </Link>
        </div>
      </header>
      <div className="px-5 pt-7 md:px-10">
        {!loaded ? (
          <p className="py-20 text-center text-sm font-bold text-muted-foreground">
            Finding your latest instruction…
          </p>
        ) : current ? (
          <ContinueProject project={current} />
        ) : (
          <EmptyHome signedIn={Boolean(session.data?.user)} />
        )}
        <section className="mt-9">
          <p className="text-xs font-extrabold uppercase tracking-[.16em] text-primary">
            How Stitchly works
          </p>
          <h2 className="font-heading mt-1 text-2xl font-black">
            From PDF to one clear step
          </h2>
          <div className="mt-4 grid gap-3 md:grid-cols-3">
            <Step
              icon={FileUp}
              number="01"
              title="Add your pattern"
              body="Upload a private PDF from your phone or computer."
            />
            <Step
              icon={Sparkles}
              number="02"
              title="Check the structure"
              body="Review the sections, rounds, rows and finishing steps."
            />
            <Step
              icon={Play}
              number="03"
              title="Start making"
              body="Progress and notes sync to your account."
            />
          </div>
        </section>
      </div>
    </div>
  );
}
function ContinueProject({ project }: { project: Project }) {
  const pct = Math.min(
    100,
    Math.round(
      (project.current_instruction / project.total_instructions) * 100,
    ),
  );
  return (
    <section className="stitch-card grid overflow-hidden md:grid-cols-[.8fr_1.2fr]">
      <div className="relative min-h-48 overflow-hidden bg-[#59c3eb]">
        <PatternCover
          coverUrl={project.cover_url}
          craft={project.craft}
          alt={`${project.pattern_name} cover`}
          fallbackClassName="absolute inset-4 m-auto size-40"
        />
      </div>
      <div className="flex flex-col justify-center p-6">
        <p className="text-xs font-extrabold uppercase tracking-[.15em] text-primary">
          Continue making
        </p>
        <h2 className="font-heading mt-1 text-2xl font-black">
          {project.name}
        </h2>
        <p className="mt-1 text-sm text-muted-foreground">
          Step {project.current_instruction} of {project.total_instructions} ·{" "}
          {project.pattern_name}
        </p>
        <div className="mt-4 flex items-center gap-3">
          <Progress value={pct} className="h-2" />
          <span className="text-xs font-extrabold">{pct}%</span>
        </div>
        <Link
          href={`/projects/${project.id}/reader`}
          className="mt-5 inline-flex items-center gap-2 font-heading text-sm font-extrabold text-primary"
        >
          Open reader <ArrowRight className="size-4" />
        </Link>
      </div>
    </section>
  );
}
function EmptyHome({ signedIn }: { signedIn: boolean }) {
  return (
    <section className="relative overflow-hidden rounded-3xl bg-[#f58ba2] p-6 pb-7 md:pr-72">
      <div className="absolute -right-7 -top-8 size-48 rounded-full bg-[#fff8ea]/70" />
      <CraftArt
        art="basket"
        className="relative mx-auto size-52 md:absolute md:-bottom-12 md:right-8"
      />
      <div className="relative">
        <p className="text-xs font-extrabold uppercase tracking-[.15em] text-[#17324d]/60">
          Nothing tangled yet
        </p>
        <h2 className="font-heading mt-1 text-3xl font-black">
          Your first project starts with a pattern
        </h2>
        <p className="mt-2 max-w-md text-sm text-[#17324d]/75">
          {signedIn
            ? "Upload a PDF and its actual instructions will become a trackable project."
            : "Sign in to keep private PDFs, progress and notes together."}
        </p>
        <Link
          href={signedIn ? "/library/upload" : "/sign-in"}
          className="mt-5 inline-flex items-center gap-2 rounded-2xl bg-[#17324d] px-5 py-3 font-heading text-sm font-extrabold text-white"
        >
          <BookOpen className="size-4" />
          {signedIn ? "Add your first pattern" : "Sign in to begin"}
        </Link>
      </div>
    </section>
  );
}
function Step({
  icon: Icon,
  number,
  title,
  body,
}: {
  icon: typeof FileUp;
  number: string;
  title: string;
  body: string;
}) {
  return (
    <div className="stitch-card p-5">
      <div className="flex items-center justify-between">
        <span className="flex size-10 items-center justify-center rounded-2xl bg-secondary">
          <Icon className="size-5" />
        </span>
        <span className="font-heading text-sm font-black text-primary/50">
          {number}
        </span>
      </div>
      <h3 className="font-heading mt-4 font-extrabold">{title}</h3>
      <p className="mt-1 text-sm leading-relaxed text-muted-foreground">
        {body}
      </p>
    </div>
  );
}
