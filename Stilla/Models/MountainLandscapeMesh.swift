import Foundation
import simd

/// CPU geometry is generated away from the main actor, batched by material so a
/// forest or a staircase doesn't become hundreds of RealityKit entities/draw calls.
struct MountainMeshBatch: Sendable {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []

    mutating func triangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) {
        let cross = simd_cross(b - a, c - a)
        guard simd_length_squared(cross) > 0.0000001 else { return }
        let normal = simd_normalize(cross)
        positions.append(contentsOf: [a, b, c])
        normals.append(contentsOf: [normal, normal, normal])
    }

    mutating func quad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>) {
        triangle(a, b, c); triangle(a, c, d)
    }

    mutating func box(center p: SIMD3<Float>, size: SIMD3<Float>, yaw: Float = 0) {
        let first = positions.count
        let r = size / 2
        let a = p + [-r.x, -r.y, r.z], b = p + [r.x, -r.y, r.z]
        let c = p + [r.x, r.y, r.z], d = p + [-r.x, r.y, r.z]
        let e = p + [-r.x, -r.y, -r.z], f = p + [r.x, -r.y, -r.z]
        let g = p + [r.x, r.y, -r.z], h = p + [-r.x, r.y, -r.z]
        quad(a,b,c,d); quad(f,e,h,g); quad(d,c,g,h)
        quad(e,f,b,a); quad(b,f,g,c); quad(e,a,d,h)
        if yaw != 0 {
            func rotate(_ v: SIMD3<Float>) -> SIMD3<Float> {
                [cos(yaw)*v.x + sin(yaw)*v.z, v.y, -sin(yaw)*v.x + cos(yaw)*v.z]
            }
            for index in first..<positions.count {
                positions[index] = p + rotate(positions[index] - p)
                normals[index] = rotate(normals[index])
            }
        }
    }

    mutating func branch(from a: SIMD3<Float>, to b: SIMD3<Float>, radius: Float) {
        let up = simd_normalize(b - a)
        let tangent = simd_normalize(simd_cross(up, abs(up.y) < 0.95 ? [0,1,0] : [1,0,0]))
        let bitangent = simd_cross(up, tangent)
        for index in 0..<7 {
            let angle = Float(index) * 2 * .pi / 7
            let next = Float(index + 1) * 2 * .pi / 7
            let r = (cos(angle) * tangent + sin(angle) * bitangent) * radius
            let s = (cos(next) * tangent + sin(next) * bitangent) * radius
            quad(a + s, a + r, b + r * 0.55, b + s * 0.55)
        }
    }

    mutating func crown(center: SIMD3<Float>, radius: SIMD3<Float>, phase: Float) {
        func point(_ ring: Int, _ segment: Int) -> SIMD3<Float> {
            let latitude = Float(ring) / 6 * .pi
            let longitude = Float(segment) / 11 * .pi * 2
            let irregular = 1 + 0.12 * sin(longitude * 3 + phase) * sin(latitude)
            return center + SIMD3(sin(latitude) * cos(longitude) * irregular,
                                   cos(latitude), sin(latitude) * sin(longitude) * irregular) * radius
        }
        for ring in 0..<6 {
            for segment in 0..<11 {
                quad(point(ring,segment), point(ring,segment+1),
                     point(ring+1,segment+1), point(ring+1,segment))
            }
        }
    }
}

enum MountainMeshBuilder {
    // Stone, path, timber, glazed roof, pine needles, warm brass, distant rock.
    static let colors: [SIMD3<Float>] = [
        [0.55,0.61,0.55], [0.79,0.76,0.64], [0.29,0.34,0.29],
        [0.30,0.43,0.41], [0.33,0.46,0.37], [0.73,0.55,0.30], [0.48,0.60,0.58],
        [0.42,0.52,0.34], [0.47,0.68,0.67], [0.80,0.69,0.53], [0.84,0.88,0.80]
    ]

    static func colors(for place: MountainJourneyRecipe.Place) -> [SIMD3<Float>] {
        var palette = colors
        palette[4] = place.foliage
        palette[9] = place.flowers
        return palette
    }

