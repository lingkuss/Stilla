import Foundation
import simd

/// Stable identities and bounded local coordinates; a new region never increases
/// the magnitude of GPU coordinates. Increment version when changing generation.
struct MountainRegionRecipe: Sendable {
    static let version = 1
    let seed: UInt64
    let region: Int
    enum PlaceID: String, Codable, CaseIterable, Sendable, Identifiable {
        case mossGate, pineGlade, brookRavine, lakeTerrace, mountainRidge, templeGrove, cloudTemple
        var id: String { rawValue }
        var titleKey: String { "mountain.place.\(rawValue)" }
        var descriptionKey: String { titleKey + ".description" }
        var level: Int {
            switch self {
            case .mossGate: 0
            case .pineGlade, .brookRavine: 1
            case .lakeTerrace: 2
            case .mountainRidge, .templeGrove: 3
            case .cloudTemple: 4
            }
        }
    }
    struct Edge: Hashable, Codable, Sendable {
        let from: PlaceID
        let to: PlaceID
    }
    static let edges: [Edge] = [
        .init(from: .mossGate, to: .pineGlade), .init(from: .mossGate, to: .brookRavine),
        .init(from: .pineGlade, to: .lakeTerrace), .init(from: .brookRavine, to: .lakeTerrace),
        .init(from: .lakeTerrace, to: .mountainRidge), .init(from: .lakeTerrace, to: .templeGrove),
        .init(from: .mountainRidge, to: .cloudTemple), .init(from: .templeGrove, to: .cloudTemple)
    ]
    func outgoing(_ id: PlaceID) -> [Edge] { Self.edges.filter { $0.from == id } }
    var noise: MountainJourneyRecipe {
        MountainJourneyRecipe(seed: seed &+ UInt64(region) &* 0x9E3779B97F4A7C15 &+ UInt64(Self.version))
    }
    func variation(_ id: PlaceID, _ salt: UInt64) -> Float {
        noise.variation(stage: PlaceID.allCases.firstIndex(of: id)!, salt: salt)
    }
    func position(_ id: PlaceID) -> SIMD3<Float> {
        let side: Float = [.pineGlade, .mountainRidge].contains(id) ? -1
            : [.brookRavine, .templeGrove].contains(id) ? 1 : 0
        return [side * (20 + variation(id, 10) * 6), Float(id.level) * 6,
                -Float(id.level) * 34]
    }
    func route(_ edge: Edge, t: Float) -> SIMD3<Float> {
        let a = position(edge.from), b = position(edge.to)
        let s = t * t * (3 - 2 * t)
        let bend = (variation(edge.from, UInt64(edge.to.level + 80)) - 0.5) * 6
        return [a.x + (b.x - a.x) * s + bend * pow(sin(t * .pi), 2),
                a.y + (b.y - a.y) * s, a.z + (b.z - a.z) * t]
    }
    /// Continuous height field shared by every tile and every LOD. Path shoulders
    /// and guide terraces are analytically flattened before any props are placed.
    func height(x: Float, z: Float) -> Float {
        var nearest = Float.greatestFiniteMagnitude
        var elevation: Float = 0
        for edge in Self.edges {
            let a = position(edge.from), b = position(edge.to)
            let t = min(1, max(0, (z - a.z) / (b.z - a.z)))
            let p = route(edge, t: t)
            let d = simd_length(SIMD2(x - p.x, z - p.z))
            if d < nearest { nearest = d; elevation = p.y }
        }
        let phase = noise.variation(stage: 0, salt: 903) * 6
        let shoulder = max(0, nearest - 3)
        let waves = sin(x * 0.14 + phase) * cos(z * 0.12 - phase) * 2
            + sin(x * 0.43 + z * 0.19 + phase) * 0.5
        var result = elevation - pow(shoulder, 0.85) * (0.85 + phase * 0.08)
            + waves * min(1, shoulder / 8)
        for id in PlaceID.allCases {
            let p = position(id)
            let d = simd_length(SIMD2(x-p.x,z-p.z))
            let t = min(1,max(0,(d-7)/4))
            let weight = 1-t*t*(3-2*t)
            result += (p.y-result)*weight
        }
        let brook = position(.brookRavine)
        let channel = simd_length(SIMD2((x-brook.x-7)/3.2,(z-brook.z+2)/7))
        let cut = max(0,1-channel*channel)
        result -= cut*cut*7
        return result
    }
    func nearestPlace(x: Float, z: Float) -> PlaceID {
        PlaceID.allCases.min { a, b in
            let pa = position(a), pb = position(b)
            return simd_length_squared(SIMD2(x-pa.x,z-pa.z)) < simd_length_squared(SIMD2(x-pb.x,z-pb.z))
        }!
    }
    func allowsProp(x: Float, z: Float) -> Bool {
        // Wide foreground/arrival clearing protects both the guide and the view.
        for id in PlaceID.allCases {
            let p = position(id)
            if abs(x-p.x) < 8 && z > p.z-7 && z < p.z+14 { return false }
        }
        for edge in Self.edges {
            let a = position(edge.from), b = position(edge.to)
            let t = min(1, max(0, (z-a.z)/(b.z-a.z)))
            let p = route(edge, t: t)
            if simd_length(SIMD2(x-p.x,z-p.z)) < 3.4 { return false }
        }
        return true
    }
    func place(_ id: PlaceID) -> MountainJourneyRecipe.Place {
        let biome: MountainJourneyRecipe.Biome
        switch id {
        case .mossGate, .lakeTerrace: biome = .moss
        case .pineGlade: biome = .pine
        case .brookRavine: biome = .waterfall
        case .mountainRidge: biome = .ridge
        case .templeGrove: biome = .golden
        case .cloudTemple: biome = .temple
        }
        let tint = noise.variation(stage: 0, salt: 700)
        let density = variation(id, 701)
        return .init(biome: biome, width: 7, relief: 1.5, roughness: 1,
                     treeCount: biome == .ridge ? 3 : 12 + Int(density * 10),
                     landmarkScale: 0.85 + variation(id, 702) * 0.3,
                     foliage: [0.30 + tint*0.10 + Float(id.level)*0.025, 0.46+tint*0.05, 0.35+tint*0.06],
                     flowers: [0.78, 0.72+tint*0.06, 0.59])
    }
}

