import { db } from "@/lib/db";
import { apiError, requireUser } from "@/lib/session";

export async function POST(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const user = await requireUser(); const { id } = await params; const body = await request.json() as { instructionPosition?: number; body?: string }; const sql = db();
    if (!body.body?.trim()) return Response.json({ error: "Note cannot be empty" }, { status: 400 });
    const project = await sql`select id from public.projects where id = ${id} and owner_id = ${user.id}`;
    if (!project[0]) return Response.json({ error: "Project not found" }, { status: 404 });
    const notes = await sql`insert into public.project_notes (project_id, owner_id, instruction_position, body) values (${id}, ${user.id}, ${body.instructionPosition ?? null}, ${body.body.trim()}) returning id, instruction_position, body, created_at, updated_at`;
    return Response.json({ note: notes[0] }, { status: 201 });
  } catch (error) { return apiError(error); }
}
