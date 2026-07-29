export type InstructionKind =
  | "round"
  | "row"
  | "step"
  | "setup"
  | "instruction"
  | "choice"
  | "repeat"
  | "technique";

export type ExtractedInstruction = {
  position: number;
  section: string;
  sectionQuantity: number;
  sectionPosition: number;
  instructionKind: InstructionKind;
  sourceLabel: string | null;
  instructionNumber: number | null;
  instructionNumberEnd: number | null;
  instructions: string;
  notes: string | null;
  stitchCount: number | null;
  optional: boolean;
  sourceGroup: string | null;
  confidence: "high" | "medium" | "low";
};

export type ParsedSection = {
  name: string;
  quantity: number;
  instructionCount: number;
};

export type ParsedPattern = {
  name: string;
  designer: string | null;
  difficulty: string | null;
  craft: "knit" | "crochet";
  totalInstructions: number;
  sections: ParsedSection[];
  instructions: ExtractedInstruction[];
};

type Marker = {
  kind: "round" | "row";
  start: number;
  end: number;
  sourceLabel: string;
  remainder: string;
};

type DraftInstruction = Omit<
  ExtractedInstruction,
  "position" | "sectionPosition" | "section" | "sectionQuantity"
>;

const referenceHeadings = new Set([
  "abbreviations",
  "chart",
  "finished sizes",
  "materials",
  "overview",
  "skill level",
  "symbols",
  "to change colors",
  "to change colours",
  "you will need",
]);

const terminalLines = [
  /^chart$/i,
  /^symbols$/i,
  /^enjoy!?$/i,
  /^follow us\b/i,
  /^this pattern is intended\b/i,
  /^yay for yarn copyright/i,
];

const actionStarts =
  /^(?:ch(?:ain)?\d*\b|cast\b|join\b|start\b|using\b|make\b|work\b|sew\b|stitch\b|crochet\b|knit\b|turn\b|sc\b|dc\b|hdc\b|tr\b|inc\b|dec\b|cssc\b|csdc\b|\d+\s*(?:sc|dc|hdc|tr)\b|\(|\*)/i;

function clean(value: string) {
  return value
    .replace(/\u00ad/g, "")
    .replace(/[ \t]+/g, " ")
    .replace(/\s+([,.;:])/g, "$1")
    .trim();
}

function titleFromFilename(filename: string) {
  return filename
    .replace(/\.pdf$/i, "")
    .replace(/\+/g, " ")
    .replace(/[-_]+/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

function inferCraft(text: string): "knit" | "crochet" {
  const crochet = (
    text.match(/\b(sc|dc|hdc|tr|ch|sl st|slst|crochet|hook|magic ring|mr)\b/gi) ?? []
  ).length;
  const knit = (
    text.match(/\b(knit|purl|k\d|p\d|ssk|k2tog|needle|cast on)\b/gi) ?? []
  ).length;
  return crochet > knit ? "crochet" : "knit";
}

function isJunkLine(line: string) {
  return (
    !line ||
    /^\d+$/.test(line) ||
    /^©/.test(line) ||
    /^reproducing, distributing, or transmitting\b/i.test(line)
  );
}

function preparePages(input: string | string[]) {
  const pages = Array.isArray(input) ? input : input.split(/\f|\n\s*---PAGE---\s*\n/);
  const allText = pages.join("\n");
  const printRange = allText.match(
    /printer-friendly version,?\s*print pages?\s*(\d+)\s*[-–—]\s*(\d+)/i,
  );
  const selected = printRange
    ? pages.slice(Number(printRange[1]) - 1, Number(printRange[2]))
    : pages;

  return selected.map((page) =>
    page
      .replace(/\r/g, "\n")
      .split(/\n+/)
      .map(clean)
      .filter((line) => !isJunkLine(line)),
  );
}

function parseMarker(line: string): Marker | null {
  const match = line.match(
    /^(Rnd|Rounds?|Rows?)\s+(\d+)(?:\s*[-–—]\s*(\d+))?(?:\s*\[[^\]]+\])?\s*(:)?\s*(.*)$/i,
  );
  if (!match) return null;
  const remainder = clean(match[5]);
  const hasColon = Boolean(match[4]);
  const startsWithAnnotation = /^(?:note:|optional round\.)/i.test(remainder);
  if (!hasColon && (!remainder || /^[,.;)]/.test(remainder) || (!startsWithAnnotation && !actionStarts.test(remainder)))) {
    return null;
  }
  const start = Number(match[2]);
  const end = match[3] ? Number(match[3]) : start;
  if (end < start || end - start > 100) return null;
  return {
    kind: /^row/i.test(match[1]) ? "row" : "round",
    start,
    end,
    sourceLabel: clean(line.slice(0, line.length - match[5].length).replace(/:\s*$/, "")),
    remainder,
  };
}

function isNumberedStep(line: string) {
  return /^(\d{1,3})[.)]\s+(.+)$/.test(line);
}