struct MountainPlaceAddress: Codable, Hashable, Sendable {
    var region: Int
    var place: MountainRegionRecipe.PlaceID
    static let start = Self(region: 0, place: .mossGate)
}

struct MountainSessionContext: Sendable {
    enum Mode: String, Codable, CaseIterable {
        case guided, silent
        var durations: [Int] { Array(stride(from: 5, through: self == .guided ? 30 : 120, by: 5)) }
    }
    let id: UUID
    let address: MountainPlaceAddress
    let mode: Mode
    let durationSeconds: Int
    let startedAtUptime: TimeInterval
    func elapsed(at uptime: TimeInterval) -> Int {
        Int(min(Double(durationSeconds), max(0, uptime - startedAtUptime)))
    }
}

/// Separate from journey progress and the app's ordinary meditation preferences.
struct MountainMeditationPreferences: Codable, Equatable {
    struct Settings: Codable, Equatable {
        var minutes = 10
        var intention = ""
        var ambience = "None"
        var startSound = "Singing Bowl"
        var endSound = "Gentle Chime"
        var breathingCues = false
        var ambienceVolume: Float = 0.5
        var cueVolume: Float = 0.5

        enum CodingKeys: String, CodingKey {
            case minutes, intention, ambience, startSound, endSound, breathingCues, ambienceVolume, cueVolume
        }