    static func chunk(recipe: MountainJourneyRecipe, stage: Int, origin: Int) -> [MountainMeshBatch] {
        var batches = Array(repeating: MountainMeshBatch(), count: colors.count)
        let place = recipe.place(stage: stage)
        let start = Double(stage) * MountainJourneyRecipe.stageLength - 9
        // Shared boundaries use identical samples. Cache the grid before triangulating.
        let rows = (0...24).map { row in
            (0...40).map { col in
                recipe.point(at: start + Double(row), lateral: Double(col - 20) * 1.8, originStage: origin)
            }
        }
        for row in 0..<24 {
            for col in 0..<40 {
                batches[0].quad(rows[row][col],rows[row][col+1],rows[row+1][col+1],rows[row+1][col])
            }
        }
        // Closely spaced treads follow the same continuous height field as the ridge.
        for step in 0..<48 {
            let distance = start + Double(step) * 0.5
            let p = recipe.point(at: distance, originStage: origin)
            let direction = Float(recipe.pathX(at: distance + 0.1) - recipe.pathX(at: distance - 0.1)) / 0.2
            let width = 1.5 + recipe.variation(stage: stage, salt: UInt64(1200 + step)) * 0.25
            let material = place.biome == .waterfall ? 2 : 1
            batches[material].box(center: p + [0,0.12,0], size: [width,0.24,0.64], yaw: -atan(direction))
        }
        let distance = Double(stage) * MountainJourneyRecipe.stageLength
        let terrace = recipe.point(at: distance, originStage: origin)
        arrival(at: terrace, place: place, batches: &batches)
        for index in 0..<place.treeCount {
            let u = recipe.variation(stage: stage, salt: UInt64(index * 17 + 2))
            let v = recipe.variation(stage: stage, salt: UInt64(index * 17 + 7))
            let d = start + 2 + Double(u) * 20
            let side: Double = index % 2 == 0 ? -1 : 1
            let lateral = side * (5.4 + Double(v) * 6)
            if place.biome == .waterfall && side > 0 && abs(d - distance) < 6 { continue }
            let p = recipe.point(at: d, lateral: lateral, originStage: origin)
            if place.biome == .golden || place.biome == .temple {
                broadleaf(at: p, size: 2.4 + v * 3.1, phase: u * 6, batches: &batches)
            } else {
                pine(at: p, size: 1.8 + v * 2.6, phase: u * 6, batches: &batches)
            }
        }
        // Two scales of detail: silhouettes first, then clumps, pebbles and flowers.
        for index in 0..<65 {
            let u = recipe.variation(stage: stage, salt: UInt64(2000 + index * 7))
            let v = recipe.variation(stage: stage, salt: UInt64(2002 + index * 7))
            let w = recipe.variation(stage: stage, salt: UInt64(2004 + index * 7))
            let d = start + 0.4 + Double(u) * 23
            let side: Double = index % 2 == 0 ? -1 : 1
            let lateral = side * (1.5 + Double(v) * 12)
            // Keep the arrival composition and clear route free of random clutter.
            if abs(d - distance) < 3.8 && abs(lateral) < 4.8 { continue }
            if place.biome == .waterfall && side > 0 && abs(d - distance) < 6 { continue }
            let p = recipe.point(at: d, lateral: lateral, originStage: origin)
            if index % 4 == 0 {
                let size: Float = place.biome == .ridge ? 1.5 + w * 3.8 : 0.3 + w * 1.25
                rock(at: p, size: size, moss: place.biome == .moss || place.biome == .waterfall,
                     phase: v * 6, batches: &batches)
            } else {
                grasses(at: p, size: 0.3 + w * 0.6, phase: u * 6,
                        flower: index % 3 == 0, batches: &batches)
            }
        }
        if place.biome == .waterfall {
            let p = recipe.point(at: distance - 0.5, originStage: origin)
            waterfall(at: p + [4.5,0,0], size: place.landmarkScale, batches: &batches)
        }
        // Nearby summits are streamed with the terrain, so the horizon reveals
        // new shapes during travel instead of repeating the same painted backdrop.
        for side: Double in [-1,1] {
            let u = recipe.variation(stage: stage, salt: side < 0 ? 601 : 607)
            let p = recipe.point(at: distance + 7, lateral: side*(29+Double(u)*12), originStage: origin)
            peak(at: p + [0,-12,0], height: 23+u*20, radius: 7+u*5, phase: u*6, batch: &batches[6])
        }
        return batches
    }

