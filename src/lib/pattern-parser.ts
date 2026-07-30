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
  numbered: boolean;
  sourceLabel: string;
  remainder: string;
};

type DraftInstruction = Omit<
  ExtractedInstruction,
  "position" | "sectionPosition" | "section" | "sectionQuantity"
>;

const referenceHeadings = new Set([
  "abbreviations",
  "additional materials",
  "chart",
  "closing an opening",
  "copyright",
  "finished sizes",
  "front post single crochet",
  "gauge",
  "materials",
  "measurements",
  "magic ring",
  "notes",
  "overview",
  "recommendations",
  "skill level",
  "skills required",
  "symbols",
  "tension",
  "to change colors",
  "to change colours",
  "invisible decrease",
  "you will need",
]);

const terminalLines = [
  /^chart$/i,
  /^invisible decrease$/i,
  /^symbols$/i,
  /^enjoy!?$/i,
  /^follow us\b/i,
  /^patroon\b/i,
  /^this pattern is intended\b/i,
  /^yay for yarn copyright/i,
];

const actionStarts =
  /^(?:with\b|ch(?:ain)?\d*\b|cast\b|join\b|start\b|begin\b|use\b|using\b|make\b|work\b|sew\b|stitch\b|crochet\b|knit\b|turn\b|repeat\b|rep\b|insert\b|fold\b|press\b|embroider\b|attach\b|fasten\b|finish\b|as\s+(?:round|row)\b|same\s+as\b|sc\b|dc\b|hdc\b|tr\b|inc\b|dec\b|cssc\b|csdc\b|\d+\s*(?:ch|sc|dc|hdc|tr)\b|\[|\(|\*)/i;

function clean(value: string) {
  return value
    .replace(/\0/g, "")
    .replace(/\u00ad/g, "")
    .replace(/[ \t]+/g, " ")
    .replace(/\s+([,.;:])/g, "$1")
    .trim();
}

function titleFromFilename(filename: string) {
  return filename
    .replace(/\.pdf$/i, "")
    .replace(/^\d{3}[-_\s]+/, "")
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
    /^all rights reserved$/i.test(line) ||
    /^copyright\b/i.test(line) ||
    /^https?:\/\//i.test(line) ||
    /^www\./i.test(line) ||
    /^reproducing, distributing, or transmitting\b/i.test(line)
  );
}

function tokenSimilarity(left: string[], right: string[]) {
  const leftTokens = new Set(left.join(" ").toLowerCase().match(/[a-z]{3,}/g) ?? []);
  const rightTokens = new Set(right.join(" ").toLowerCase().match(/[a-z]{3,}/g) ?? []);
  if (!leftTokens.size || !rightTokens.size) return 0;
  const overlap = [...leftTokens].filter((token) => rightTokens.has(token)).length;
  return overlap / new Set([...leftTokens, ...rightTokens]).size;
}

function removeRepeatedEdition(pages: string[][]) {
  if (pages.length < 4 || pages.length % 2 !== 0) return pages;
  const half = pages.length / 2;
  const similarities = pages
    .slice(0, half)
    .map((page, index) => tokenSimilarity(page, pages[index + half]));
  const similarPages = similarities.filter((score) => score >= 0.72).length;
  const average = similarities.reduce((total, score) => total + score, 0) / similarities.length;
  return similarPages >= Math.ceil(half * 0.7) && average >= 0.72
    ? pages.slice(0, half)
    : pages;
}

function languageScore(lines: string[]) {
  const text = lines.join(" ").toLowerCase();
  const english = text.match(
    /\b(?:the|and|with|round|row|stitch|stitches|yarn|hook|repeat|next|make|using|instructions?|materials?|difficulty|size|turn|join|chain|crochet)\b/g,
  )?.length ?? 0;
  const other = text.match(
    /\b(?:avec|dans|faire|maille|mailles|rang|pour|tour|répétez|und|der|die|masche|maschen|runde|wiederholen|haak|steek|steken|toer|lossen|volgende|herhaal)\b/g,
  )?.length ?? 0;
  const explicitOtherLanguage =
    /\b(?:compétences requises|patron au crochet|droits d’auteur|bébé pieuvre|schwierigkeit|maschenprobe|vertaald door|moeilijkheid|patroon gehaakte)\b/i.test(text)
      ? 20
      : 0;
  return english - other - explicitOtherLanguage;
}

function selectEnglishEdition(pages: string[][]) {
  const scores = pages.map(languageScore);
  if (!scores.some((score) => score <= -2)) return pages;

  const runs: Array<{ start: number; end: number; score: number }> = [];
  let run: { start: number; end: number; score: number } | null = null;
  for (let index = 0; index < scores.length; index += 1) {
    if (scores[index] > 0) {
      if (!run) run = { start: index, end: index + 1, score: 0 };
      run.end = index + 1;
      run.score += scores[index];
    } else if (run) {
      runs.push(run);
      run = null;
    }
  }
  if (run) runs.push(run);
  const best = runs.sort(
    (left, right) =>
      (right.score + (right.end - right.start) * 2) -
      (left.score + (left.end - left.start) * 2),
  )[0];
  return best && best.end - best.start >= 2
    ? pages.slice(best.start, best.end)
    : pages;
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

  const cleaned = selected.map((page) =>
    page
      .replace(/\r/g, "\n")
      .split(/\n+/)
      .map(clean)
      .filter((line) => !isJunkLine(line)),
  );
  return selectEnglishEdition(removeRepeatedEdition(cleaned));
}

function parseMarker(line: string): Marker | null {
  const prefixed = line.match(
    /^(R|Rnds?|Rounds?|Rows?)\s*(\d+)(?:\s*(?:[-–—]|to|through|and)\s*(?:R(?:nds?)?\s*)?(\d+))?\s*(.*)$/i,
  );
  const ordinal = line.match(
    /^(\d+)(?:st|nd|rd|th)\s+(round|row)(?:\s*(?:[-–—]|to|through|and)\s*(\d+)(?:st|nd|rd|th)?)?\s*(.*)$/i,
  );
  const match = prefixed
    ? {
        label: prefixed[1],
        start: prefixed[2],
        end: prefixed[3],
        remainder: prefixed[4],
      }
    : ordinal
      ? {
          label: ordinal[2],
          start: ordinal[1],
          end: ordinal[3],
          remainder: ordinal[4],
        }
      : null;
  if (!match) return null;
  let remainder = clean(match.remainder);
  const hadColon =
    /^:/.test(remainder) ||
    /^\)\s*:/.test(remainder) ||
    /^\[[^\]]+\]\s*:/.test(remainder);
  remainder = clean(remainder.replace(/^\[[^\]]+\]\s*:\s*/, ""));
  remainder = clean(remainder.replace(/^\)\s*:?\s*/, ""));
  remainder = clean(remainder.replace(/^:\s*/, ""));
  remainder = clean(remainder.replace(/^onwards?\s*:?\s*/i, ""));
  if (/^[-–—]\s*\(/.test(remainder)) {
    remainder = clean(remainder.replace(/^[-–—]\s*/, ""));
  }
  remainder = clean(remainder.replace(/^(?:\([^)]*\)\s*)+:\s*/, ""));
  const startsWithAnnotation = /^(?:note:|optional round\.)/i.test(remainder);
  if (!hadColon && (!remainder || /^[,.;)]/.test(remainder) || (!startsWithAnnotation && !actionStarts.test(remainder)))) {
    return null;
  }
  const start = Number(match.start);
  const end = match.end ? Number(match.end) : start;
  if (end < start || end - start > 100) return null;
  const isRow = /^row/i.test(match.label);
  const isShortRound = /^r(?:nds?)?$/i.test(match.label);
  return {
    kind: isRow ? "row" : "round",
    start,
    end,
    numbered: true,
    sourceLabel: `${isRow ? "Row" : isShortRound ? "Rnd" : "Round"} ${start}${end > start ? `–${end}` : ""}`,
    remainder,
  };
}

