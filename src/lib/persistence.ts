export type SavedProgress = { row: number; notes: Record<number, string> };

export function loadProgress(projectId: string, fallbackRow: number): SavedProgress {
  if (typeof window === "undefined") return { row: fallbackRow, notes: {} };
  try {
    const saved = window.localStorage.getItem(`stitchly:project:${projectId}`);
    return saved ? JSON.parse(saved) : { row: fallbackRow, notes: {} };
  } catch {
    return { row: fallbackRow, notes: {} };
  }
}

export function saveProgress(projectId: string, value: SavedProgress) {
  window.localStorage.setItem(`stitchly:project:${projectId}`, JSON.stringify(value));
}

export function saveDraftProject(value: { name: string; yarn: string; notes: string; patternId: string }) {
  window.localStorage.setItem("stitchly:last-project", JSON.stringify(value));
}

export function loadMaterialChecks(projectId: string): string[] {
  if (typeof window === "undefined") return [];
  try {
    const saved = window.localStorage.getItem(`stitchly:materials:${projectId}`);
    return saved ? JSON.parse(saved) : [];
  } catch { return []; }
}

export function saveMaterialChecks(projectId: string, checked: string[]) {
  window.localStorage.setItem(`stitchly:materials:${projectId}`, JSON.stringify(checked));
}
