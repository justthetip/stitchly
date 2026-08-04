import { db } from "@/lib/db";
import { isAllowedNativeTelemetryEvent } from "@/lib/native-telemetry";
import { apiError, requireUser } from "@/lib/session";

export async function POST(request: Request) {
  try {
    const user = await requireUser();
    const body = await request.json() as { event?: string; appVersion?: string; buildNumber?: string; properties?: Record<string, string | number | boolean> };
    if (!isAllowedNativeTelemetryEvent(body.event)) return Response.json({ error: "Unknown event" }, { status: 400 });
    const properties = Object.fromEntries(Object.entries(body.properties ?? {}).slice(0, 12).filter(([, value]) => ["string", "number", "boolean"].includes(typeof value)));
    const sql = db();
    await sql`insert into public.native_telemetry_events (owner_id, event_name, app_version, build_number, properties) values (${user.id}, ${body.event}, ${body.appVersion ?? null}, ${body.buildNumber ?? null}, ${JSON.stringify(properties)}::jsonb)`;
    return Response.json({ ok: true }, { status: 201 });
  } catch (error) { return apiError(error); }
}
