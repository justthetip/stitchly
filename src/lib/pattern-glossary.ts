export type PatternGlossaryTerm = {
  id: string;
  shorthand: string;
  name: string;
  definition: string;
  aliases?: string[];
};

export type PatternGlossarySegment = {
  text: string;
  term?: PatternGlossaryTerm;
};

export const patternGlossary: PatternGlossaryTerm[] = [
  { id: "mr", shorthand: "mr", name: "Magic ring", definition: "Make an adjustable loop and work the stated number of stitches into it. In a compact form such as mr6, the number is the stitch count worked into the ring.", aliases: ["magic ring"] },
  { id: "csdc", shorthand: "CSDC", name: "Chainless starting double crochet", definition: "A standing-style double crochet used at the start of a round instead of a turning chain." },
  { id: "cssc", shorthand: "CSSC", name: "Chainless starting single crochet", definition: "A standing-style single crochet used at the start of a round instead of a turning chain." },
  { id: "sl-st", shorthand: "sl st", name: "Slip stitch", definition: "Insert the hook, yarn over, and pull through the stitch and the loop already on the hook in one motion.", aliases: ["slst"] },
  { id: "sc2tog", shorthand: "sc2tog", name: "Single crochet two together", definition: "Work two single crochet stitches together to decrease by one stitch." },
  { id: "dc2tog", shorthand: "dc2tog", name: "Double crochet two together", definition: "Work two double crochet stitches together to decrease by one stitch." },
  { id: "hdc", shorthand: "hdc", name: "Half double crochet", definition: "Yarn over, insert the hook, pull up a loop, then yarn over and pull through all three loops." },
  { id: "dtr", shorthand: "dtr", name: "Double treble crochet", definition: "A tall crochet stitch made with three yarn overs before inserting the hook." },
  { id: "dc", shorthand: "dc", name: "Double crochet", definition: "Yarn over, insert the hook and pull up a loop, then complete the stitch by pulling through two loops twice." },
  { id: "tr", shorthand: "tr", name: "Treble crochet", definition: "A tall crochet stitch made with two yarn overs before inserting the hook." },
  { id: "sc", shorthand: "sc", name: "Single crochet", definition: "Insert the hook, yarn over and pull up a loop, then yarn over and pull through both loops." },
  { id: "ch", shorthand: "ch", name: "Chain", definition: "Yarn over and pull through the loop on the hook to make one chain stitch." },
  { id: "sp", shorthand: "sp", name: "Space", definition: "Work into the indicated gap or chain space rather than into a stitch." },
  { id: "sk", shorthand: "sk", name: "Skip", definition: "Leave the stated stitch or space unworked and continue at the next indicated point." },
  { id: "ea", shorthand: "ea", name: "Each", definition: "Work the instruction in every indicated stitch or space." },
  { id: "nxt", shorthand: "nxt", name: "Next", definition: "Work into the next stitch, space, or group described by the pattern." },
  { id: "rnd", shorthand: "rnd", name: "Round", definition: "One complete circuit of circular crochet or knitting." },
  { id: "beg", shorthand: "beg", name: "Beginning", definition: "The start of the row, round, or instruction." },
  { id: "fo", shorthand: "F/o", name: "Fasten off", definition: "Cut the yarn, pull the tail through the final loop, and secure it." },
  { id: "k2tog", shorthand: "k2tog", name: "Knit two together", definition: "Knit the next two stitches together as one, decreasing one stitch." },
  { id: "p2tog", shorthand: "p2tog", name: "Purl two together", definition: "Purl the next two stitches together as one, decreasing one stitch." },
  { id: "ssk", shorthand: "ssk", name: "Slip, slip, knit", definition: "Slip two stitches knitwise one at a time, then knit them together through the back loops; a left-leaning decrease." },
  { id: "kfb", shorthand: "kfb", name: "Knit front and back", definition: "Knit into the front and then the back of the same stitch to increase by one stitch." },
  { id: "yo", shorthand: "yo", name: "Yarn over", definition: "Wrap the yarn over the needle to create a new stitch and usually an eyelet." },
  { id: "w-and-t", shorthand: "w&t", name: "Wrap and turn", definition: "Wrap the working yarn around the next stitch and turn the work to shape with a short row.", aliases: ["w & t"] },
  { id: "sl", shorthand: "sl", name: "Slip", definition: "Move the stated stitch from one needle to the other without working it." },
  { id: "wyif", shorthand: "wyif", name: "With yarn in front", definition: "Hold the working yarn at the front of the work while completing the stated action." },
  { id: "uls", shorthand: "uls", name: "Under lifted strand", definition: "Work under the lifted strand specified by this pattern's stitch technique." },
  { id: "st-st", shorthand: "st st", name: "Stocking stitch", definition: "Alternate knit and purl rows when working flat; knit every round when working in the round.", aliases: ["stockinette stitch"] },
  { id: "sts", shorthand: "sts", name: "Stitches", definition: "More than one stitch." },
  { id: "st", shorthand: "st", name: "Stitch", definition: "One loop or unit of knitting or crochet." },
  { id: "k", shorthand: "k", name: "Knit", definition: "Work a knit stitch. A following number gives the number of stitches, so k3 means knit three." },
  { id: "p", shorthand: "p", name: "Purl", definition: "Work a purl stitch. A following number gives the number of stitches, so p3 means purl three." },
  { id: "rep", shorthand: "rep", name: "Repeat", definition: "Work the stated instruction or range again." },
  { id: "rem", shorthand: "rem", name: "Remaining", definition: "The stitches or work still left after the preceding action." },
  { id: "foll", shorthand: "foll", name: "Following", definition: "The next row, round, stitch, or instruction described." },
  { id: "inc", shorthand: "inc", name: "Increase", definition: "Add one or more stitches using the method specified by the pattern." },
  { id: "dec", shorthand: "dec", name: "Decrease", definition: "Remove one or more stitches using the method specified by the pattern." },
  { id: "rs", shorthand: "RS", name: "Right side", definition: "The side of the work intended to face outward when finished." },
  { id: "ws", shorthand: "WS", name: "Wrong side", definition: "The side of the work intended to face inward when finished." },
  { id: "rh", shorthand: "RH", name: "Right-hand", definition: "The right-hand needle or right-hand side named by the instruction." },
  { id: "patt", shorthand: "patt", name: "Pattern", definition: "Follow the referenced pattern or stitch sequence." },
  { id: "tog", shorthand: "tog", name: "Together", definition: "Work or join the named stitches or pieces together." },
  { id: "dk", shorthand: "DK", name: "Double knitting yarn", definition: "A medium-light yarn weight; use the exact yarn and gauge information specified by the pattern." },
];

