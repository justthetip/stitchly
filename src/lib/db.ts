import { neon } from "@neondatabase/serverless";

export function db() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error("DATABASE_URL is not configured");
  return neon(url);
}

export type DbPattern = {
  id: string;
  owner_id: string;
  name: string;
  designer: string | null;
  craft: "knit" | "crochet";
  difficulty: string | null;
  yarn: string | null;
  tool: string | null;
  total_instructions: number;
  source: string;
  blob_url: string | null;
  page_count: number | null;
  created_at: string;
  updated_at: string;
  cover_blob_url?: string | null;
};

export type DbPatternInstruction = {
  id: string;
  pattern_id: string;
  position: number;
  section: string;
  section_quantity: number;
  section_position: number;
  instruction_kind: "round" | "row" | "step" | "setup" | "instruction" | "choice" | "repeat" | "technique";
  source_label: string | null;
  instruction_number: number | null;
  instruction_number_end: number | null;
  instructions: string;
  notes: string | null;
  stitch_count: number | null;
  optional: boolean;
  source_group: string | null;
  confidence: "high" | "medium" | "low" | null;
};

export type DbProject = {
  id: string;
  owner_id: string;
  pattern_id: string;
  name: string;
  status: "planned" | "active" | "completed";
  yarn: string | null;
  current_instruction: number;
  started_at: string;
  last_worked_at: string;
  completed_at: string | null;
  pattern_name?: string;
  total_instructions?: number;
  craft?: "knit" | "crochet";
  cover_url?: string | null;
};
