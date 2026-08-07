import assert from "node:assert/strict";
import test from "node:test";
import { photosForStep, type ProjectPhoto } from "../src/lib/project-photo-journal.ts";

const image = new Blob(["image"]);
const photos: ProjectPhoto[] = [
  { id: "one", projectId: "a", instructionPosition: 2, section: "Body", capturedAt: "2026-08-01T10:00:00Z", image },
  { id: "two", projectId: "a", instructionPosition: 3, section: "Body", capturedAt: "2026-08-01T11:00:00Z", image },
  { id: "three", projectId: "b", instructionPosition: 2, section: "Body", capturedAt: "2026-08-01T12:00:00Z", image },
];

test("photo journal isolates photos by both project and instruction", () => {
  assert.deepEqual(photosForStep(photos, "a", 2).map((photo) => photo.id), ["one"]);
});