    private static func peak(at p: SIMD3<Float>, height: Float, radius: Float,
                             phase: Float, batch: inout MountainMeshBatch) {
        func point(_ row: Int, _ col: Int) -> SIMD3<Float> {
            let t = Float(row)/9, a = Float(col)/13 * .pi * 2
            let r = pow(1-t,0.73) * radius * (1+0.20*sin(a*3+phase+t*5))
            return p + [cos(a)*r+sin(t*2+phase)*2,t*height,sin(a)*r*0.8]
        }
        for row in 0..<9 {
            for col in 0..<13 {
                batch.quad(point(row,col+1),point(row,col),point(row+1,col),point(row+1,col+1))
            }
        }
    }

    private static func arrival(at p: SIMD3<Float>, place: MountainJourneyRecipe.Place,
                                batches: inout [MountainMeshBatch]) {
        switch place.biome {
        case .temple:
            batches[1].box(center: p + [0,0.08,0], size: [8.6,0.52,6.5])
            for x in -6...6 {
                for z in -4...4 {
                    batches[1].box(center: p + [Float(x)*0.63,0.38,Float(z)*0.63], size: [0.61,0.12,0.61])
                }
            }
            pavilion(at: p + [0,0.45,-0.6], scale: place.landmarkScale, batches: &batches)
            for x: Float in [-4,4] {
                batches[1].box(center: p + [x,0.8,0], size: [0.2,0.8,6.2])
                batches[1].box(center: p + [x,1.23,0], size: [0.32,0.12,6.3])
                lantern(at: p + [x*0.82,0.45,2.2], batches: &batches)
            }
        case .pine:
            pavilion(at: p + [-2.5,0.05,-0.4], scale: 0.58 * place.landmarkScale, batches: &batches)
            bench(at: p + [2.6,0,-0.5], batches: &batches)
            lantern(at: p + [-1.2,0,2.5], batches: &batches)
        case .moss:
            pond(at: p + [-3.1,0.04,-0.3], scale: 1.15 * place.landmarkScale, batches: &batches)
            for index in 0..<4 {
                let size = 0.65 + Float(index) * 0.23
                rock(at: p + [2.4+Float(index%2)*1.2,0,Float(index)*1.1-2],
                     size: size, moss: true, phase: Float(index)*2, batches: &batches)
            }
            bench(at: p + [2.9,0,2.3], batches: &batches)
        case .golden:
            gateway(at: p + [0,0,-1.6], scale: place.landmarkScale, batches: &batches)
            bench(at: p + [-2.6,0,0.5], batches: &batches)
            for index in 0..<24 {
                let a = Float(index) * 2.399
                let r: Float = 1.2 + Float(index % 5)*0.5
                let center = p + [cos(a)*r,0.04,sin(a)*r]
                batches[9].triangle(center + [-0.12,0,0],center + [0,0.015,0.18],center + [0.12,0,0])
            }
        case .ridge:
            // An unbuilt overlook, with a small cairn rather than another pavilion.
            for index in 0..<5 {
                let size = 0.8 - Float(index)*0.12
                batches[0].crown(center: p + [-2.4,0.3+Float(index)*0.36,0],
                                 radius: [size,0.24,size*0.7], phase: Float(index)*1.7)
            }
            rock(at: p + [3.6,-0.4,-1.8], size: 3.5 * place.landmarkScale,
                 moss: false, phase: 2, batches: &batches)
        case .waterfall:
            for plank in 0..<19 {
                batches[2].box(center: p + [0,0.35,Float(plank-9)*0.27], size: [5.5,0.22,0.24])
            }
            for x: Float in [-2.6,2.6] {
                for z: Float in [-2.3,0,2.3] {
                    batches[2].branch(from: p + [x,0.35,z], to: p + [x,1.4,z], radius: 0.07)
                }
                batches[2].branch(from: p + [x,1.3,-2.5], to: p + [x,1.3,2.5], radius: 0.06)
            }
            lantern(at: p + [-2.0,0.47,-1.8], batches: &batches)
        }
    }

    private static func bench(at p: SIMD3<Float>, batches: inout [MountainMeshBatch]) {
        for x: Float in [-0.65,0.65] {
            batches[1].box(center: p + [x,0.25,0], size: [0.2,0.5,0.45])
        }
        batches[2].box(center: p + [0,0.58,0], size: [1.9,0.17,0.55])
    }

