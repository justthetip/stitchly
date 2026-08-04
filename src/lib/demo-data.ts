import type { PatternInstructionRecord } from "@/lib/pattern-instructions";

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

export const demoInstructions: PatternInstructionRecord[] = [
  { id: "demo-i1", position: 1, section: "Back panel", section_quantity: 1, section_position: 1, instruction_kind: "setup", source_label: "Foundation", instruction_number: null, instruction_number_end: null, instructions: "Chain 72 loosely. Turn, working into the back bumps for a neat lower edge.", notes: "Keep the foundation chain relaxed.", stitch_count: 72, optional: false, source_group: null, confidence: "high" },
  { id: "demo-i2", position: 2, section: "Back panel", section_quantity: 1, section_position: 2, instruction_kind: "row", source_label: "Row 1", instruction_number: 1, instruction_number_end: null, instructions: "Double crochet in the fourth chain from the hook and in every chain across. Turn.", notes: null, stitch_count: 70, optional: false, source_group: null, confidence: "high" },
  { id: "demo-i3", position: 3, section: "Back panel", section_quantity: 1, section_position: 3, instruction_kind: "row", source_label: "Row 2", instruction_number: 2, instruction_number_end: null, instructions: "Chain 3, skip the first stitch, double crochet across. Turn.", notes: "Repeat this row until the panel measures 38 cm.", stitch_count: 70, optional: false, source_group: null, confidence: "high" },
  { id: "demo-i4", position: 4, section: "Left front", section_quantity: 1, section_position: 1, instruction_kind: "setup", source_label: "Foundation", instruction_number: null, instruction_number_end: null, instructions: "Chain 38 loosely for the left front panel.", notes: null, stitch_count: 38, optional: false, source_group: null, confidence: "high" },
  { id: "demo-i5", position: 5, section: "Left front", section_quantity: 1, section_position: 2, instruction_kind: "row", source_label: "Row 1", instruction_number: 1, instruction_number_end: null, instructions: "Double crochet across, keeping the front edge relaxed.", notes: null, stitch_count: 36, optional: false, source_group: null, confidence: "high" },
  { id: "demo-i6", position: 6, section: "Sleeves", section_quantity: 2, section_position: 1, instruction_kind: "setup", source_label: "Cuff", instruction_number: null, instruction_number_end: null, instructions: "Work the cuff ribbing to the required wrist measurement.", notes: "Make two matching sleeves.", stitch_count: null, optional: false, source_group: null, confidence: "high" },
];

export const demoPatterns: DemoPattern[] = [{
  id: "pattern-demo",
  name: "Wildflower Cardigan",
  designer: "Stitchly Studio",
  craft: "crochet",
  difficulty: "Intermediate",
  yarn: "DK cotton",
  tool: "4 mm hook",
  total_instructions: demoInstructions.length,
  page_count: 8,
  source: "Demo PDF",
  cover_url: null,
  created_at: "2026-08-01T09:00:00.000Z",
}];

export const demoProjects: DemoProject[] = [{
  id: "project-demo",
  pattern_id: demoPatterns[0].id,
  name: "My coral cardigan",
  status: "active",
  yarn: "Coral merino blend",
  current_instruction: 2,
  started_at: "2026-08-01T09:00:00.000Z",
  last_worked_at: "2026-08-04T09:00:00.000Z",
  completed_at: null,
  pattern_name: demoPatterns[0].name,
  total_instructions: demoInstructions.length,
  craft: demoPatterns[0].craft,
  cover_url: null,
}];

export function demoPattern(id: string) { return demoPatterns.find((pattern) => pattern.id === id); }
export function demoProject(id: string) { return demoProjects.find((project) => project.id === id); }
