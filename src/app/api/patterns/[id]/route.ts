import { del } from "@vercel/blob";
import { db, type DbPattern, type DbPatternInstruction } from "@/lib/db";
import { apiError, requireUser } from "@/lib/session";

export async function GET(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const user = await requireUser(); const { id } = await params; const sql = db();
    const patterns = await sql`select id, owner_id, name, designer, craft, difficulty, yarn, tool, total_instructions, source, blob_url, page_count, created_at, updated_at from public.patterns where id = ${id} and owner_id = ${user.id}` as DbPattern[];
    if (!patterns[0]) return Response.json({ error: "Pattern not found" }, { status: 404 });
    const instructions = await sql`select id, pattern_id, position, section, section_quantity, section_position, instruction_kind, source_label, instruction_number, instruction_number_end, instructions, notes, stitch_count, optional, source_group, confidence from public.pattern_instructions where pattern_id = ${id} order by position` as DbPatternInstruction[];
    return Response.json({ pattern: patterns[0], instructions });
  } catch (error) { return apiError(error); }
}

export async function PATCH(request: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const user = await requireUser(); const { id } = await params; const body = await request.json() as {
      name?: string;
      designer?: string;
      yarn?: string;
      tool?: string;
      instructions?: Array<{
        position: number;
        section: string;
        sectionQuantity?: number;
        sectionPosition: number;
        instructionKind: string;
        sourceLabel?: string | null;
        instructionNumber?: number | null;
        instructionNumberEnd?: number | null;
        instructions: string;
        notes?: string | null;
        stitchCount?: number | null;
        optional?: boolean;
        sourceGroup?: string | null;
        confidence?: string;
      }>;
    }; const sql = db();
    const owned = await sql`select id from public.patterns where id = ${id} and owner_id = ${user.id}`;
    if (!owned[0]) return Response.json({ error: "Pattern not found" }, { status: 404 });
    await sql`update public.patterns set name = coalesce(${body.name ?? null}, name), designer = coalesce(${body.designer ?? null}, designer), yarn = coalesce(${body.yarn ?? null}, yarn), tool = coalesce(${body.tool ?? null}, tool), updated_at = now() where id = ${id} and owner_id = ${user.id}`;
    if (body.instructions) {
      const validKinds = ["round", "row", "step", "setup", "instruction", "choice", "repeat", "technique"];
      const instructions = body.instructions.filter(item => item.section.trim() && item.instructions.trim());
      if (!instructions.length) return Response.json({ error: "At least one valid instruction is required" }, { status: 400 });
      const instructionPayload = JSON.stringify(instructions.map((item, index) => ({
        position: index + 1,
        section: item.section.trim(),
        section_quantity: item.sectionQuantity && item.sectionQuantity > 0 ? item.sectionQuantity : 1,
        section_position: item.sectionPosition > 0 ? item.sectionPosition : index + 1,
        instruction_kind: validKinds.includes(item.instructionKind) ? item.instructionKind : "instruction",
        source_label: item.sourceLabel ?? null,
        instruction_number: item.instructionNumber ?? null,
        instruction_number_end: item.instructionNumberEnd ?? null,
        instructions: item.instructions.trim(),
        notes: item.notes?.trim() || null,
        stitch_count: item.stitchCount ?? null,
        optional: Boolean(item.optional),
        source_group: item.sourceGroup ?? null,
        confidence: ["high", "medium", "low"].includes(item.confidence ?? "") ? item.confidence : "medium",
      })));
      await sql.transaction([
        sql`delete from public.pattern_instructions where pattern_id = ${id}`,
        sql`insert into public.pattern_instructions (pattern_id, position, section, section_quantity, section_position, instruction_kind, source_label, instruction_number, instruction_number_end, instructions, notes, stitch_count, optional, source_group, confidence)
          select ${id}, position, section, section_quantity, section_position, instruction_kind, source_label, instruction_number, instruction_number_end, instructions, notes, stitch_count, optional, source_group, confidence
          from jsonb_to_recordset(${instructionPayload}::jsonb)
          as instruction_data(position integer, section text, section_quantity integer, section_position integer, instruction_kind text, source_label text, instruction_number integer, instruction_number_end integer, instructions text, notes text, stitch_count integer, optional boolean, source_group text, confidence text)`,
        sql`update public.patterns set total_instructions = ${instructions.length}, updated_at = now() where id = ${id} and owner_id = ${user.id}`,
      ]);
    }
    return Response.json({ ok: true });
  } catch (error) { return apiError(error); }
}

export async function DELETE(_request: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const user = await requireUser(); const { id } = await params; const sql = db();
    const deleted = await sql`delete from public.patterns where id = ${id} and owner_id = ${user.id} returning id, blob_url` as Array<{ id: string; blob_url: string | null }>;
    if (!deleted[0]) return Response.json({ error: "Pattern not found" }, { status: 404 });
    if (deleted[0].blob_url) await del(deleted[0].blob_url);
    return new Response(null, { status: 204 });
  } catch (error) { return apiError(error); }
}
