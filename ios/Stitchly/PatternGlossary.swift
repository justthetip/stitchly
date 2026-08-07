import Foundation
import SwiftUI

struct PatternGlossaryTerm: Identifiable, Hashable, Sendable {
    let id: String
    let shorthand: String
    let name: String
    let definition: String
    var aliases: [String] = []
}

struct PatternGlossarySegment: Equatable, Sendable {
    let text: String
    let term: PatternGlossaryTerm?
}

enum PatternGlossary {
    static let terms: [PatternGlossaryTerm] = [
        .init(id: "mr", shorthand: "mr", name: "Magic ring", definition: "Make an adjustable loop and work the stated number of stitches into it. In mr6, the number means six stitches are worked into the ring.", aliases: ["magic ring"]),
        .init(id: "csdc", shorthand: "CSDC", name: "Chainless starting double crochet", definition: "A standing-style double crochet used at the start of a round instead of a turning chain."),
        .init(id: "cssc", shorthand: "CSSC", name: "Chainless starting single crochet", definition: "A standing-style single crochet used at the start of a round instead of a turning chain."),
        .init(id: "sl-st", shorthand: "sl st", name: "Slip stitch", definition: "Insert the hook, yarn over, and pull through the stitch and the loop already on the hook in one motion.", aliases: ["slst"]),
        .init(id: "sc2tog", shorthand: "sc2tog", name: "Single crochet two together", definition: "Work two single crochet stitches together to decrease by one stitch."),
        .init(id: "dc2tog", shorthand: "dc2tog", name: "Double crochet two together", definition: "Work two double crochet stitches together to decrease by one stitch."),
        .init(id: "hdc", shorthand: "hdc", name: "Half double crochet", definition: "Yarn over, insert the hook, pull up a loop, then yarn over and pull through all three loops."),
        .init(id: "dtr", shorthand: "dtr", name: "Double treble crochet", definition: "A tall crochet stitch made with three yarn overs before inserting the hook."),
        .init(id: "dc", shorthand: "dc", name: "Double crochet", definition: "Yarn over, insert the hook and pull up a loop, then pull through two loops twice."),
        .init(id: "tr", shorthand: "tr", name: "Treble crochet", definition: "A tall crochet stitch made with two yarn overs before inserting the hook."),
        .init(id: "sc", shorthand: "sc", name: "Single crochet", definition: "Insert the hook, yarn over and pull up a loop, then yarn over and pull through both loops."),
        .init(id: "ch", shorthand: "ch", name: "Chain", definition: "Yarn over and pull through the loop on the hook to make one chain stitch."),
        .init(id: "sp", shorthand: "sp", name: "Space", definition: "Work into the indicated gap or chain space rather than into a stitch."),
        .init(id: "sk", shorthand: "sk", name: "Skip", definition: "Leave the stated stitch or space unworked and continue at the next indicated point."),
        .init(id: "ea", shorthand: "ea", name: "Each", definition: "Work the instruction in every indicated stitch or space."),
        .init(id: "nxt", shorthand: "nxt", name: "Next", definition: "Work into the next stitch, space, or group described by the pattern."),
        .init(id: "rnd", shorthand: "rnd", name: "Round", definition: "One complete circuit of circular crochet or knitting."),
        .init(id: "beg", shorthand: "beg", name: "Beginning", definition: "The start of the row, round, or instruction."),
        .init(id: "fo", shorthand: "F/o", name: "Fasten off", definition: "Cut the yarn, pull the tail through the final loop, and secure it."),
        .init(id: "k2tog", shorthand: "k2tog", name: "Knit two together", definition: "Knit the next two stitches together as one, decreasing one stitch."),
        .init(id: "p2tog", shorthand: "p2tog", name: "Purl two together", definition: "Purl the next two stitches together as one, decreasing one stitch."),
        .init(id: "ssk", shorthand: "ssk", name: "Slip, slip, knit", definition: "Slip two stitches knitwise, then knit them together through the back loops; a left-leaning decrease."),
        .init(id: "kfb", shorthand: "kfb", name: "Knit front and back", definition: "Knit into the front and back of the same stitch to increase by one."),
        .init(id: "yo", shorthand: "yo", name: "Yarn over", definition: "Wrap the yarn over the needle to create a new stitch and usually an eyelet."),
        .init(id: "w-and-t", shorthand: "w&t", name: "Wrap and turn", definition: "Wrap the working yarn around the next stitch and turn the work to shape with a short row.", aliases: ["w & t"]),
        .init(id: "sl", shorthand: "sl", name: "Slip", definition: "Move the stated stitch from one needle to the other without working it."),
        .init(id: "wyif", shorthand: "wyif", name: "With yarn in front", definition: "Hold the working yarn at the front while completing the stated action."),
        .init(id: "uls", shorthand: "uls", name: "Under lifted strand", definition: "Work under the lifted strand specified by this pattern's stitch technique."),
        .init(id: "st-st", shorthand: "st st", name: "Stocking stitch", definition: "Alternate knit and purl rows when working flat; knit every round when working in the round.", aliases: ["stockinette stitch"]),
        .init(id: "sts", shorthand: "sts", name: "Stitches", definition: "More than one stitch."),
        .init(id: "st", shorthand: "st", name: "Stitch", definition: "One loop or unit of knitting or crochet."),
        .init(id: "k", shorthand: "k", name: "Knit", definition: "Work a knit stitch. A following number gives the count, so k3 means knit three."),
        .init(id: "p", shorthand: "p", name: "Purl", definition: "Work a purl stitch. A following number gives the count, so p3 means purl three."),
        .init(id: "rep", shorthand: "rep", name: "Repeat", definition: "Work the stated instruction or range again."),
        .init(id: "rem", shorthand: "rem", name: "Remaining", definition: "The stitches or work still left after the preceding action."),
        .init(id: "foll", shorthand: "foll", name: "Following", definition: "The next row, round, stitch, or instruction described."),
        .init(id: "inc", shorthand: "inc", name: "Increase", definition: "Add one or more stitches using the method specified by the pattern."),
        .init(id: "dec", shorthand: "dec", name: "Decrease", definition: "Remove one or more stitches using the method specified by the pattern."),
        .init(id: "rs", shorthand: "RS", name: "Right side", definition: "The side intended to face outward when finished."),
        .init(id: "ws", shorthand: "WS", name: "Wrong side", definition: "The side intended to face inward when finished."),
        .init(id: "rh", shorthand: "RH", name: "Right-hand", definition: "The right-hand needle or right-hand side named by the instruction."),
        .init(id: "patt", shorthand: "patt", name: "Pattern", definition: "Follow the referenced pattern or stitch sequence."),
        .init(id: "tog", shorthand: "tog", name: "Together", definition: "Work or join the named stitches or pieces together."),
        .init(id: "dk", shorthand: "DK", name: "Double knitting yarn", definition: "A medium-light yarn weight; use the exact yarn and gauge information specified by the pattern.")
    ]