const byID = new Map(patternGlossary.map((term) => [term.id, term]));
const aliases = patternGlossary.flatMap((term) =>
  [term.shorthand, ...(term.aliases ?? [])].map((alias) => ({ alias, term })),
).sort((a, b) => b.alias.length - a.alias.length);
const escaped = aliases.map(({ alias }) => alias.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
const matcher = new RegExp(`mr\\s*\\d+|${escaped.join("|")}|[kp]\\d+`, "gi");

function canonicalTerm(matched: string): PatternGlossaryTerm | undefined {
  const normalized = matched.toLowerCase().replace(/\s+/g, " ");
  if (/^mr\s*\d+$/.test(normalized)) return byID.get("mr");
  if (/^k\d+$/.test(normalized)) return byID.get("k");
  if (/^p\d+$/.test(normalized)) return byID.get("p");
  return aliases.find(({ alias }) => alias.toLowerCase() === normalized)?.term;
}

function isLetter(value: string | undefined) {
  return value != null && /[A-Za-z]/.test(value);
}

export function glossarySegments(text: string): PatternGlossarySegment[] {
  const result: PatternGlossarySegment[] = [];
  let cursor = 0;
  matcher.lastIndex = 0;
  for (let match = matcher.exec(text); match; match = matcher.exec(text)) {
    const start = match.index;
    const end = start + match[0].length;
    if (isLetter(text[start - 1]) || isLetter(text[end])) continue;
    const term = canonicalTerm(match[0]);
    if (!term) continue;
    if (start > cursor) result.push({ text: text.slice(cursor, start) });
    result.push({ text: match[0], term });
    cursor = end;
  }
  if (cursor < text.length) result.push({ text: text.slice(cursor) });
  return result.length ? result : [{ text }];
}

export function glossaryTermsIn(instructions: string[]): PatternGlossaryTerm[] {
  const found = new Set<string>();
  for (const instruction of instructions) {
    for (const segment of glossarySegments(instruction)) {
      if (segment.term) found.add(segment.term.id);
    }
  }
  return patternGlossary.filter((term) => found.has(term.id));
}