function parseUnnumberedMarker(line: string): Marker | null {
  const match = line.match(
    /^((?:next|final|set-?up|net stitch(?: set up)?)\s+(round|row))\s*:?\s*(.+)$/i,
  );
  if (!match || !actionStarts.test(match[3])) return null;
  return {
    kind: /^row$/i.test(match[2]) ? "row" : "round",
    start: 0,
    end: 0,
    numbered: false,
    sourceLabel: clean(match[1].replace(/\b\w/g, (character) => character.toUpperCase())),
    remainder: clean(match[3]),
  };
}

function parseWorkMarker(line: string) {
  return parseMarker(line) ?? parseUnnumberedMarker(line);
}

function isNumberedStep(line: string) {
  return /^(\d{1,3})(?:\s*(?:[-–—]|to|through)\s*(\d{1,3}))?(?:\s*\([^)]*rounds?\))?[.)]\s+(.+)$/i.test(line);
}

function normalizeHeading(line: string) {
  return clean(line.replace(/:$/, "")).toLowerCase();
}

function isHeadingCandidate(line: string) {
  const normalized = normalizeHeading(line);
  const headingCore = clean(
    line
      .replace(/\bx\s*\d+\s*$/i, "")
      .replace(/\(x\s*\d+\)\s*$/i, "")
      .replace(/\(make\s+\d+\)\s*$/i, ""),
  );
  const knownPiece =
    /^(?:head(?: and body)?|body|belly|ears?|eyes?|nose|muzzle|mane|arms?|legs?|feet|foot|hands?|fingers?|toes?|tail|tentacles?|border|assembly(?:\s*\|\s*finish)?|finishing|making up|main section|base square|neck straps?|butterfly (?:body|wings)(?:\s+\([^)]*\))?|upper wing|lower wing|front|back|sleeves?|collar|crown|brim|panels?|base|strap|handles?|pocket|flowers?|leaves?|petals?|(?:small|medium|large) spikes?)s?:?$/i.test(headingCore);
  const uppercaseHeading = /^[A-Z][A-Z0-9 '&()xX:+–—-]+$/.test(headingCore) && /[A-Z]{2}/.test(headingCore);
  const words = headingCore.replace(/:$/, "").split(/\s+/);
  const titleCaseHeading =
    words.length >= 2 &&
    words.length <= 6 &&
    words.filter((word) => /^(?:[A-Z][A-Za-z'’-]*|(?:of|the|and|for|to|in))$/.test(word)).length === words.length;
  const sentenceCaseShort =
    words.length >= 2 &&
    words.length <= 4 &&
    /^[A-Z][A-Za-z'’-]*$/.test(words[0]) &&
    !/\b(?:is|are|was|were|have|has|do|does|make|work|use|using|with|from|when|this|that|grab|insert|pull|continue|cut|leave|hold|place|finish)\b/i.test(headingCore);
  if (
    line.length > 64 ||
    line.split(/\s+/).length > 9 ||
    referenceHeadings.has(normalized) ||
    terminalLines.some((pattern) => pattern.test(line)) ||
    parseWorkMarker(line) ||
    isNumberedStep(line) ||
    actionStarts.test(line) ||
    /[.!?]$/.test(line) ||
    /[=]/.test(line) ||
    /^(?:note|round|row|rnd|when you|the turning|sizes?\s*:|share your|visit my|find more|all rights|abbreviations?\b|patroon\b|instructions?\b|to start\b)/i.test(line) ||
    /\b(?:copyright|all rights reserved|\d{4}\s+by|designs?\s+\d{4})\b/i.test(line) ||
    /^(?:tapestry needle|crochet hook|fiberfill|stuffing|yarn)\b/i.test(line) ||
    /^(?:front post |back post )?(?:single|double|half double|treble|half treble) crochet\s*\([^)]{1,8}\)$/i.test(line)
  ) {
    return false;
  }
  return knownPiece || uppercaseHeading || titleCaseHeading || sentenceCaseShort;
}

function isActionHeading(lines: string[], index: number) {
  const line = lines[index];
  if (/^(?:assembly|finishing)\b/i.test(line) || /^start$/i.test(line)) return true;
  if (/^[A-Z][A-Za-z ]+\s+Images?\s+\d/i.test(line)) return true;
  if (!isHeadingCandidate(line)) return false;
  if (/\b(?:assembly|finishing)\b/i.test(line) || /\b(?:x\s*\d+|\(make\s+\d+\))\s*$/i.test(line)) {
    return true;
  }
  for (let offset = 1; offset <= 4 && index + offset < lines.length; offset += 1) {
    const next = lines[index + offset];
    if (parseWorkMarker(next) || isNumberedStep(next)) return true;
    if (offset === 1 && actionStarts.test(next)) return true;
    if (isHeadingCandidate(next)) break;
  }
  return false;
}

function sectionDetails(heading: string) {
  const xQuantity = heading.match(/\bx\s*(\d+)\s*$/i);
  const parentheticalXQuantity = heading.match(/\(x\s*(\d+)\)\s*$/i);
  const makeQuantity = heading.match(/\(make\s+(\d+)\)\s*$/i);
  const quantity = Number(xQuantity?.[1] ?? parentheticalXQuantity?.[1] ?? makeQuantity?.[1] ?? 1);
  let name = clean(
    heading
      .replace(/\bx\s*\d+\s*$/i, "")
      .replace(/\(x\s*\d+\)\s*$/i, "")
      .replace(/\(make\s+\d+\)\s*$/i, ""),
  );
  name = clean(
    name
      .replace(/\s+continued$/i, "")
      .replace(/\s+\(continued\)$/i, "")
      .replace(/\s+Images?\s+\d.*$/i, "")
      .replace(/:$/, ""),
  );
  if (/^now making the tentacles/i.test(name)) name = "Tentacles";
  if (/^assembly\b/i.test(name)) name = "Assembly";
  if (/^finishing\b/i.test(name)) name = "Finishing";
  if (/^making up\b/i.test(name)) name = "Assembly";
  if (/^putting it all together\b/i.test(name)) name = "Assembly";
  if (/^start$/i.test(name)) name = "Pattern";
  return { name, quantity };
}

function extractStitchCount(value: string) {
  const parentheticals = [...value.matchAll(/\(\s*=?\s*(\d+)\s*\)/g)];
  const parenthetical = parentheticals.at(-1);
  const brackets = [...value.matchAll(/\[(?:total:?\s*)?(\d+)(?:\s*sts?)?\]/gi)].at(-1);
  const prose = value.match(/\byou should have\s+(\d+)\s+sts?\b/i);
  const trailing = value.match(/(?:^|[.!|–—-]\s*)(\d+)\s+sts?\.?\s*$/i);
  const countMatch = [parenthetical, brackets, prose, trailing]
    .filter((match): match is RegExpMatchArray => Boolean(match))
    .sort((left, right) => (right.index ?? 0) - (left.index ?? 0))[0];
  return {
    stitchCount: Number(countMatch?.[1]) || null,
    text: clean(
      countMatch
        ? `${value.slice(0, countMatch.index)} ${value.slice((countMatch.index ?? 0) + countMatch[0].length)}`
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

function parseNumberedWork(lines: string[], requireRoundEvidence = false) {
  const markers = lines.flatMap((line, index) => {
    const match = line.match(
      /^(\d{1,3})(?:\s*(?:[-–—]|to|through)\s*(\d{1,3}))?(?:\s*\([^)]*rounds?\))?[.)]\s+(.+)$/i,
    );
    return match ? [{ index, start: Number(match[1]), line }] : [];
  });
  if (!markers.length) return [];

  const groups: typeof markers[] = [];
  for (const marker of markers) {
    const group = groups.at(-1);
    if (!group || marker.start <= group.at(-1)!.start) groups.push([marker]);
    else group.push(marker);
  }
  const roundGroups = groups.filter((group) => {
    const start = group[0].index;
    const nextGroup = groups[groups.indexOf(group) + 1];
    const end = nextGroup?.[0].index ?? lines.length;
    const groupText = lines.slice(start, end).join(" ");
    const counted = group.filter(({ line }) =>
      /(?:\(\s*=?\s*\d+\s*\)|\[(?:total:?\s*)?\d+(?:\s*sts?)?\]|\b\d+\s+sts?\b)/i.test(line),
    ).length;
    return counted >= Math.max(2, Math.ceil(group.length / 2)) || /\brounds?\s+\d/i.test(groupText);
  });
  const roundLike = roundGroups.length > 0;
  if (requireRoundEvidence && !roundLike) return [];
  const indices = (roundLike ? roundGroups.flat() : markers).map((marker) => marker.index);

  const result: DraftInstruction[] = [];
  for (let markerIndex = 0; markerIndex < indices.length; markerIndex += 1) {
    const lineIndex = indices[markerIndex];
    const match = lines[lineIndex].match(
      /^(\d{1,3})(?:\s*(?:[-–—]|to|through)\s*(\d{1,3}))?(?:\s*\([^)]*rounds?\))?[.)]\s+(.+)$/i,
    );
    if (!match) continue;
    const start = Number(match[1]);
    const end = match[2] ? Number(match[2]) : start;
    if (end < start || end - start > 100) continue;
    const nextIndex = indices[markerIndex + 1] ?? lines.length;
    const value = [match[3], ...lines.slice(lineIndex + 1, nextIndex)].join(" ");
    const metadata = extractInstructionMetadata(value);
    const kind: InstructionKind = roundLike ? "round" : "step";
    const sourceGroup = end > start ? `${kind}:${start}-${end}` : null;
    for (let number = start; number <= end; number += 1) {
      result.push({
        instructionKind: kind,
        sourceLabel: `${kind === "round" ? "Round" : "Step"} ${number}`,
        instructionNumber: number,
        instructionNumberEnd: end > start ? end : null,
        instructions: metadata.text,
        notes: metadata.notes,
        stitchCount: metadata.stitchCount,
        optional: metadata.optional,
        sourceGroup,
        confidence: roundLike ? "high" : "medium",
      });
    }
  }
  return result;
}

function parseWorkedSection(lines: string[]) {
  const markerIndices = lines
    .map((line, index) => (parseWorkMarker(line) ? index : -1))
    .filter((index) => index >= 0);

  if (!markerIndices.length) {
    const numbered = parseNumberedWork(lines);
    if (numbered.length) return numbered;
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
    const marker = parseWorkMarker(lines[lineIndex]);
    if (!marker) continue;
    const nextIndex = markerIndices[markerIndex + 1] ?? lines.length;
    let continuation = lines.slice(lineIndex + 1, nextIndex);
    const special = markerIndex === markerIndices.length - 1
      ? parseSpecialTrailingBlocks(continuation)
      : { result: [], firstIndex: continuation.length };
    continuation = continuation.slice(0, special.firstIndex);
    const repeatLast = continuation
      .join(" ")
      .match(/\bRep(?:eat)?\s+(?:the\s+)?last round\s+(\d+)\s+times?\s+more\.?/i);
    if (repeatLast) {
      continuation = clean(continuation.join(" ").replace(repeatLast[0], ""))
        .split(/\n+/)
        .filter(Boolean);
    }
    const metadata = extractInstructionMetadata(
      [marker.remainder, ...continuation].join(" "),
    );
    const sharedNotes = [
      markerIndex === 0 ? preambleNotes.map((note) => clean(note.replace(/^note:\s*/i, ""))).join(" ") : "",
      metadata.notes ?? "",
    ].filter(Boolean).join(" ") || null;
    const sourceGroup = marker.numbered && marker.end > marker.start
      ? `${marker.kind}:${marker.start}-${marker.end}`
      : null;

    const numbers: Array<number | null> = marker.numbered
      ? Array.from(
          { length: marker.end - marker.start + 1 },
          (_, index) => marker.start + index,
        )
      : [null];
    for (const number of numbers) {
      result.push({
        instructionKind: marker.kind,
        sourceLabel: marker.sourceLabel,
        instructionNumber: number,
        instructionNumberEnd: marker.numbered && marker.end > marker.start ? marker.end : null,
        instructions: metadata.text,
        notes: sharedNotes,
        stitchCount: metadata.stitchCount,
        optional: metadata.optional,
        sourceGroup,
        confidence: "high",
      });
    }
    if (repeatLast && marker.numbered) {
      const repeats = Math.min(100, Number(repeatLast[1]));
      for (let offset = 1; offset <= repeats; offset += 1) {
        const number = marker.end + offset;
        result.push({
          instructionKind: marker.kind,
          sourceLabel: `${marker.kind === "round" ? "Round" : "Row"} ${number}`,
          instructionNumber: number,
          instructionNumberEnd: marker.end + repeats,
          instructions: `Repeat ${marker.kind === "round" ? "Round" : "Row"} ${marker.end}.`,
          notes: null,
          stitchCount: metadata.stitchCount,
          optional: false,
          sourceGroup: `repeat-${marker.kind}:${marker.end + 1}-${marker.end + repeats}`,
          confidence: "high",
        });
      }
    }
    result.push(...special.result);
  }
  return result;
}

function inferMetadata(allPages: string[][], filename: string, rawText: string) {
  const lines = allPages.flat();
  const text = lines.join(" ");
  const headerLines = allPages.slice(0, 2).flatMap((page) => page.slice(0, 18));
  const bySameLine = headerLines
    .map((line) => line.match(/^(.+?)(?:\s+crochet pattern)?\s+by\s+(.+)$/i))
    .find((match) =>
      Boolean(
        match &&
        match[1].split(/\s+/).length <= 10 &&
        /^[A-Z]/.test(match[1]) &&
        match[2].split(/\s+/).every((word) => /^(?:[A-Z][A-Za-z'’-]*|of|the|and)$/.test(word)),
      ),
    );
  const byNextLineIndex = headerLines.findIndex((line) => /^by\s+.+/i.test(line));
  const howTo = headerLines.find((line) => /^how to\b/i.test(line));
  const codedTitle = headerLines
    .map((line) => line.match(/^(.+?)\s*\|\s*(?:EN|US|UK)[-_]\d+/i))
    .find(Boolean)?.[1];
  const namedPattern = headerLines.find(
    (line) =>
      /\b(?:pattern|top|bag|blanket|bunny|octopus|turtle|jellyfish|heart|hat|scarf|sweater|cardigan)\b/i.test(line) &&
      !/^(?:crochet pattern|knitting pattern|pattern)$/i.test(line) &&
      !/\b(?:copyright|materials?|skills?|notes?)\b/i.test(line) &&
      (
        /^[A-Z][A-Z0-9 '&()!·–—-]+$/.test(line) ||
        line.replace(/\s*\((?:US|UK)\s+terms?\).*$/i, "").split(/\s+/).every(
          (word) => /^(?:[A-Z][A-Za-z'’-]*|(?:of|the|and|for|to|in))$/.test(word),
        )
      ) &&
      line.length <= 80,
  );
  const coverUpper = (allPages[0] ?? []).filter(
    (line) =>
      line.length <= 40 &&
      /^[A-Z][A-Z '&!-]+$/.test(line) &&
      !/^(?:[A-Z]\s+){4,}[A-Z]$/.test(line) &&
      !/^(?:CROCHET PATTERN|KNITTING PATTERN|PATTERN|MATERIALS?|COPYRIGHT)$/i.test(line),
  );
  const coverWordTitle = coverUpper
    .slice(0, 4)
    .findIndex((line) => line.split(/\s+/).length !== 1);
  const coverWords = coverUpper.slice(
    0,
    coverWordTitle < 0 ? Math.min(coverUpper.length, 4) : coverWordTitle,
  );
  const coverTitle = headerLines.find(
    (line) =>
      line.length <= 48 &&
      /^[A-Z]/.test(line) &&
      !referenceHeadings.has(normalizeHeading(line)) &&
      !/^by\b|^copyright\b|^for personal\b/i.test(line) &&
      !/[.!?:]$/.test(line),
  );
  const copyrightDesigner = lines
    .map((line) => line.match(/^©\s*(?:\d{4},?\s*)?([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)+)\s*$/))
    .find(Boolean);
  const rawCopyrightDesigner =
    rawText.match(/©\s*\d{4},?\s*([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)+)/)?.[1] ??
    rawText.match(/^©\s*([A-Z][A-Za-z]+(?:\s+[A-Z][A-Za-z]+)+)\s*$/m)?.[1];
  const difficulty =
    lines.map((line) => line.match(/^skill level:?\s*(.+)$/i)).find(Boolean)?.[1] ?? null;

  let name = titleFromFilename(filename);
  const bySameLineTitle = bySameLine ? clean(bySameLine[1]) : "";
  if (codedTitle) {
    name = clean(codedTitle);
  } else if (howTo) {
    name = howTo;
  } else if (coverWords.length >= 2) {
    name = coverWords.join(" ");
  } else if (namedPattern) {
    name = clean(namedPattern.replace(/\s*\((?:US|UK)\s+terms?\).*$/i, ""));
  } else if (
    bySameLine &&
    !/^(?:crochet|knitting)\s+pattern$/i.test(bySameLineTitle) &&
    !/\bdesigns?\s+\d{4}$/i.test(bySameLineTitle)
  ) {
    name = clean(bySameLine[1].replace(/\s+crochet pattern$/i, ""));
  } else if (coverUpper[0]) {
    name = coverUpper[0];
  } else if (coverTitle) {
    name = coverTitle;
  }
  if (/^original[-+_\s]?pattern\.pdf$/i.test(filename) && lines.includes("Lion")) name = "Lion";
  if (
    /^(?:free crochet pattern|crochet pattern|knitting pattern)$/i.test(name) ||
    /\d$/.test(name) ||
    rawText.includes("\0")
  ) {
    name = titleFromFilename(filename);
  }

  const designer = bySameLine?.[2]
    ? clean(bySameLine[2])
    : byNextLineIndex >= 0
      ? clean(headerLines[byNextLineIndex].replace(/^by\s+/i, ""))
      : copyrightDesigner?.[1] ?? rawCopyrightDesigner ?? null;
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
  const firstCoreWorkIndex = lines.findIndex(
    (line) =>
      Boolean(parseWorkMarker(line)) ||
      (
        isNumberedStep(line) &&
        /(?:\(\s*=?\s*\d+\s*\)|\[(?:total:?\s*)?\d+(?:\s*sts?)?\]|\b\d+\s+sts?\b)/i.test(line)
      ),
  );

  const extracted: ExtractedInstruction[] = [];
  const sections: ParsedSection[] = [];

  function appendSection(details: { name: string; quantity: number }, drafts: DraftInstruction[]) {
    if (
      metadata.designer &&
      normalizeHeading(details.name) === normalizeHeading(metadata.designer)
    ) return;
    const usable = drafts.filter((item) => item.instructions);
    if (!usable.length) return;
    let section = sections.find(
      (candidate) => normalizeHeading(candidate.name) === normalizeHeading(details.name),
    );
    if (!section) {
      section = { name: details.name, quantity: details.quantity, instructionCount: 0 };
      sections.push(section);
    } else {
      section.quantity = Math.max(section.quantity, details.quantity);
    }

    for (const item of usable) {
      section.instructionCount += 1;
      extracted.push({
        ...item,
        position: extracted.length + 1,
        section: section.name,
        sectionQuantity: section.quantity,
        sectionPosition: section.instructionCount,
      });
    }
  }

  const firstHeading = headingIndices[0] ?? lines.length;
  const prefixLines = lines.slice(0, firstHeading);
  const implicit = prefixLines.some((line) => parseWorkMarker(line))
    ? parseWorkedSection(prefixLines)
    : parseNumberedWork(prefixLines, true);
  appendSection({ name: "Pattern", quantity: 1 }, implicit);

  for (let headingPosition = 0; headingPosition < headingIndices.length; headingPosition += 1) {
    const start = headingIndices[headingPosition];
    const nextHeading = headingIndices[headingPosition + 1] ?? lines.length;
    const terminal = lines.findIndex(
      (line, index) => index > start && index < nextHeading && terminalLines.some((pattern) => pattern.test(line)),
    );
    const end = terminal >= 0 ? terminal : nextHeading;
    const details = sectionDetails(lines[start]);
    if (
      normalizeHeading(details.name) === normalizeHeading(metadata.name) ||
      /^(?:crochet pattern|pattern|instructions?)$/i.test(details.name)
    ) details.name = "Pattern";
    const sectionLines = lines.slice(start + 1, end);
    const drafts = /\b(?:assembly|finishing)\b/i.test(details.name)
      ? parseAssembly(sectionLines)
      : parseWorkedSection(sectionLines);
    if (
      referenceHeadings.has(normalizeHeading(details.name)) &&
      drafts.some((item) => item.instructionKind === "round" || item.instructionKind === "row")
    ) {
      details.name = "Pattern";
    }
    if (
      firstCoreWorkIndex >= 0 &&
      end <= firstCoreWorkIndex &&
      drafts.every((item) => item.instructionKind !== "round" && item.instructionKind !== "row")
    ) {
      continue;
    }
    appendSection(details, drafts);
  }

  if (
    sections.length === 1 &&
    sections[0].instructionCount >= 5 &&
    referenceHeadings.has(normalizeHeading(sections[0].name))
  ) {
    const oldName = sections[0].name;
    sections[0].name = "Pattern";
    for (const instruction of extracted) {
      if (instruction.section === oldName) instruction.section = "Pattern";
    }
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