    private static let aliases: [(String, PatternGlossaryTerm)] = terms.flatMap { term in
        ([term.shorthand] + term.aliases).map { ($0, term) }
    }.sorted { $0.0.count > $1.0.count }

    private static let matcher: NSRegularExpression = {
        let escaped = aliases.map { NSRegularExpression.escapedPattern(for: $0.0) }
        return try! NSRegularExpression(pattern: "mr\\s*\\d+|" + escaped.joined(separator: "|") + "|[kp]\\d+", options: [.caseInsensitive])
    }()

    static func segments(in text: String) -> [PatternGlossarySegment] {
        let source = text as NSString
        let matches = matcher.matches(in: text, range: NSRange(location: 0, length: source.length))
        var result: [PatternGlossarySegment] = []
        var cursor = 0
        for match in matches {
            let start = match.range.location
            let end = NSMaxRange(match.range)
            guard !isLetter(source, at: start - 1), !isLetter(source, at: end), let term = canonicalTerm(for: source.substring(with: match.range)) else { continue }
            if start > cursor { result.append(.init(text: source.substring(with: NSRange(location: cursor, length: start - cursor)), term: nil)) }
            result.append(.init(text: source.substring(with: match.range), term: term))
            cursor = end
        }
        if cursor < source.length { result.append(.init(text: source.substring(from: cursor), term: nil)) }
        return result.isEmpty ? [.init(text: text, term: nil)] : result
    }

    static func terms(in instructions: [Instruction]) -> [PatternGlossaryTerm] {
        let found = Set(instructions.flatMap { segments(in: $0.instructions).compactMap(\.term?.id) })
        return terms.filter { found.contains($0.id) }
    }

    static func attributed(_ text: String) -> AttributedString {
        segments(in: text).reduce(into: AttributedString()) { result, segment in
            var part = AttributedString(segment.text)
            if let term = segment.term {
                part.link = URL(string: "stitchly-glossary://\(term.id)")
                part.foregroundColor = .brandPink
                part.underlineStyle = .single
            }
            result.append(part)
        }
    }

    static func term(id: String) -> PatternGlossaryTerm? { terms.first { $0.id == id } }

    private static func canonicalTerm(for match: String) -> PatternGlossaryTerm? {
        let normalized = match.lowercased().replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if normalized.range(of: #"^mr\s*\d+$"#, options: .regularExpression) != nil { return term(id: "mr") }
        if normalized.range(of: #"^k\d+$"#, options: .regularExpression) != nil { return term(id: "k") }
        if normalized.range(of: #"^p\d+$"#, options: .regularExpression) != nil { return term(id: "p") }
        return aliases.first { $0.0.lowercased() == normalized }?.1
    }

    private static func isLetter(_ text: NSString, at index: Int) -> Bool {
        guard index >= 0, index < text.length else { return false }
        return CharacterSet.letters.contains(UnicodeScalar(text.character(at: index))!)
    }
}

struct GlossaryInstructionText: View {
    let text: String
    let onSelect: (PatternGlossaryTerm) -> Void
    var body: some View {
        Text(PatternGlossary.attributed(text))
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "stitchly-glossary", let id = url.host, let term = PatternGlossary.term(id: id) else { return .systemAction }
                onSelect(term)
                return .handled
            })
    }
}

struct GlossaryTermSheet: View {
    @Environment(\.dismiss) private var dismiss
    let term: PatternGlossaryTerm
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Label("Pattern glossary", systemImage: "book.closed")
                    .font(.subheadline.weight(.bold)).foregroundStyle(Color.brandPink)
                Text(term.shorthand).font(.largeTitle.bold()).foregroundStyle(Color.ink)
                Text(term.name).font(.title3.weight(.semibold))
                Text(term.definition).font(.body).foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(24)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