    private static func gateway(at p: SIMD3<Float>, scale s: Float, batches: inout [MountainMeshBatch]) {
        for x: Float in [-1.5,1.5] {
            batches[2].branch(from: p + [x*s,0,0], to: p + [x*s,3.4*s,0], radius: 0.13*s)
            batches[1].box(center: p + [x*s,0.16,0], size: [0.5,0.32,0.5])
        }
        batches[2].box(center: p + [0,2.65*s,0], size: [3.6*s,0.18,0.20])
        batches[2].box(center: p + [0,3.25*s,0], size: [4.3*s,0.25,0.4])
        batches[3].box(center: p + [0,3.43*s,0], size: [4.6*s,0.12,0.7])
    }

    private static func rock(at p: SIMD3<Float>, size s: Float, moss: Bool, phase: Float,
                             batches: inout [MountainMeshBatch]) {
        batches[0].crown(center: p + [0,s*0.25,0], radius: [s*0.70,s*0.67,s*0.55], phase: phase)
        if moss {
            batches[7].crown(center: p + [-s*0.12,s*0.74,0], radius: [s*0.55,s*0.17,s*0.43], phase: phase)
        }
    }

    private static func grasses(at p: SIMD3<Float>, size s: Float, phase: Float,
                                flower: Bool, batches: inout [MountainMeshBatch]) {
        for leaf in 0..<7 {
            let a = phase + Float(leaf) * 2.4
            let side = SIMD3<Float>(cos(a),0,sin(a))
            let bend = p + side*s*0.25 + [0,s*0.7,0]
            let tip = p + side*s*0.75 + [0,s*0.6,0]
            let width = SIMD3<Float>(-sin(a),0,cos(a))*s*0.045
            batches[7].quad(p,bend-width,tip,bend+width)
            batches[7].quad(p,bend+width,tip,bend-width)
        }
        if flower {
            let top = p + [0,s*0.85,0]
            batches[7].branch(from: p, to: top, radius: 0.016)
            for petal in 0..<5 {
                let a = Float(petal)*2 * .pi/5
                let center = top + [cos(a)*0.10,0,sin(a)*0.10]
                batches[9].triangle(top,center + [0,0.04,0.09],center + [0.09,0.04,-0.02])
            }
        }
    }

    private static func broadleaf(at p: SIMD3<Float>, size s: Float, phase: Float,
                                  batches: inout [MountainMeshBatch]) {
        let top = p + [sin(phase)*s*0.18,s,0]
        batches[2].branch(from: p, to: top, radius: s*0.047)
        for branch in 0..<5 {
            let a = phase + Float(branch)*2.4
            let end = p + [cos(a)*s*0.4,s*(0.72+Float(branch)*0.07),sin(a)*s*0.4]
            batches[2].branch(from: p + [0,s*0.55,0], to: end, radius: s*0.026)
            batches[4].crown(center: end, radius: [s*0.43,s*0.30,s*0.39], phase: a)
        }
    }

    private static func pond(at p: SIMD3<Float>, scale s: Float, batches: inout [MountainMeshBatch]) {
        batches[0].crown(center: p, radius: [1.55*s,0.2,2.05*s], phase: 1)
        batches[8].crown(center: p + [0,0.18,0], radius: [1.35*s,0.025,1.82*s], phase: 1)
        for index in 0..<7 {
            let a = Float(index)*2.4
            let c = p + [cos(a)*s*0.8,0.23,sin(a)*s*1.3]
            batches[7].crown(center: c, radius: [0.20,0.02,0.16], phase: a)
            if index % 3 == 0 {
                batches[9].crown(center: c + [0,0.055,0], radius: [0.10,0.08,0.10], phase: a)
            }
        }
    }

