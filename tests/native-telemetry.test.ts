import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { allowedNativeTelemetryEvents, isAllowedNativeTelemetryEvent } from "../src/lib/native-telemetry.ts";

const nativeTelemetrySources = [
  "ios/Stitchly/Telemetry.swift",
  "ios/Stitchly/LibraryViews.swift",
  "ios/Stitchly/ProjectViews.swift",
];

test("the server accepts every literal telemetry event emitted by iOS", async () => {
  const sources = await Promise.all(nativeTelemetrySources.map((path) => readFile(path, "utf8")));
  const emittedEvents = new Set(
    sources.flatMap((source) => [...source.matchAll(/(?:Telemetry\.shared\.)?track\("([^"]+)"/g)].map((match) => match[1])),
  );

  assert.ok(emittedEvents.size > 0, "expected to find literal iOS telemetry events");
  assert.deepEqual(
    [...emittedEvents].filter((event) => !allowedNativeTelemetryEvents.has(event)),
    [],
    "iOS emitted a telemetry event that the server would reject",
  );
});

test("unknown and non-string telemetry events remain rejected", () => {
  assert.equal(isAllowedNativeTelemetryEvent("pattern_text_captured"), false);
  assert.equal(isAllowedNativeTelemetryEvent(undefined), false);
  assert.equal(isAllowedNativeTelemetryEvent({ event: "app_opened" }), false);
});
