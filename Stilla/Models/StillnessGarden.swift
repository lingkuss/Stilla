import Foundation

enum GardenKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case flower, crystal, tree
    var id: String { rawValue }
    var titleKey: String { "garden.\(rawValue)s" }
    var ruleKey: String { "garden.\(rawValue).rule" }
    var interval: Int {
        switch self { case .flower: 10; case .crystal: 25; case .tree: 100 }
    }
    var symbol: String {
        switch self { case .flower: "camera.macro"; case .crystal: "diamond"; case .tree: "tree" }
    }
    var seedSalt: UInt64 {
        switch self { case .flower: 0; case .crystal: 0xC7157A1; case .tree: 0x71F37E33 }
    }
    var familyCount: Int { self == .tree ? 4 : 6 }
}

/// The saved seed is the specimen's permanent DNA.
/// Geometry is disposable; earning a flower never needs a network or an asset file.
struct GardenSpecimen: Identifiable, Hashable, Sendable {
    let sessionID: UUID
    let seed: UInt64
    let kind: GardenKind
    let ordinal: Int
    let earnedAt: Date
    var id: String { "\(sessionID.uuidString).\(kind.rawValue)" }
}

struct GardenCompletion: Codable, Equatable, Sendable {
    let sessionID: UUID
    let seed: UInt64
    let earnedAt: Date
}

struct StillnessGarden: Codable, Sendable {
    // Storage version is independent of rendering revisions. Existing completed
    // practice survives a new reward cadence or a richer geometry generator.
    static let storageVersion = 1
    var version = Self.storageVersion
    private(set) var completions: [GardenCompletion] = []

    var isValid: Bool {
        version == Self.storageVersion &&
        Set(completions.map(\.sessionID)).count == completions.count &&
        Set(completions.map(\.seed)).count == completions.count &&
        completions.allSatisfy { $0.earnedAt.timeIntervalSince1970.isFinite }
    }

    static func qualifies(reachedEnd: Bool, openEnded: Bool, elapsedSeconds: Int, sleepStory: Bool) -> Bool {
        !sleepStory && elapsedSeconds > 0 && (reachedEnd || openEnded)
    }

    @discardableResult mutating func record(sessionID: UUID, at date: Date = Date()) -> Bool {
        guard !completions.contains(where: { $0.sessionID == sessionID }), date.timeIntervalSince1970.isFinite else { return false }
        var seed = GardenDNA.seed(for: sessionID)
        // A collision is exceedingly unlikely, but uniqueness is a persisted invariant.
        let used = Set(completions.map(\.seed))
        while used.contains(seed) { seed = GardenDNA.mix(seed &+ 1) }
        completions.append(.init(sessionID: sessionID, seed: seed, earnedAt: date))
        return true
    }

    func specimens(_ kind: GardenKind) -> [GardenSpecimen] {
        var usedFamilies: Set<Int> = []
        var usedSeeds: Set<UInt64> = []
        var lastFamily: Int?
        return completions.enumerated().compactMap { index, completion in
            let number = index + 1
            guard number.isMultiple(of: kind.interval) else { return nil }
            // A personal, deterministic shuffle bag: discover every silhouette
            // before a family returns, with no immediate repeat across bags.
            // Only earlier completions influence DNA, so later practice cannot
            // change an existing specimen. All continuous traits stay individual.
            if usedFamilies.count == kind.familyCount { usedFamilies.removeAll(keepingCapacity: true) }
            var seed = kind == .flower ? completion.seed : GardenDNA.mix(completion.seed ^ kind.seedSalt)
            func family(_ value: UInt64) -> Int { Int(GardenDNA.value(value,900)*Float(kind.familyCount)) }
            while usedFamilies.contains(family(seed)) || family(seed) == lastFamily || usedSeeds.contains(seed) {
                seed = GardenDNA.mix(seed &+ 1)
            }
            usedFamilies.insert(family(seed)); usedSeeds.insert(seed); lastFamily = family(seed)
            return GardenSpecimen(sessionID: completion.sessionID,
                seed: seed,
                kind: kind, ordinal: number / kind.interval,
                earnedAt: completion.earnedAt)
        }
    }
}

enum GardenDNA {
    static func mix(_ input: UInt64) -> UInt64 {
        var x = input &+ 0x9E3779B97F4A7C15
        x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
        x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
        return x ^ (x >> 31)
    }
    static func seed(for id: UUID) -> UInt64 {
        id.uuidString.utf8.reduce(UInt64(0xCBF29CE484222325)) { ($0 ^ UInt64($1)) &* 0x100000001B3 }
    }
    static func value(_ seed: UInt64, _ gene: Int) -> Float {
        Float(mix(seed &+ UInt64(gene) &* 0x9E3779B97F4A7C15) >> 40) / 16_777_216
    }
}