    private static func waterfall(at p: SIMD3<Float>, size s: Float, batches: inout [MountainMeshBatch]) {
        // A stepped stream falls into a basin beside the path. Constant geometry,
        // delicate highlights: no camera movement or flashing particles at rest.
        let top = p + [0,3.2*s,0.3]
        for side: Float in [-1,1] {
            rock(at: top + [side*1.3,-2,-1.5], size: 3.1*s, moss: true, phase: side, batches: &batches)
        }
        for step in 0..<18 {
            let t = Float(step)/18, next = Float(step+1)/18
            func center(_ t: Float) -> SIMD3<Float> { top + [sin(t*4)*0.3,-t*8.5*s,t*2.0] }
            let a = center(t), b = center(next)
            let w: Float = 0.6 + 0.15*sin(t*7)
            batches[8].quad(a + [-w,0,0], b + [-w,0,0], b + [w,0,0], a + [w,0,0])
            for line in 0..<3 {
                let x = Float(line-1)*0.32
                batches[10].quad(a + [x,0,0.015], b + [x,0,0.015],
                                  b + [x+0.045,0,0.015],a + [x+0.045,0,0.015])
            }
        }
        let basin = top + [-0.23,-8.5*s,2]
        batches[0].crown(center: basin + [0,-4,0], radius: [2.2*s,4,2.6*s], phase: 2)
        pond(at: basin, scale: s, batches: &batches)
    }

    private static func pavilion(at p: SIMD3<Float>, scale: Float, batches: inout [MountainMeshBatch]) {
        func at(_ x: Float, _ y: Float, _ z: Float) -> SIMD3<Float> { p + SIMD3(x,y,z) * scale }
        batches[1].box(center: at(0,0.17,0), size: SIMD3<Float>(4.1,0.34,3.6) * scale)
        for x: Float in [-1.55, 1.55] {
            for z: Float in [-1.25, 1.25] {
                batches[2].branch(from: at(x,0.34,z), to: at(x,3.05,z), radius: 0.12 * scale)
                batches[1].box(center: at(x,0.46,z), size: SIMD3<Float>(0.39,0.24,0.39) * scale)
            }
        }
        for z: Float in [-1.25, 1.25] {
            batches[2].box(center: at(0,2.8,z), size: SIMD3<Float>(3.55,0.25,0.24) * scale)
        }
        for x: Float in [-1.55, 1.55] {
            batches[2].box(center: at(x,2.8,0), size: SIMD3<Float>(0.24,0.25,2.9) * scale)
        }
        // Hipped roof with curved eaves, generated as nested rectangular rings.
        let rings: [(Float,Float,Float)] = [(2.65,2.24,2.88),(2.1,1.76,2.79),(1.40,1.10,3.23),(0.28,0.20,4.08)]
        for index in 0..<(rings.count - 1) {
            let outer = rings[index], inner = rings[index+1]
            let a = [at(-outer.0,outer.2,outer.1), at(outer.0,outer.2,outer.1),
                     at(outer.0,outer.2,-outer.1), at(-outer.0,outer.2,-outer.1)]
            let b = [at(-inner.0,inner.2,inner.1), at(inner.0,inner.2,inner.1),
                     at(inner.0,inner.2,-inner.1), at(-inner.0,inner.2,-inner.1)]
            for side in 0..<4 {
                let next = (side + 1) % 4
                batches[3].quad(a[side], a[next], b[next], b[side])
                // A thin edge catches the morning light without an ornate texture.
                if index == 0 { batches[2].branch(from: a[side], to: a[next], radius: 0.06 * scale) }
            }
        }
        batches[3].box(center: at(0,4.09,0), size: SIMD3<Float>(0.58,0.12,0.43) * scale)
        batches[5].branch(from: at(0,4.12,0), to: at(0,4.53,0), radius: 0.055 * scale)
        // A single hanging bell and a place to sit beneath the roof.
        batches[5].branch(from: at(0,2.75,0), to: at(0,2.37,0), radius: 0.022 * scale)
        batches[5].crown(center: at(0,2.28,0), radius: SIMD3<Float>(0.15,0.18,0.15) * scale, phase: 0)
        batches[2].box(center: at(0,0.7,-1.0), size: SIMD3<Float>(2.4,0.2,0.48) * scale)
    }

    private static func pine(at p: SIMD3<Float>, size: Float, phase: Float, batches: inout [MountainMeshBatch]) {
        let lean: Float = sin(phase) * 0.25
        let top = p + [lean * size, size, 0]
        batches[2].branch(from: p, to: top, radius: size * 0.055)
        for level in 0..<4 {
            let t = Float(level) / 3
            let angle = phase + Float(level) * 2.4
            let spread = size * (0.39 - t * 0.14)
            let start = p + [lean * size * (0.55+t*0.4), size*(0.55+t*0.4), 0]
            let end = start + [cos(angle)*spread, size*0.13, sin(angle)*spread]
            batches[2].branch(from: start, to: end, radius: size * 0.024)
            batches[4].crown(center: end, radius: [spread * 1.3, size * 0.16, spread], phase: angle)
        }
        batches[4].crown(center: top + [0,size*0.1,0], radius: [size*0.32,size*0.16,size*0.29], phase: phase)
    }

