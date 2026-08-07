import catalog from "./demo-catalog.json";
import type { PatternInstructionRecord } from "@/lib/pattern-instructions";
import { loadProgress } from "@/lib/persistence";

export type DemoPattern = {
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
  pdf_url: string;
  created_at: string;
};

export type DemoProject = {
  id: string;
  pattern_id: string;
  name: string;
  status: "planned" | "active" | "completed";
  yarn: string | null;
  current_instruction: number;
  started_at: string;
  last_worked_at: string;
  completed_at: string | null;
  pattern_name: string;
  total_instructions: number;
  craft: "knit" | "crochet";
  cover_url: string | null;
};

export const demoPatterns: DemoPattern[] = catalog.patterns.map((pattern) => ({
  id: pattern.id,
  name: pattern.name,
  designer: pattern.designer,
  craft: pattern.craft as "knit" | "crochet",
  difficulty: pattern.difficulty,
  yarn: pattern.yarn,
  tool: pattern.tool,
  total_instructions: pattern.totalInstructions,
  page_count: pattern.pageCount,
  source: pattern.source,
  cover_url: pattern.coverUrl,
  pdf_url: `/demo/${pattern.pdfResource}.pdf`,
  created_at: "2026-08-01T09:00:00.000Z",
}));

function instructionRecord(value: (typeof catalog.instructions)[keyof typeof catalog.instructions][number]): PatternInstructionRecord {
  return {
    id: value.id,
    position: value.position,
    section: value.section,
    section_quantity: value.sectionQuantity,
    section_position: value.sectionPosition,
    instruction_kind: value.instructionKind as PatternInstructionRecord["instruction_kind"],
    source_label: value.sourceLabel,
    instruction_number: value.instructionNumber,
    instruction_number_end: value.instructionNumberEnd,
    instructions: value.instructions,
    notes: value.notes,
    stitch_count: value.stitchCount,
    optional: value.optional,
    source_group: value.sourceGroup,
    confidence: value.confidence as PatternInstructionRecord["confidence"],
  };
}

const instructionsByPattern = Object.fromEntries(
  Object.entries(catalog.instructions).map(([patternID, values]) => [
    patternID,
    values.map(instructionRecord),
  ]),
) as Record<string, PatternInstructionRecord[]>;

export const demoProjects: DemoProject[] = [
  {
    id: catalog.project.id,
    pattern_id: catalog.project.patternId,
    name: catalog.project.name,
    status: catalog.project.status as DemoProject["status"],
    yarn: catalog.project.yarn,
    current_instruction: catalog.project.currentInstruction,
    started_at: catalog.project.startedAt,
    last_worked_at: catalog.project.lastWorkedAt,
    completed_at: catalog.project.completedAt,
    pattern_name: catalog.project.patternName,
    total_instructions: catalog.project.totalInstructions,
    craft: catalog.project.craft as DemoProject["craft"],
    cover_url: catalog.project.coverUrl,
  },
  {
    id: "demo-completed-mini-whale",
    pattern_id: "demo-mini-whale",
    name: "My Mini Whale",
    status: "completed",
    yarn: "Worsted weight yarn",
    current_instruction: 12,
    started_at: "2026-07-12T10:00:00.000Z",
    last_worked_at: "2026-07-18T15:30:00.000Z",
    completed_at: "2026-07-18T15:30:00.000Z",
    pattern_name: "Mini Whale",
    total_instructions: 12,
    craft: "crochet",
    cover_url: "/demo/mini-whale-cover.png",
  },
];

export function demoPattern(id: string) { return demoPatterns.find((pattern) => pattern.id === id); }
export function demoProject(id: string) {
  const project = demoProjects.find((candidate) => candidate.id === id);
  if (!project) return undefined;
  const progress = loadProgress(project.id, project.current_instruction);
  const currentInstruction = progress.row > 0 && progress.row <= project.total_instructions
    ? progress.row
    : project.current_instruction;
  return { ...project, current_instruction: currentInstruction };
}
export function demoInstructions(id: string) { return instructionsByPattern[id] ?? []; }
export function isDemoPattern(id: string) { return Boolean(demoPattern(id)); }
export function isDemoProject(id: string) { return Boolean(demoProject(id)); }
