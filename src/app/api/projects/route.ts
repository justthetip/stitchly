import { db, type DbProject } from "@/lib/db";
import { apiError, requireUser } from "@/lib/session";

export async function GET() {
  try {
    const user = await requireUser(); const sql = db();
    const projects = await sql`select p.id, p.owner_id, p.pattern_id, p.name, p.status, p.yarn, p.current_instruction, p.started_at, p.last_worked_at, p.completed_at, pt.name as pattern_name, pt.total_instructions, pt.craft, case when pt.cover_blob_url is not null then '/api/patterns/' || pt.id || '/cover' else null end as cover_url from public.projects p join public.patterns pt on pt.id = p.pattern_id where p.owner_id = ${user.id} order by p.last_worked_at desc` as DbProject[];
    return Response.json({ projects });
  } catch (error) { return apiError(error); }
}

export async function POST(request: Request) {
  try {
    const user = await requireUser(); const body = await request.json() as { patternId?: string; name?: string; yarn?: string; notes?: string }; const sql = db();
    if (!body.patternId || !body.name?.trim()) return Response.json({ error: "Pattern and project name are required" }, { status: 400 });
    const pattern = await sql`select id from public.patterns where id = ${body.patternId} and owner_id = ${user.id}`;
    if (!pattern[0]) return Response.json({ error: "Pattern not found" }, { status: 404 });
    const projects = await sql`with first_project as (
      select not exists(select 1 from public.projects where owner_id = ${user.id}) as is_first_project
    ), inserted as (
      insert into public.projects (owner_id, pattern_id, name, yarn) values (${user.id}, ${body.patternId}, ${body.name.trim()}, ${body.yarn?.trim() || null})
      returning id, owner_id, pattern_id, name, status, yarn, current_instruction, started_at, last_worked_at, completed_at
    ) select inserted.*, first_project.is_first_project from inserted cross join first_project` as Array<DbProject & { is_first_project: boolean }>;
    if (body.notes?.trim()) await sql`insert into public.project_notes (project_id, owner_id, body) values (${projects[0].id}, ${user.id}, ${body.notes.trim()})`;
    const { is_first_project: isFirstProject, ...project } = projects[0];
    return Response.json({ project, isFirstProject }, { status: 201 });
  } catch (error) { return apiError(error); }
}
