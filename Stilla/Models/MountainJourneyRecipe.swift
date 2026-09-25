import Foundation
import simd

/// Versioned, deterministic terrain. Distances are Double; only nearby geometry is
/// converted to Float, so travelling farther never moves the camera far from zero.
struct MountainJourneyRecipe: Sendable {
    static let version = 2
    static let stageLength: Double = 24
    static let defaultSeed: UInt64 = 0x56494E444C41
    let seed: UInt64

    enum Biome: String, CaseIterable, Sendable {
        case pine, moss, golden, ridge, waterfall, temple
        var titleKey: String { "mountain.biome.\(rawValue)" }
    }

    struct Place: Equatable, Sendable {
        let biome: Biome
        let width: Double
        let relief: Double
        let roughness: Double
        let treeCount: Int
        let landmarkScale: Float
        let foliage: SIMD3<Float>
        let flowers: SIMD3<Float>
    }

    /// Shuffled six-place chapters avoid an obvious loop and guarantee that even
    /// chapter boundaries never put the same environment next to itself.
    func biome(stage: Int) -> Biome {
        let chapter = Int(floor(Double(stage) / 6))
        func order(_ chapter: Int) -> [Biome] {
            var result = Biome.allCases
            for index in stride(from: 5, through: 1, by: -1) {
                let choice = min(index, Int(variation(stage: chapter, salt: UInt64(800 + index)) * Float(index + 1)))
                result.swapAt(index, choice)
            }
            return result
        }
        var result = order(chapter)
        if result[0] == order(chapter - 1)[5] { result.swapAt(0, 1) }
        return result[stage - chapter * 6]
    }

    func place(stage: Int) -> Place {
        let biome = biome(stage: stage)
        let a = Double(variation(stage: stage, salt: 41))
        let b = Double(variation(stage: stage, salt: 43))
        let widths: [Biome: Double] = [.pine: 4.5, .moss: 7.0, .golden: 6.0,
                                      .ridge: 3.8, .waterfall: 5.8, .temple: 5.2]
        let counts: [Biome: Int] = [.pine: 17, .moss: 5, .golden: 14, .ridge: 2, .waterfall: 8, .temple: 6]
        let foliage: SIMD3<Float>
        let flowers: SIMD3<Float>
        switch biome {
        case .golden: foliage = [0.69,0.48,0.22]; flowers = [0.85,0.68,0.36]
        case .moss: foliage = [0.39,0.52,0.32]; flowers = [0.76,0.79,0.59]
        case .ridge: foliage = [0.36,0.46,0.43]; flowers = [0.54,0.53,0.69]
        case .waterfall: foliage = [0.26,0.47,0.39]; flowers = [0.74,0.83,0.78]
        case .temple: foliage = [0.50,0.62,0.48]; flowers = [0.84,0.63,0.60]
        case .pine: foliage = [0.29,0.42,0.32]; flowers = [0.77,0.73,0.50]
        }
        return Place(biome: biome, width: widths[biome]! + a * 1.3,
                     relief: (biome == .ridge ? 2.4 : 1.1) + b * 0.8,
                     roughness: 0.6 + a * 1.7, treeCount: counts[biome]! + Int(b * 4),
                     landmarkScale: 0.82 + Float(a) * 0.34,
                     foliage: foliage * (0.93 + Float(b) * 0.12), flowers: flowers)
    }

    private func smooth(_ t: Double) -> Double { t * t * t * (t * (t * 6 - 15) + 10) }

    func pathX(at distance: Double) -> Double {
        let stage = Int(floor(distance / Self.stageLength))
        let t = distance / Self.stageLength - Double(stage)
        let a = Double(variation(stage: stage, salt: 91)) * 14 - 7
        let b = Double(variation(stage: stage + 1, salt: 91)) * 14 - 7
        // Gentle bends between randomized arrival positions, level tangents at arrival.
        let bend = (Double(variation(stage: stage, salt: 93)) - 0.5) * 3
        return a + (b - a) * smooth(t) + bend * pow(sin(t * .pi), 2)
    }

    func elevation(at distance: Double) -> Double {
        // Continuous, monotonically rising, with almost level arrival terraces.
        let stage = floor(distance / Self.stageLength)
        let t = distance / Self.stageLength - stage
        return stage * 5.4 + smooth(t) * 5.4
    }

    func surface(at distance: Double, lateral: Double) -> Double {
        let stage = Int(floor(distance / Self.stageLength))
        let t = smooth(distance / Self.stageLength - Double(stage))
        let a = place(stage: stage), b = place(stage: stage + 1)
        let width = a.width + (b.width - a.width) * t
        let shoulder = a.relief + (b.relief - a.relief) * t
        let roughness = a.roughness + (b.roughness - a.roughness) * t
        let edge = max(0, abs(lateral) - width)
        let waterWeight = (a.biome == .waterfall ? 1-t : 0) + (b.biome == .waterfall ? t : 0)
        let channel = smooth(min(1, max(0, (lateral - 2.9) / 1.2))) * waterWeight * 10
        let folds = sin(distance * 0.37 + lateral * 0.45)
            + 0.45 * cos(distance * 0.79 - lateral * 0.7)
        return elevation(at: distance) - pow(edge, 0.86) * shoulder - channel
            + folds * min(1, edge / 5) * roughness
    }

    func point(at distance: Double, lateral: Double = 0, originStage: Int) -> SIMD3<Float> {
        let origin = Double(originStage) * Self.stageLength
        return [Float(pathX(at: distance) + lateral),
                Float(surface(at: distance, lateral: lateral) - elevation(at: origin)),
                Float(origin - distance)]
    }

    func variation(stage: Int, salt: UInt64) -> Float {
        var value = UInt64(bitPattern: Int64(stage)) &* 0x9E3779B97F4A7C15 &+ seed &+ salt
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        value ^= value >> 31
        return Float(value & 0xFFFFFF) / Float(0xFFFFFF)
    }
}
