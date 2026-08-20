import Foundation

enum PatternHubSection: String, CaseIterable, Identifiable {
    case marketplace = "Marketplace"
    case owned = "My Patterns"

    var id: Self { self }
}

struct MarketplacePatternListing: Identifiable, Hashable, Sendable {
    let pattern: Pattern
    let summary: String

    var id: String { pattern.id }
}

enum PatternMarketplaceCatalog {
    static let listings: [MarketplacePatternListing] = [
        listing(
            patternID: "demo-mini-whale",
            summary: "Make a pocket-sized amigurumi whale from the complete two-page PDF."
        ),
        listing(
            patternID: "demo-perfect-granny-square",
            summary: "Learn a classic granny square from the complete six-page PDF pattern."
        )
    ]

    static func listing(for patternID: String) -> MarketplacePatternListing? {
        listings.first { $0.id == patternID }
    }

    private static func listing(patternID: String, summary: String) -> MarketplacePatternListing {
        guard let pattern = DemoData.patterns.first(where: { $0.id == patternID }) else {
            fatalError("Marketplace pattern \(patternID) is missing from the bundled catalog.")
        }
        return MarketplacePatternListing(pattern: pattern, summary: summary)
    }
}

@MainActor enum PatternMarketplaceOwnership {
    private static let keyPrefix = "marketplace-owned-patterns-v2"

    static func acquiredPatternIDs(for identity: String, defaults: UserDefaults = .standard) -> [String: String] {
        guard let data = defaults.data(forKey: key(for: identity)),
              let value = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return value
    }

    static func patternID(for listingID: String, identity: String, defaults: UserDefaults = .standard) -> String? {
        acquiredPatternIDs(for: identity, defaults: defaults)[listingID]
    }

    static func listingID(for patternID: String, identity: String, defaults: UserDefaults = .standard) -> String? {
        acquiredPatternIDs(for: identity, defaults: defaults).first { $0.value == patternID }?.key
    }

    static func acquiredListingIDs(for identity: String, availablePatternIDs: Set<String>, defaults: UserDefaults = .standard) -> Set<String> {
        Set(acquiredPatternIDs(for: identity, defaults: defaults).compactMap { listingID, patternID in
            availablePatternIDs.contains(patternID) ? listingID : nil
        })
    }

    static func acquiredPatterns(for identity: String, defaults: UserDefaults = .standard) -> [Pattern] {
        let ids = acquiredPatternIDs(for: identity, defaults: defaults)
        return PatternMarketplaceCatalog.listings.compactMap { listing in
            ids[listing.id] == listing.id ? listing.pattern : nil
        }
    }

    static func record(listingID: String, patternID: String, for identity: String, defaults: UserDefaults = .standard) {
        guard PatternMarketplaceCatalog.listing(for: listingID) != nil else { return }
        var ids = acquiredPatternIDs(for: identity, defaults: defaults)
        ids[listingID] = patternID
        if let data = try? JSONEncoder().encode(ids) { defaults.set(data, forKey: key(for: identity)) }
    }

    static func removeListing(_ listingID: String, for identity: String, defaults: UserDefaults = .standard) {
        var ids = acquiredPatternIDs(for: identity, defaults: defaults)
        ids.removeValue(forKey: listingID)
        if let data = try? JSONEncoder().encode(ids) { defaults.set(data, forKey: key(for: identity)) }
    }

    static func removePattern(_ patternID: String, for identity: String, defaults: UserDefaults = .standard) {
        guard let listingID = listingID(for: patternID, identity: identity, defaults: defaults) else { return }
        removeListing(listingID, for: identity, defaults: defaults)
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
