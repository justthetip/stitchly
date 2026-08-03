import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { put } from "@vercel/blob";
import { extractText, getDocumentProxy } from "unpdf";
import { db, type DbPattern, type DbPatternInstruction } from "@/lib/db";
import { parsePatternText } from "@/lib/pattern-parser";
import { createPrivatePatternCover } from "@/lib/pattern-cover";
import { apiError, requireUser } from "@/lib/session";

export const maxDuration = 60;

async function existingExample(ownerId: string) {
  const sql = db();
  const patterns = await sql`select id, owner_id, name, designer, craft, difficulty, yarn, tool, total_instructions, source, blob_url, page_count, created_at, updated_at, case when cover_blob_url is not null then '/api/patterns/' || id || '/cover' else null end as cover_url from public.patterns where owner_id = ${ownerId} and source = 'Stitchly example' limit 1` as DbPattern[];
  if (!patterns[0]) return null;
  const instructions = await sql`select id, pattern_id, position, section, section_quantity, section_position, instruction_kind, source_label, instruction_number, instruction_number_end, instructions, notes, stitch_count, optional, source_group, confidence from public.pattern_instructions where pattern_id = ${patterns[0].id} order by position` as DbPatternInstruction[];
  return { pattern: patterns[0], instructions, alreadyAdded: true };
}

export async function POST() {
  try {
    const user = await requireUser();
    const existing = await existingExample(user.id);
    if (existing) return Response.json(existing);

    const buffer = await readFile(join(process.cwd(), "public/examples/stitchly-starter-headband.pdf"));
    const pdf = await getDocumentProxy(new Uint8Array(buffer));
    const extracted = await extractText(pdf);
    const parsed = parsePatternText(extracted.text, "Stitchly Starter Headband");
    const blob = await put(`patterns/${user.id}/example/stitchly-starter-headband.pdf`, buffer, {
      access: "private",
      contentType: "application/pdf",
      addRandomSuffix: false,
    });
    const sql = db();
    const rawText = extracted.text.join("\n\n---PAGE---\n\n");
    let pattern: DbPattern;
    try {
      const inserted = await sql`insert into public.patterns (owner_id, name, designer, craft, difficulty, total_instructions, source, blob_url, page_count, raw_text) values (${user.id}, ${parsed.name}, ${parsed.designer}, ${parsed.craft}, ${parsed.difficulty}, ${parsed.totalInstructions}, 'Stitchly example', ${blob.url}, ${extracted.totalPages}, ${rawText}) returning id, owner_id, name, designer, craft, difficulty, yarn, tool, total_instructions, source, blob_url, page_count, created_at, updated_at` as DbPattern[];
      pattern = inserted[0];
    } catch (error) {
      const concurrent = await existingExample(user.id);
      if (concurrent) return Response.json(concurrent);
      throw error;
    }

    try {
      const instructionPayload = JSON.stringify(parsed.instructions.map((instruction) => ({
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

    let coverUrl: string | null = null;
    try {
      const coverBlobUrl = await createPrivatePatternCover(pdf, user.id, pattern.id);
      if (coverBlobUrl) {
        await sql`update public.patterns set cover_blob_url = ${coverBlobUrl}, updated_at = now() where id = ${pattern.id} and owner_id = ${user.id}`;
        coverUrl = `/api/patterns/${pattern.id}/cover`;
      }
    } catch {
      // Artwork is optional; the example remains usable with fallback imagery.
    }
    const instructions = await sql`select id, pattern_id, position, section, section_quantity, section_position, instruction_kind, source_label, instruction_number, instruction_number_end, instructions, notes, stitch_count, optional, source_group, confidence from public.pattern_instructions where pattern_id = ${pattern.id} order by position` as DbPatternInstruction[];
    return Response.json({ pattern: { ...pattern, cover_url: coverUrl }, instructions, alreadyAdded: false }, { status: 201 });
  } catch (error) {
    return apiError(error);
  }
}