    private static func lantern(at p: SIMD3<Float>, batches: inout [MountainMeshBatch]) {
        batches[1].box(center: p + [0,0.13,0], size: [0.50,0.26,0.50])
        batches[1].box(center: p + [0,0.48,0], size: [0.21,0.56,0.21])
        batches[5].box(center: p + [0,0.86,0], size: [0.29,0.25,0.29])
        batches[3].box(center: p + [0,1.04,0], size: [0.53,0.13,0.53])
    }

    static func distantMountains() -> [MountainMeshBatch] {
        var batches = Array(repeating: MountainMeshBatch(), count: colors.count)
        for row in 0..<3 {
            for index in 0..<9 {
                let phase = Float(index * 7 + row * 11)
                let x = Float(index - 4) * 36 + Float(row) * 12
                let z = -95 - Float(row) * 62
                let height: Float = 50 + 27 * sin(phase * 1.7)
                let center = SIMD3<Float>(x,-55,z)
                let segments = 13, rings = 10
                func point(_ ring: Int, _ segment: Int) -> SIMD3<Float> {
                    let t = Float(ring) / Float(rings)
                    let a = Float(segment) / Float(segments) * .pi * 2
                    let radius = pow(1 - t, 0.65) * (25 + 5 * sin(a * 3 + phase))
                    return center + [cos(a)*radius + sin(t*3+phase)*5,
                                      t*height + sin(a*4+phase)*3*(1-t), sin(a)*radius*0.6]
                }
                for ring in 0..<rings {
                    for s in 0..<segments {
                        batches[6].quad(point(ring,s+1),point(ring,s),point(ring+1,s),point(ring+1,s+1))
                    }
                }
            }
        }
        return batches
    }
}

/// Three actual geometry budgets. Tile borders always sample every two metres,
/// even when the interior is simplified, so adjacent LODs share exact vertices.
enum MountainDetail: Int, Sendable { case near, middle, silhouette }
struct MountainTile: Hashable, Sendable {
    let x: Int
    let z: Int
    static let size: Float = 32
    init(x: Int, z: Int) { self.x = x; self.z = z }
    init(at p: SIMD3<Float>) {
        x = Int(floor(p.x / Self.size)); z = Int(floor(p.z / Self.size))
    }
}