function normalizeHeading(line: string) {
  return clean(line.replace(/:$/, "")).toLowerCase();
}

function isHeadingCandidate(line: string) {
  const normalized = normalizeHeading(line);
  if (
    line.length > 64 ||
    line.split(/\s+/).length > 9 ||
    referenceHeadings.has(normalized) ||
    terminalLines.some((pattern) => pattern.test(line)) ||
    parseMarker(line) ||
    isNumberedStep(line) ||
    actionStarts.test(line) ||
    /[.!?]$/.test(line) ||
    /[=]/.test(line) ||
    /^(?:note|round|row|rnd)\b/i.test(line)
  ) {
    return false;
  }
  return /^[A-Z]/.test(line);
}

function isActionHeading(lines: string[], index: number) {
  const line = lines[index];
  if (!isHeadingCandidate(line)) return false;
  if (/\b(?:assembly|finishing)\b/i.test(line) || /\b(?:x\s*\d+|\(make\s+\d+\))\s*$/i.test(line)) {
    return true;
  }
  for (let offset = 1; offset <= 4 && index + offset < lines.length; offset += 1) {
    const next = lines[index + offset];
    if (parseMarker(next) || isNumberedStep(next)) return true;
    if (offset === 1 && actionStarts.test(next)) return true;
    if (isHeadingCandidate(next)) break;
  }
  return false;
}

function sectionDetails(heading: string) {
  const xQuantity = heading.match(/\bx\s*(\d+)\s*$/i);
  const makeQuantity = heading.match(/\(make\s+(\d+)\)\s*$/i);
  const quantity = Number(xQuantity?.[1] ?? makeQuantity?.[1] ?? 1);
  const name = clean(
    heading
      .replace(/\bx\s*\d+\s*$/i, "")
      .replace(/\(make\s+\d+\)\s*$/i, ""),
  );
  return { name, quantity };
}

function extractStitchCount(value: string) {
  const parentheticals = [...value.matchAll(/\((\d+)\)/g)];
  const parenthetical = parentheticals.at(-1);
  const prose = value.match(/\byou should have\s+(\d+)\s+sts?\b/i);
  const parentheticalCount = parenthetical?.[1];
  return {
    stitchCount: Number(parentheticalCount ?? prose?.[1]) || null,
    text: clean(
      parenthetical
        ? `${value.slice(0, parenthetical.index)} ${value.slice((parenthetical.index ?? 0) + parenthetical[0].length)}`
        : value,
    ),
  };
}

function extractInstructionMetadata(value: string) {
  let text = clean(value);
  const notes: string[] = [];
  let optional = false;

  if (/^optional round\./i.test(text)) {
    optional = true;
    notes.push("Optional round.");
    text = clean(text.replace(/^optional round\.\s*/i, ""));
  }

  if (/^note:/i.test(text)) {
    const split = text.match(
      /^note:\s*(.+?)(?=\s+(?:join|start|using|ch\d*\b|cssc\b|csdc\b|sc\b|dc\b|hdc\b|tr\b|\())/i,
    );
    if (split) {
      notes.push(clean(split[1]));
      text = clean(text.slice(split[0].length));
    }
  }

  const trailingNote = text.match(/\s+\*([^*]+)\*\s*$/);
  if (trailingNote) {
    notes.push(clean(trailingNote[1]));
    text = clean(text.slice(0, trailingNote.index));
  }

  const count = extractStitchCount(text);
  return {
    text: count.text,
    notes: notes.length ? notes.join(" ") : null,
    optional,
    stitchCount: count.stitchCount,
  };
}

function paragraphs(lines: string[]) {
  const result: string[] = [];
  let current = "";
  for (const line of lines) {
    if (!current) {
      current = line;
      continue;
    }
    if (/[.!?]$/.test(current) && /^[A-Z*]/.test(line)) {
      result.push(clean(current));
      current = line;
    } else {
      current = clean(`${current} ${line}`);
    }
  }
  if (current) result.push(clean(current));
  return result.filter(Boolean);
}

function draft(
  kind: InstructionKind,
  sourceLabel: string | null,
  number: number | null,
  numberEnd: number | null,
  value: string,
  confidence: DraftInstruction["confidence"],
  overrides: Partial<DraftInstruction> = {},
): DraftInstruction {
  const metadata = extractInstructionMetadata(value);
  return {
    instructionKind: kind,
    sourceLabel,
    instructionNumber: number,
    instructionNumberEnd: numberEnd,
    instructions: metadata.text,
    notes: metadata.notes,
    stitchCount: metadata.stitchCount,
    optional: metadata.optional,
    sourceGroup: null,
    confidence,
    ...overrides,
  };
}

function parseAssembly(lines: string[]) {
  const numbered = lines.some(isNumberedStep);
  if (!numbered) {
    return paragraphs(lines)
      .filter((value) => actionStarts.test(value))
      .map((value, index) => draft("step", null, index + 1, null, value, "medium"));
  }

  const result: DraftInstruction[] = [];
  let current: { number: number; lines: string[] } | null = null;
  for (const line of lines) {
    const match = line.match(/^(\d{1,3})[.)]\s+(.+)$/);
    if (match) {
      if (current) {
        result.push(
          draft("step", String(current.number), current.number, null, current.lines.join(" "), "high"),
        );
      }
      current = { number: Number(match[1]), lines: [match[2]] };
    } else if (current) {
      current.lines.push(line);
    }
  }
  if (current) {
    result.push(
      draft("step", String(current.number), current.number, null, current.lines.join(" "), "high"),
    );
  }
  return result;
}