        init(minutes: Int = 10, intention: String = "", ambience: String = "None",
             startSound: String = "Singing Bowl", endSound: String = "Gentle Chime",
             breathingCues: Bool = false, ambienceVolume: Float = 0.5, cueVolume: Float = 0.5) {
            self.minutes = minutes
            self.intention = intention
            self.ambience = ambience
            self.startSound = startSound
            self.endSound = endSound
            self.breathingCues = breathingCues
            self.ambienceVolume = ambienceVolume
            self.cueVolume = cueVolume
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            minutes = try c.decodeIfPresent(Int.self, forKey: .minutes) ?? 10
            intention = try c.decodeIfPresent(String.self, forKey: .intention) ?? ""
            ambience = try c.decodeIfPresent(String.self, forKey: .ambience) ?? "None"
            // Existing saved sessions retain their previously quiet chimes.
            startSound = try c.decodeIfPresent(String.self, forKey: .startSound) ?? "None"
            endSound = try c.decodeIfPresent(String.self, forKey: .endSound) ?? "None"
            breathingCues = try c.decodeIfPresent(Bool.self, forKey: .breathingCues) ?? false
            ambienceVolume = try c.decodeIfPresent(Float.self, forKey: .ambienceVolume) ?? 0.5
            cueVolume = try c.decodeIfPresent(Float.self, forKey: .cueVolume) ?? 0.5
        }
    }
    var guided = Settings()
    var silent = Settings(startSound: "None", endSound: "None")
    subscript(mode: MountainSessionContext.Mode) -> Settings {
        get { mode == .guided ? guided : silent }
        set {
            var value = newValue
            if !mode.durations.contains(value.minutes) { value.minutes = 10 }
            value.ambienceVolume = value.ambienceVolume.isFinite ? min(1, max(0, value.ambienceVolume)) : 0.5
            value.cueVolume = value.cueVolume.isFinite ? min(1, max(0, value.cueVolume)) : 0.5
            if mode == .guided { guided = value } else { silent = value }
        }
    }
    static func restore(_ data: Data) -> Self {
        var value = (try? JSONDecoder().decode(Self.self,from: data)) ?? Self()
        for mode in MountainSessionContext.Mode.allCases { value[mode] = value[mode] }
        return value
    }
}

struct MountainJourneyProgress: Codable, Equatable {
    var generatorVersion = MountainRegionRecipe.version
    var seed = MountainJourneyRecipe.defaultSeed
    var current = MountainPlaceAddress.start
    var discovered: Set<MountainPlaceAddress> = [.start]
    var completed: Set<MountainPlaceAddress> = []
    var opened: Set<Connection> = []
    var creditedSessions: Set<UUID> = []
    struct Connection: Codable, Hashable {
        let from: MountainPlaceAddress
        let to: MountainPlaceAddress
    }
    func destinations(from address: MountainPlaceAddress) -> [MountainPlaceAddress] {
        opened.filter { $0.from == address }.map(\.to).sorted {
            $0.region == $1.region ? $0.place.rawValue < $1.place.rawValue : $0.region < $1.region
        }
    }
    func canTravel(to address: MountainPlaceAddress) -> Bool {
        address != current && (discovered.contains(address) || destinations(from: current).contains(address))
    }
    @discardableResult mutating func arrive(_ address: MountainPlaceAddress) -> Bool {
        guard canTravel(to: address) else { return false }
        current = address
        discovered.insert(address)
        return true
    }
    @discardableResult mutating func complete(_ session: MountainSessionContext, at uptime: TimeInterval,
                                             reachedEnd: Bool) -> Bool {
        guard reachedEnd, session.durationSeconds > 0, session.elapsed(at: uptime) >= session.durationSeconds,
              session.address == current, discovered.contains(session.address),
              !creditedSessions.contains(session.id) else { return false }
        creditedSessions.insert(session.id)
        completed.insert(session.address)
        let recipe = MountainRegionRecipe(seed: seed, region: current.region)
        for edge in recipe.outgoing(current.place) {
            opened.insert(.init(from: current, to: .init(region: current.region, place: edge.to)))
        }
        if current.place == .cloudTemple, current.region < Int.max - 1 {
            opened.insert(.init(from: current, to: .init(region: current.region + 1, place: .mossGate)))
        }
        return true
    }
}
