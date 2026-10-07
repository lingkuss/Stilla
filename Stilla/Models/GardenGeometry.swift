import Foundation
import simd

/// One indexed, coloured surface per specimen, shared by the world and the viewer.
/// Hue and lightness fit in UV0, so each reward category needs just one draw.
struct GardenMesh: Sendable {
    var positions: [SIMD3<Float>] = []
    var normals: [SIMD3<Float>] = []
    var pigments: [SIMD2<Float>] = []
    var indices: [UInt32] = []
    /// Crystals only: x = 0 (glass), 1 (matrix) or 2 (inclusion); y = axial growth coordinate.
    /// Empty for botanical meshes; reused as the crystal viewer's UV channel.
    var mineralSurfaces: [SIMD2<Float>] = []
    var triangleCount: Int { indices.count / 3 }

    mutating func append(_ other: GardenMesh, at origin: SIMD3<Float>, scale: Float = 1) {
        let offset = UInt32(positions.count)
        if !mineralSurfaces.isEmpty || !other.mineralSurfaces.isEmpty {
            if mineralSurfaces.isEmpty { mineralSurfaces = Array(repeating: .zero,count: positions.count) }
            mineralSurfaces += other.mineralSurfaces.isEmpty ? Array(repeating: .zero,count: other.positions.count) : other.mineralSurfaces
        }
        positions += other.positions.map { $0 * scale + origin }
        normals += other.normals
        pigments += other.pigments
        indices += other.indices.map { $0 + offset }
    }

    mutating func facet(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, pigment: SIMD2<Float>) {
        let cross = simd_cross(b-a, c-a)
        guard simd_length_squared(cross) > 1e-12 else { return }
        let offset = UInt32(positions.count)
        positions += [a,b,c]
        normals += Array(repeating: simd_normalize(cross), count: 3)
        pigments += Array(repeating: pigment, count: 3)
        indices += [offset,offset+1,offset+2]
    }

    mutating func surface(rows: Int, columns: Int, pigment: (Float, Float) -> SIMD2<Float>,
                          point: (Float, Float) -> SIMD3<Float>) {
        let offset = UInt32(positions.count)
        for row in 0...rows { for col in 0...columns {
            let u = Float(row)/Float(rows), v = Float(col)/Float(columns)*2-1
            let du = point(min(1,u+0.001),v)-point(max(0,u-0.001),v)
            let dv = point(u,min(1,v+0.001))-point(u,max(-1,v-0.001))
            let cross = simd_cross(dv,du)
            positions.append(point(u,v))
            normals.append(simd_length_squared(cross)>1e-12 ? simd_normalize(cross) : [0,1,0])
            pigments.append(pigment(u,v))
        } }
        for row in 0..<rows { for col in 0..<columns {
            let a = offset + UInt32(row*(columns+1)+col), b = a+1, c = a+UInt32(columns+1), d = c+1
            indices += [a,b,d,a,d,c]
        } }
    }

    static func rgb(_ pigment: SIMD2<Float>) -> SIMD3<Float> {
        let saturation: Float = 0.70*(1-pigment.y*0.8), value: Float = 0.40+0.60*pigment.y
        func channel(_ offset: Float) -> Float {
            let h = pigment.x+offset, f = h-floor(h)
            return value*(1-saturation+saturation*min(1,max(0,abs(f*6-3)-1)))
        }
        return [channel(0),channel(2/3),channel(1/3)]
    }
}

enum GardenGeometry {
    enum Detail: Sendable { case world, portrait }
    static let revision = 4

    static func build(_ specimen: GardenSpecimen, detail: Detail) -> GardenMesh {
        let mesh: GardenMesh
        switch specimen.kind {
        case .flower: mesh = flower(specimen.seed,detail: detail)
        case .crystal: mesh = crystal(specimen.seed,detail: detail)
        case .tree: mesh = tree(specimen.seed,detail: detail)
        }
        // Both LODs use identical DNA; no frame-time tessellation.
        return mesh
    }

    static func family(_ seed: UInt64, count: Int) -> Int { Int(GardenDNA.value(seed,900)*Float(count)) }

    static func frame(_ direction: SIMD3<Float>) -> (SIMD3<Float>,SIMD3<Float>,SIMD3<Float>) {
        let axis = simd_length_squared(direction)>1e-12 ? simd_normalize(direction) : SIMD3<Float>(0,1,0)
        let side = simd_normalize(simd_cross(axis,abs(axis.y)>0.92 ? SIMD3(1,0,0) : SIMD3(0,1,0)))
        return (axis,side,simd_cross(axis,side))
    }

    static func tube(_ mesh: inout GardenMesh, from a: SIMD3<Float>, via control: SIMD3<Float>,
                     to b: SIMD3<Float>, radius: Float, tip: Float, hue: Float,
                     light: Float = 0.28, rows: Int, sides: Int) {
        mesh.surface(rows: rows,columns: sides,pigment: { u,v in
            [hue,light+u*0.14+0.025*cos(v * .pi*4)]
        }) { u,v in
            let center = (1-u)*(1-u)*a+2*(1-u)*u*control+u*u*b
            let tangent = 2*(1-u)*(control-a)+2*u*(b-control)
            let (_,x,z) = frame(simd_length_squared(tangent)>1e-10 ? tangent : b-a)
            let angle = (v+1)*Float.pi, r = radius+(tip-radius)*u
            return center+(x*cos(angle)+z*sin(angle))*r
        }
    }

