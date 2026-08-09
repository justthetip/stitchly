import Foundation

enum PatternHubSection: String, CaseIterable, Identifiable {
    case marketplace = "Marketplace"
    case owned = "My Patterns"

    var id: Self { self }
}

enum MarketplacePrice: Hashable, Sendable {
    case free
    case paid(pence: Int)

    var displayName: String {
        switch self {
        case .free:
            return "Free"
        case .paid(let pence):
            return String(format: "£%.2f", Double(pence) / 100)
        }
    }

    var acquisitionTitle: String {
        switch self {
        case .free: return "Get free pattern"
        case .paid: return "Add · \(displayName)"
        }
    }
}

struct MarketplacePatternListing: Identifiable, Hashable, Sendable {
    let pattern: Pattern
    let price: MarketplacePrice
    let summary: String
    let symbol: String
    let featured: Bool

    var id: String { pattern.id }
}

enum PatternMarketplaceCatalog {
    static let listings: [MarketplacePatternListing] = [
        listing(
            id: "market-sunburst-tote", name: "Sunburst Market Tote", designer: "Mara & Loop",
            craft: "Crochet", difficulty: "Confident beginner", yarn: "DK cotton", tool: "4 mm hook",
            steps: 28, price: .paid(pence: 499), summary: "A roomy colour-block tote worked from a sturdy circular base.",
            symbol: "basket.fill", featured: true
        ),
        listing(
            id: "market-cloudline-cardigan", name: "Cloudline Cardigan", designer: "North Thread Studio",
            craft: "Knit", difficulty: "Intermediate", yarn: "Light worsted wool", tool: "5 mm needles",
            steps: 46, price: .paid(pence: 750), summary: "A relaxed top-down layer with tidy raglan shaping and generous pockets.",
            symbol: "tshirt.fill", featured: true
        ),
        listing(
            id: "market-mini-whale", name: "Pocket-Sized Whale", designer: "Tiny Tide Makes",
            craft: "Crochet", difficulty: "Beginner", yarn: "Worsted cotton", tool: "3.5 mm hook",
            steps: 16, price: .free, summary: "A quick amigurumi friend with simple shaping and a tiny tail.",
            symbol: "water.waves", featured: false
        ),
        listing(
            id: "market-weekend-beanie", name: "Weekend Rib Beanie", designer: "Common Skein",
            craft: "Knit", difficulty: "Beginner", yarn: "Aran wool", tool: "5.5 mm needles",
            steps: 18, price: .paid(pence: 299), summary: "A warm, stretchy hat designed for an easy one-weekend make.",
            symbol: "snowflake", featured: false
        ),
        listing(
            id: "market-granny-basics", name: "Granny Square Basics", designer: "Stitch School",
            craft: "Crochet", difficulty: "First project", yarn: "DK yarn", tool: "4 mm hook",
            steps: 12, price: .free, summary: "Learn the classic square with clear colour-change and joining guidance.",
            symbol: "square.grid.2x2.fill", featured: false
        ),
        listing(
            id: "market-strawberry-blanket", name: "Strawberry Picnic Blanket", designer: "Berry Good Yarn",
            craft: "Crochet", difficulty: "Intermediate", yarn: "Cotton blend", tool: "4.5 mm hook",
            steps: 52, price: .paid(pence: 599), summary: "Cheerful berry motifs joined into a soft summer picnic blanket.",
            symbol: "leaf.fill", featured: true
        ),
        listing(
            id: "market-woodland-fox", name: "Woodland Fox", designer: "Fern & Fibre",
            craft: "Crochet", difficulty: "Improver", yarn: "Sport-weight cotton", tool: "3 mm hook",
            steps: 34, price: .paid(pence: 449), summary: "A bright woodland companion with a curled tail and embroidered details.",
            symbol: "pawprint.fill", featured: false
        ),
        listing(
            id: "market-coastal-socks", name: "Coastal Walking Socks", designer: "Harbour Knits",
            craft: "Knit", difficulty: "Intermediate", yarn: "4-ply sock yarn", tool: "2.5 mm needles",
            steps: 40, price: .paid(pence: 625), summary: "Comfortable cuff-down socks with a wave-texture leg and reinforced heel.",
            symbol: "figure.walk", featured: false
        )
    ]

