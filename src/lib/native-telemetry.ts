export const allowedNativeTelemetryEvents: ReadonlySet<string> = new Set([
  "app_opened",
  "pdf_import_started",
  "pdf_import_completed",
  "project_created",
  "reader_opened",
  "reader_progressed",
  "project_completed_in_reader",
  "metric_diagnostic_received",
]);

export function isAllowedNativeTelemetryEvent(value: unknown): value is string {
  return typeof value === "string" && allowedNativeTelemetryEvents.has(value);
}
