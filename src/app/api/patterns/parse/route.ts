import { get } from "@vercel/blob";
import { extractText, getDocumentProxy } from "unpdf";
import { db, type DbPattern, type DbPatternInstruction } from "@/lib/db";
import { parsePatternText } from "@/lib/pattern-parser";
import { apiError, requireUser } from "@/lib/session";

export const maxDuration = 60;

export async function POST(request: Request) {
  try {
    const user = await requireUser();
    const body = await request.json() as { url?: string; name?: string };
    if (!body.url || !body.name) return Response.json({ error: "A private PDF URL and filename are required" }, { status: 400 });
    if (!body.url.includes(".private.blob.vercel-storage.com/")) return Response.json({ error: "Only Stitchly private Blob files can be parsed" }, { status: 400 });
    if (!new URL(body.url).pathname.startsWith(`/patterns/${user.id}/`)) return Response.json({ error: "This upload does not belong to the signed-in user" }, { status: 403 });

    const result = await get(body.url, { access: "private" });
    if (!result?.stream || result.statusCode !== 200) return Response.json({ error: "The uploaded PDF could not be retrieved" }, { status: 404 });
    if (result.blob.contentType !== "application/pdf") return Response.json({ error: "The uploaded file is not a PDF" }, { status: 415 });
    if ((result.blob.size ?? 0) > 25 * 1024 * 1024) return Response.json({ error: "PDF exceeds the 25 MB limit" }, { status: 413 });

    const buffer = new Uint8Array(await new Response(result.stream).arrayBuffer());
    const pdf = await getDocumentProxy(buffer);
    const extracted = await extractText(pdf);
    const parsed = parsePatternText(extracted.text, body.name);
    const sql = db();
    const rawText = extracted.text.join("\n\n---PAGE---\n\n");
    const inserted = await sql`insert into public.patterns (owner_id, name, designer, craft, difficulty, total_instructions, source, blob_url, page_count, raw_text) values (${user.id}, ${parsed.name}, ${parsed.designer}, ${parsed.craft}, ${parsed.difficulty}, ${parsed.totalInstructions}, 'PDF', ${body.url}, ${extracted.totalPages}, ${rawText}) returning id, owner_id, name, designer, craft, difficulty, yarn, tool, total_instructions, source, blob_url, page_count, created_at, updated_at` as DbPattern[];
    const pattern = inserted[0];
    try {
      const instructionPayload = JSON.stringify(parsed.instructions.map(instruction => ({
        position: instruction.position,
        section: instruction.section,
        section_quantity: instruction.sectionQuantity,
        section_position: instruction.sectionPosition,
        instruction_kind: instruction.instructionKind,
        source_label: instruction.sourceLabel,
        instruction_number: instruction.instructionNumber,
        instruction_number_end: instruction.instructionNumberEnd,
        instructions: instruction.instructions,
        notes: instruction.notes,
        stitch_count: instruction.stitchCount,
        optional: instruction.optional,
        source_group: instruction.sourceGroup,
        confidence: instruction.confidence,
      })));
      await sql`insert into public.pattern_instructions (pattern_id, position, section, section_quantity, section_position, instruction_kind, source_label, instruction_number, instruction_number_end, instructions, notes, stitch_count, optional, source_group, confidence)
        select ${pattern.id}, position, section, section_quantity, section_position, instruction_kind, source_label, instruction_number, instruction_number_end, instructions, notes, stitch_count, optional, source_group, confidence
        from jsonb_to_recordset(${instructionPayload}::jsonb)
        as instruction_data(position integer, section text, section_quantity integer, section_position integer, instruction_kind text, source_label text, instruction_number integer, instruction_number_end integer, instructions text, notes text, stitch_count integer, optional boolean, source_group text, confidence text)`;
    } catch (error) {
      await sql`delete from public.patterns where id = ${pattern.id} and owner_id = ${user.id}`;
      throw error;
    }
    const instructions = await sql`select id, pattern_id, position, section, section_quantity, section_position, instruction_kind, source_label, instruction_number, instruction_number_end, instructions, notes, stitch_count, optional, source_group, confidence from public.pattern_instructions where pattern_id = ${pattern.id} order by position` as DbPatternInstruction[];
    return Response.json({ pattern, sections: parsed.sections, instructions }, { status: 201 });
  } catch (error) { return apiError(error); }
}
