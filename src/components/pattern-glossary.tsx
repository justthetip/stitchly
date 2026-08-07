"use client";

import { BookOpen, X } from "lucide-react";
import {
  glossarySegments,
  type PatternGlossaryTerm,
} from "@/lib/pattern-glossary";
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { cn } from "@/lib/utils";

export function GlossaryInstructionText({
  text,
  onSelect,
  className,
}: {
  text: string;
  onSelect: (term: PatternGlossaryTerm) => void;
  className?: string;
}) {
  return (
    <p className={className}>
      {glossarySegments(text).map((segment, index) =>
        segment.term ? (
          <button
            key={`${index}-${segment.text}`}
            type="button"
            className="inline rounded-sm font-inherit font-semibold text-primary underline decoration-primary/50 decoration-dotted underline-offset-4 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40"
            onClick={() => onSelect(segment.term!)}
            aria-label={`${segment.text}: ${segment.term.name}. Open glossary`}
          >
            {segment.text}
          </button>
        ) : (
          <span key={`${index}-${segment.text}`}>{segment.text}</span>
        ),
      )}
    </p>
  );
}

export function GlossarySheet({
  term,
  onOpenChange,
}: {
  term: PatternGlossaryTerm | null;
  onOpenChange: (open: boolean) => void;
}) {
  return (
    <Sheet open={term != null} onOpenChange={onOpenChange}>
      <SheetContent side="bottom" className="rounded-t-3xl pb-8">
        {term && (
          <>
            <SheetHeader className="text-left">
              <div className="mb-2 flex size-11 items-center justify-center rounded-2xl bg-secondary text-primary">
                <BookOpen className="size-5" />
              </div>
              <SheetTitle className="font-heading text-2xl font-black">
                {term.shorthand} · {term.name}
              </SheetTitle>
              <SheetDescription className="text-sm leading-relaxed">
                {term.definition}
              </SheetDescription>
            </SheetHeader>
            <button type="button" onClick={() => onOpenChange(false)} className="mx-4 mt-5 flex w-[calc(100%-2rem)] items-center justify-center gap-2 rounded-xl border bg-background px-4 py-3 text-sm font-extrabold">
              <X className="size-4" /> Close glossary
            </button>
          </>
        )}
      </SheetContent>
    </Sheet>
  );
}

export function GlossaryTermButton({ term, onSelect, className }: { term: PatternGlossaryTerm; onSelect: (term: PatternGlossaryTerm) => void; className?: string }) {
  return (
    <button type="button" onClick={() => onSelect(term)} className={cn("flex w-full items-start justify-between gap-4 rounded-2xl border bg-card p-4 text-left", className)}>
      <span>
        <span className="font-heading font-extrabold">{term.shorthand}</span>
        <span className="mt-1 block text-xs text-muted-foreground">{term.name}</span>
      </span>
      <span className="text-sm font-black text-primary" aria-hidden>?</span>
    </button>
  );
}