extension MountainMeshBuilder {
    static func regionTile(recipe: MountainRegionRecipe, tile: MountainTile, detail: MountainDetail) -> [MountainMeshBatch] {
        var batches = Array(repeating: MountainMeshBatch(), count: colors.count)
        let x0 = Float(tile.x) * MountainTile.size, z0 = Float(tile.z) * MountainTile.size
        let strideSize: Float = detail == .near ? 2 : detail == .middle ? 4 : 8
        func terrain(_ x: Float, _ z: Float) -> SIMD3<Float> { [x,recipe.height(x: x,z: z),z] }
        func contains(_ p: SIMD3<Float>) -> Bool {
            p.x >= x0 && p.x < x0+32 && p.z >= z0 && p.z < z0+32
        }
        for z in stride(from: z0, to: z0+32, by: strideSize) {
            for x in stride(from: x0, to: x0+32, by: strideSize) {
                let corners = [SIMD2(x,z), SIMD2(x,z+strideSize), SIMD2(x+strideSize,z+strideSize), SIMD2(x+strideSize,z)]
                let center = terrain(x+strideSize/2,z+strideSize/2)
                for edge in 0..<4 {
                    let a = corners[edge], b = corners[(edge+1)%4]
                    let boundary = (a.x == b.x && (a.x == x0 || a.x == x0+32))
                        || (a.y == b.y && (a.y == z0 || a.y == z0+32))
                    let count = boundary ? Int(strideSize/2) : 1
                    for segment in 0..<count {
                        let p = simd_mix(a,b,SIMD2(repeating: Float(segment)/Float(count)))
                        let q = simd_mix(a,b,SIMD2(repeating: Float(segment+1)/Float(count)))
                        batches[0].triangle(center,terrain(p.x,p.y),terrain(q.x,q.y))
                    }
                }
            }
        }
        // Both branches exist before choosing. Steps have continuous support from
        // the common height field, rather than intersecting independent ridges.
        for edge in MountainRegionRecipe.edges {
            for step in 0..<72 {
                let t = Float(step)/72
                var p = recipe.route(edge,t: t)
                guard contains(p) else { continue }
                let next = recipe.route(edge,t: min(1,t+1/72))
                p.y = recipe.height(x: p.x,z: p.z)
                let yaw = atan2(-(next.x-p.x), -(next.z-p.z))
                batches[1].box(center: p+[0,0.08,0], size: [1.85,0.16,0.78], yaw: yaw)
            }
        }
        for id in MountainRegionRecipe.PlaceID.allCases {
            let p = recipe.position(id)
            guard contains(p) else { continue }
            let place = recipe.place(id)
            // All guide cushions sit on this exact surface. Landmarks sit behind
            // or beside the shared clear circle, including temple columns.
            batches[1].box(center: p+[0,0.12,0],size: [6.8,0.24,5.8])
            if detail != .silhouette {
                for side: Float in [-1,1] {
                    lantern(at: p+[side*3,0.24,0.7],batches: &batches)
                }
                switch id {
                case .mossGate:
                    gateway(at: p+[0,0,-5.5],scale: 1.1,batches: &batches)
                    pond(at: p+[-5,0,-1],scale: 1.1,batches: &batches)
                case .pineGlade:
                    bench(at: p+[-4,0,-1],batches: &batches)
                    for side: Float in [-1,1] {
                        pine(at: p+[side*6,0,-6],size: 5.5,phase: side,batches: &batches)
                    }
                case .brookRavine:
                    waterfall(at: p+[6,0,-4],size: 0.8,batches: &batches)
                    rock(at: p+[7,-2,-5],size: 6,moss: true,phase: 2,batches: &batches)
                case .lakeTerrace:
                    pond(at: p+[-6,0,-4],scale: 2.5,batches: &batches)
                    bench(at: p+[4,0,-2],batches: &batches)
                case .mountainRidge:
                    for i in 0..<5 {
                        let r = 0.8-Float(i)*0.12
                        batches[0].crown(center: p+[-4,0.3+Float(i)*0.36,-2],radius: [r,0.24,r],phase: Float(i))
                    }
                case .templeGrove:
                    gateway(at: p+[0,0,-5],scale: place.landmarkScale,batches: &batches)
                    for side: Float in [-1,1] {
                        broadleaf(at: p+[side*6,0,-5],size: 4.6,phase: side,batches: &batches)
                    }
                case .cloudTemple:
                    pavilion(at: p+[0,0,-6],scale: 1.25*place.landmarkScale,batches: &batches)
                }
            }
        }
        let count = detail == .near ? 90 : detail == .middle ? 26 : 5
        let tileKey = tile.x &* 73856093 ^ tile.z &* 19349663
        for index in 0..<count {
            let u = recipe.noise.variation(stage: tileKey,salt: UInt64(index*5+100))
            let v = recipe.noise.variation(stage: tileKey,salt: UInt64(index*5+101))
            let w = recipe.noise.variation(stage: tileKey,salt: UInt64(index*5+102))
            let x = x0+u*31.99, z = z0+v*31.99
            guard recipe.allowsProp(x: x,z: z) else { continue }
            let p = terrain(x,z), id = recipe.nearestPlace(x: x,z: z)
            if index % 5 == 0, id != .mountainRidge {
                if id == .templeGrove {
                    broadleaf(at: p,size: 2.8+w*3,phase: u*6,batches: &batches)
                } else { pine(at: p,size: 2+w*3.5,phase: u*6,batches: &batches) }
            } else if detail == .near {
                if index % 4 == 0 { rock(at: p,size: 0.3+w*1.5,moss: true,phase: u*6,batches: &batches) }
                else { grasses(at: p,size: 0.3+w*0.6,phase: u*6,flower: index%3 == 0,batches: &batches) }
            }
        }
        // Region-seeded silhouettes change with each generated valley.
        if detail == .silhouette {
            let u = recipe.noise.variation(stage: tileKey,salt: 999)
            let p = terrain(x0+16,z0+16)
            if abs(p.x) > 40 {
                peak(at: p+[0,-12,0],height: 24+u*26,radius: 12+u*8,phase: u*6,batch: &batches[6])
            }
        }
        return batches
    }
}
