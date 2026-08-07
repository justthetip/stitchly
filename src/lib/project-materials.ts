export type ProjectMaterial = { id: string; name: string; detail?: string };

function item(id: string, name: string, detail?: string): ProjectMaterial {
  return { id, name, detail };
}

export function deriveProjectMaterials({
  yarn,
  tool,
  instructions,
}: {
  yarn?: string | null;
  tool?: string | null;
  instructions: string[];
}): ProjectMaterial[] {
  const materials: ProjectMaterial[] = [];
  if (yarn?.trim()) materials.push(item("yarn", "Yarn", yarn.trim()));
  if (tool?.trim()) materials.push(item("tool", "Needles or hook", tool.trim()));
  const source = instructions.join(" ").toLowerCase();
  if (/safety eyes?/.test(source)) materials.push(item("safety-eyes", "Toy safety eyes", "Size and quantity are given in the pattern steps"));
  if (/\b(stuff|stuffing|filling|fiberfill)\b/.test(source)) materials.push(item("stuffing", "Toy stuffing", "For filling the finished pieces"));
  if (/\b(sew|sewing|weave in)\b/.test(source)) materials.push(item("yarn-needle", "Yarn needle", "For sewing pieces and finishing ends"));
  if (/stitch markers?/.test(source)) materials.push(item("stitch-markers", "Stitch markers"));
  return materials;
}