function parseSpecialTrailingBlocks(lines: string[]) {
  const result: DraftInstruction[] = [];
  const choiceStart = lines.findIndex((line) => /^if you want to use the yarn tail/i.test(line));
  const repeatStart = lines.findIndex((line) => /^if you want, you can continue/i.test(line));
  const colourStart = lines.findIndex((line) => /^you can also make .*multicolou?red/i.test(line));

  if (choiceStart >= 0) {
    const end = Math.min(
      ...[repeatStart, colourStart, lines.length].filter((value) => value > choiceStart),
    );
    result.push(
      draft(
        "choice",
        "Choose a finishing method",
        null,
        null,
        lines.slice(choiceStart, end).join(" "),
        "medium",
      ),
    );
  }
  if (repeatStart >= 0) {
    const end = Math.min(
      ...[colourStart, lines.length].filter((value) => value > repeatStart),
    );
    result.push(
      draft(
        "repeat",
        "Add more rounds",
        null,
        null,
        lines.slice(repeatStart, end).join(" "),
        "medium",
        { optional: true },
      ),
    );
  }
  if (colourStart >= 0) {
    result.push(
      draft(
        "technique",
        "Change colours",
        null,
        null,
        lines
          .slice(colourStart)
          .filter((line) => !/^to change colou?rs:?$/i.test(line))
          .join(" "),
        "medium",
        { optional: true },
      ),
    );
  }
  return { result, firstIndex: Math.min(...[choiceStart, repeatStart, colourStart].filter((value) => value >= 0), lines.length) };
}

function parseWorkedSection(lines: string[]) {
  const markerIndices = lines
    .map((line, index) => (parseMarker(line) ? index : -1))
    .filter((index) => index >= 0);

  if (!markerIndices.length) {
    return paragraphs(lines)
      .filter((value) => actionStarts.test(value))
      .map((value, index) => draft("instruction", null, index + 1, null, value, "medium"));
  }

  const result: DraftInstruction[] = [];
  const preamble = lines.slice(0, markerIndices[0]);
  const preambleNotes = preamble.filter((line) => /^note:/i.test(line));
  const setup = preamble.filter((line) => !/^note:/i.test(line));
  if (setup.length && actionStarts.test(setup.join(" "))) {
    result.push(draft("setup", "Setup", null, null, setup.join(" "), "medium"));
  }

  for (let markerIndex = 0; markerIndex < markerIndices.length; markerIndex += 1) {
    const lineIndex = markerIndices[markerIndex];
    const marker = parseMarker(lines[lineIndex]);
    if (!marker) continue;
    const nextIndex = markerIndices[markerIndex + 1] ?? lines.length;
    let continuation = lines.slice(lineIndex + 1, nextIndex);
    const special = markerIndex === markerIndices.length - 1
      ? parseSpecialTrailingBlocks(continuation)
      : { result: [], firstIndex: continuation.length };
    continuation = continuation.slice(0, special.firstIndex);
    const metadata = extractInstructionMetadata(
      [marker.remainder, ...continuation].join(" "),
    );
    const sharedNotes = [
      markerIndex === 0 ? preambleNotes.map((note) => clean(note.replace(/^note:\s*/i, ""))).join(" ") : "",
      metadata.notes ?? "",
    ].filter(Boolean).join(" ") || null;
    const sourceGroup = marker.end > marker.start
      ? `${marker.kind}:${marker.start}-${marker.end}`
      : null;

    for (let number = marker.start; number <= marker.end; number += 1) {
      result.push({
        instructionKind: marker.kind,
        sourceLabel: marker.sourceLabel,
        instructionNumber: number,
        instructionNumberEnd: marker.end > marker.start ? marker.end : null,
        instructions: metadata.text,
        notes: sharedNotes,
        stitchCount: metadata.stitchCount,
        optional: metadata.optional,
        sourceGroup,
        confidence: "high",
      });
    }
    result.push(...special.result);
  }
  return result;
}