    static func leaf(_ mesh: inout GardenMesh, root: SIMD3<Float>, direction: SIMD3<Float>,
                     length: Float, width: Float, shape: Int, hue: Float, light: Float,
                     fine: Bool, phase: Float = 0) {
        let (axis,side,normal) = frame(direction)
        mesh.surface(rows: fine ? 10 : 3,columns: fine ? 4 : 2,pigment: { u,v in
            [hue+0.02*u,light+u*0.16+abs(v)*0.13]
        }) { u,v in
            let sine = max(0,sin(u * .pi))
            let profile = pow(sine,shape == 1 ? 0.48 : 0.9)
            let lobes: Float = shape == 2 ? 0.80+0.20*cos(u*Float.pi*8) : 1
            let twist = sin(u*2.8+phase)*0.20
            return root+axis*(u*length)+side*(v*profile*width*lobes)
                + normal*(sin(u * .pi)*length*0.17+v*twist*width-abs(v)*profile*width*0.23)
        }
    }

    /// Bounded low-detail world geometry; the complete collection stays in storage.
    static func world(_ specimens: [GardenSpecimen], dna: MountainWorldDNA, economical: Bool,
                      triangleBudget: Int = 70_000) -> [GardenMesh] {
        var batches = [GardenMesh(),GardenMesh(),GardenMesh()]
        var remaining = max(0,triangleBudget)
        var occupied: [SIMD2<Float>] = []
        let flowers = Array(specimens.filter { $0.kind == .flower }.suffix(economical ? 48 : 128))
        let crystals = Array(specimens.filter { $0.kind == .crystal }.suffix(economical ? 6 : 12))
        let trees = Array(specimens.filter { $0.kind == .tree }.suffix(economical ? 2 : 4))
        // Reserve rare landmarks first when a heavy landscape limits the budget.
        for (slot, items) in [(2,trees),(1,crystals),(0,flowers)] {
            for (rank, item) in items.reversed().enumerated() {
                if Task.isCancelled { return batches }
                let g = GardenDNA.value(item.seed,500)
                // Place the newest rewards in the foreground beside the trail.
                let scale: Float = slot == 2 ? 4.2 : (slot == 0 ? 1.6 : 1.75)
                let foot = placement(rank: rank,kind: item.kind,variation: g,dna: dna,avoiding: occupied)
                let x = foot.x, z = foot.y
                let p = SIMD3<Float>(x,dna.height(x,z)+0.70*scale,z)
                let mesh = build(item,detail: .world)
                guard mesh.triangleCount <= remaining else { continue }
                batches[slot].append(mesh,at: p,scale: scale)
                occupied.append(foot)
                remaining -= mesh.triangleCount
            }
        }
        return batches
    }

    /// The path can curve outside the narrow portrait frustum. Choose an actual
    /// patch of ground beside it that keeps the first rewards in view, clear of
    /// the central guide. Later blooms continue along the meditation route.
    static func placement(rank: Int, kind: GardenKind, variation: Float, dna: MountainWorldDNA,
                          avoiding occupied: [SIMD2<Float>] = []) -> SIMD2<Float> {
        let side: Float = rank%2 == 0 ? -1 : 1
        let offset: Float = kind == .tree ? 8.5+variation : (kind == .flower ? 3.5+variation*0.8 : 5.4+variation*0.7)
        let initialZ: Float = -8-Float(rank/2)*5.5
        guard rank < 6 else {
            let z: Float = -88-Float((rank-6)/2)*3.3
            return [dna.pathX(z)+side*offset,z]
        }
        let eye = dna.cameraPosition
        let forward = simd_normalize(dna.cameraTarget-eye)
        let right = simd_normalize(simd_cross(forward,SIMD3<Float>(0,1,0)))
        let up = simd_cross(right,forward)
        let tangent = tan(Float(55) * .pi/360)
        var best = SIMD2<Float>(dna.pathX(initialZ)+side*offset,initialZ)
        var bestScore: Float = .infinity
        for step in 0..<18 {
            let z = initialZ-Float(step)*4
            for direction: Float in [side,-side] {
                let x = dna.pathX(z)+direction*offset
                let p = SIMD3<Float>(x,dna.height(x,z)+1.5,z)-eye
                let depth = simd_dot(p,forward)
                guard depth > 1 else { continue }
                let nx = simd_dot(p,right)/(depth*tangent*0.46)
                let ny = simd_dot(p,up)/(depth*tangent)
                let outside = max(0,abs(nx)-0.80)*20+max(0,abs(ny)-0.65)*20
                let crowding = occupied.reduce(Float(0)) { max($0,max(0,2.2-simd_distance($1,SIMD2(x,z)))*30) }
                let score = outside+crowding+abs(abs(nx)-0.57)*2+abs(ny+0.19)+Float(step)*0.016
                    + (direction == side ? 0 : 0.05)
                if score < bestScore { bestScore = score; best = [x,z] }
            }
        }
        return best
    }
}
