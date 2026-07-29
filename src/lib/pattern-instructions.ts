export type PatternInstructionRecord = {
  id?: string;
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
  confidence: "high" | "medium" | "low";
};

export function instructionLabel(instruction: PatternInstructionRecord) {
  const number = instruction.instruction_number;
  if (instruction.instruction_kind === "round" && number != null) {
    const prefix = /^rnd\b/i.test(instruction.source_label ?? "") ? "Rnd" : "Round";
    return `${prefix} ${number}`;
  }
  if (instruction.instruction_kind === "row" && number != null) return `Row ${number}`;
  if (instruction.instruction_kind === "step" && number != null) return `Step ${number}`;
  if (instruction.source_label) return instruction.source_label;
  if (number != null) return `Step ${number}`;
  const labels: Record<PatternInstructionRecord["instruction_kind"], string> = {
    round: "Round",
    row: "Row",
    step: "Step",
    setup: "Setup",
    instruction: "Instruction",
    choice: "Choose a method",
    repeat: "Optional repeat",
    technique: "Technique",
  };
  return labels[instruction.instruction_kind];
}

export function instructionGuidance(instruction: PatternInstructionRecord) {
  const guidance: Record<PatternInstructionRecord["instruction_kind"], string> = {
    round: "Complete one full loop around your work before moving on.",
    row: "Work across this line of stitches, then follow the pattern's turning direction.",
    step: "Complete this assembly step before moving to the next one.",
    setup: "Prepare the piece so it is ready for the first worked instruction.",
    instruction: "Complete this piece of work before moving on.",
    choice: "Choose the finishing method that fits how you plan to use the piece.",
    repeat: "This is optional. Use it when you want to make the piece larger.",
    technique: "This optional technique changes how the work looks or is finished.",
  };
  return guidance[instruction.instruction_kind];
}