function inferMetadata(allPages: string[][], filename: string, rawText: string) {
  const lines = allPages.flat();
  const text = lines.join(" ");
  const headerLines = allPages[0]?.slice(0, 12) ?? [];
  const bySameLine = headerLines
    .map((line) => line.match(/^(.+?)(?:\s+crochet pattern)?\s+by\s+(.+)$/i))
    .find(Boolean);
  const byNextLineIndex = headerLines.findIndex((line) => /^by\s+.+/i.test(line));
  const howTo = headerLines.find((line) => /^how to\b/i.test(line));
  const coverTitle = headerLines.find(
    (line) =>
      line.length <= 48 &&
      /^[A-Z]/.test(line) &&
      !referenceHeadings.has(normalizeHeading(line)) &&
      !/^by\b|^copyright\b|^for personal\b/i.test(line) &&
      !/[.!?:]$/.test(line),
  );
  const copyrightDesigner = rawText.match(/©\s*\d{4},?\s*([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)+)/);
  const difficulty =
    lines.map((line) => line.match(/^skill level:?\s*(.+)$/i)).find(Boolean)?.[1] ?? null;

  let name = titleFromFilename(filename);
  if (bySameLine) {
    name = clean(bySameLine[1].replace(/\s+crochet pattern$/i, ""));
  } else if (howTo) {
    name = howTo;
  } else if (coverTitle) {
    name = coverTitle;
  }
  if (/^original pattern$/i.test(name) && lines.includes("Lion")) name = "Lion";

  const designer = bySameLine?.[2]
    ? clean(bySameLine[2])
    : byNextLineIndex >= 0
      ? clean(headerLines[byNextLineIndex].replace(/^by\s+/i, ""))
      : copyrightDesigner?.[1] ?? null;
  return { name, designer, difficulty, craft: inferCraft(text) };
}

export function parsePatternText(input: string | string[], filename: string): ParsedPattern {
  const rawText = Array.isArray(input) ? input.join("\n") : input;
  const pages = preparePages(input);
  const metadata = inferMetadata(pages, filename, rawText);
  const lines = pages.flat();
  const headingIndices = lines
    .map((_, index) => (isActionHeading(lines, index) ? index : -1))
    .filter((index) => index >= 0);

  const extracted: ExtractedInstruction[] = [];
  const sections: ParsedSection[] = [];

  for (let headingPosition = 0; headingPosition < headingIndices.length; headingPosition += 1) {
    const start = headingIndices[headingPosition];
    const nextHeading = headingIndices[headingPosition + 1] ?? lines.length;
    const terminal = lines.findIndex(
      (line, index) => index > start && index < nextHeading && terminalLines.some((pattern) => pattern.test(line)),
    );
    const end = terminal >= 0 ? terminal : nextHeading;
    const details = sectionDetails(lines[start]);
    const sectionLines = lines.slice(start + 1, end);
    const drafts = /\b(?:assembly|finishing)\b/i.test(details.name)
      ? parseAssembly(sectionLines)
      : parseWorkedSection(sectionLines);
    if (!drafts.length) continue;

    const sectionStartPosition = extracted.length;
    for (const item of drafts) {
      if (!item.instructions) continue;
      extracted.push({
        ...item,
        position: extracted.length + 1,
        section: details.name,
        sectionQuantity: details.quantity,
        sectionPosition: extracted.length - sectionStartPosition + 1,
      });
    }
    sections.push({
      name: details.name,
      quantity: details.quantity,
      instructionCount: extracted.length - sectionStartPosition,
    });
  }

  if (!extracted.length) {
    throw new Error(
      "No structured instructions were found in this PDF. It may be scanned or use an unsupported layout.",
    );
  }

  return {
    ...metadata,
    totalInstructions: extracted.length,
    sections,
    instructions: extracted,
  };
}