    static func listing(for patternID: String) -> MarketplacePatternListing? {
        listings.first { $0.id == patternID }
    }

    static func instructions(for patternID: String) -> [Instruction]? {
        guard let listing = listing(for: patternID) else { return nil }
        let isCrochet = listing.pattern.craft.caseInsensitiveCompare("Crochet") == .orderedSame
        let kind = isCrochet ? "round" : "row"
        let labels = isCrochet ? ["Setup", "Round 1", "Shape", "Finish"] : ["Cast on", "Rows 1–4", "Shape", "Finish"]
        let copy = isCrochet
            ? [
                "Make a slip knot and work the foundation described for your chosen size.",
                "Work evenly around, placing a marker at the start and checking the stitch count before continuing.",
                "Follow the increase and decrease sequence, keeping the shaping points aligned.",
                "Fasten off securely, weave in every end, and block gently to the finished measurements."
            ]
            : [
                "Cast on the stitches for your chosen size and distribute them evenly before joining or turning.",
                "Work the established stitch pattern, checking gauge and finished width as you go.",
                "Follow the increase and decrease sequence, keeping paired shaping points aligned.",
                "Bind off with an even tension, weave in every end, and block to the finished measurements."
            ]
        return labels.enumerated().map { index, label in
            Instruction(
                id: "\(patternID)-preview-\(index + 1)", position: index + 1,
                section: index == 3 ? "Finishing" : "Main pattern", instructionKind: index == 0 ? "setup" : kind,
                sourceLabel: label, instructions: copy[index], notes: index == 1 ? "Marketplace preview instructions" : nil,
                stitchCount: nil, optional: false, confidence: "high", instructionNumber: index + 1
            )
        }
    }

    private static func listing(
        id: String, name: String, designer: String, craft: String, difficulty: String,
        yarn: String, tool: String, steps: Int, price: MarketplacePrice, summary: String,
        symbol: String, featured: Bool
    ) -> MarketplacePatternListing {
        MarketplacePatternListing(
            pattern: Pattern(
                id: id, name: name, designer: designer, craft: craft, difficulty: difficulty,
                yarn: yarn, tool: tool, totalInstructions: steps, source: "marketplace-preview", pageCount: nil
            ),
            price: price, summary: summary, symbol: symbol, featured: featured
        )
    }
}

@MainActor enum PatternMarketplaceOwnership {
    private static let keyPrefix = "marketplace-owned-patterns-v1"

    static func acquiredIDs(for identity: String, defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key(for: identity)) ?? [])
    }

    static func acquiredPatterns(for identity: String, defaults: UserDefaults = .standard) -> [Pattern] {
        let ids = acquiredIDs(for: identity, defaults: defaults)
        return PatternMarketplaceCatalog.listings.filter { ids.contains($0.id) }.map(\.pattern)
    }

    @discardableResult
    static func acquire(_ patternID: String, for identity: String, defaults: UserDefaults = .standard) -> Bool {
        guard PatternMarketplaceCatalog.listing(for: patternID) != nil else { return false }
        var ids = acquiredIDs(for: identity, defaults: defaults)
        let inserted = ids.insert(patternID).inserted
        defaults.set(ids.sorted(), forKey: key(for: identity))
        return inserted
    }

    static func remove(_ patternID: String, for identity: String, defaults: UserDefaults = .standard) {
        var ids = acquiredIDs(for: identity, defaults: defaults)
        ids.remove(patternID)
        defaults.set(ids.sorted(), forKey: key(for: identity))
    }

    static func reset(for identity: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(for: identity))
    }

    private static func key(for identity: String) -> String {
        let safeIdentity = identity.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "guest"
        return "\(keyPrefix)-\(safeIdentity)"
    }
}

enum PatternCollectionMerging {
    static func merge(primary: [Pattern], acquired: [Pattern]) -> [Pattern] {
        var seen = Set<String>()
        return (primary + acquired).filter { seen.insert($0.id).inserted }
    }
}
