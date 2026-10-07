import Foundation
import simd

/// Versioned, addressable visual genomes. Six candidates compete on morphology,
/// negative space and novelty; names are labels, never scene templates.
struct MountainWorldDNA: Sendable, Equatable {
    static let version: UInt64 = 9
    let code: UInt64
    let genes: [Float]
    let candidateScore: Float

    init(seed: UInt64, address: MountainPlaceAddress) {
        let count = UInt64(MountainRegionRecipe.PlaceID.allCases.count)
        let ordinal = UInt64(MountainRegionRecipe.PlaceID.allCases.firstIndex(of: address.place)!)
        let step = UInt64(max(0, address.region)) &* count &+ ordinal
        // Independent eight-stop chapters bound reconstruction cost even far into a journey.
        // Every candidate shares a slowly evolving chromatic lineage across chapter edges.
        let chapter = step / 8
        var recent: [[Float]] = []
        var selectedCode: UInt64 = 0
        var selected: [Float] = []
        var selectedScore: Float = 0
        for offset in 0...Int(step % 8) {
            let sequence = chapter &* 8 &+ UInt64(offset)
            var bestScore: Float = -.infinity
            for candidate in 0..<6 {
                let code = Self.mix(seed ^ (sequence &* 0x9E3779B97F4A7C15) ^ (UInt64(candidate+1) &* 0xD1B54A32D192ED03) ^ Self.version)
                var g = (0..<32).map { Self.unit(Self.mix(code &+ UInt64($0)*977)) }
                // Hue is inherited locally, with a continuous drift along the journey.
                let hue = Self.unit(Self.mix(seed &+ 7187)) + Float(sequence % 10000)*0.061
                g[5] = (hue + (g[5]-0.5)*0.14).truncatingRemainder(dividingBy: 1)
                if g[5] < 0 { g[5] += 1 }
                let nearest = recent.map { Self.distance(g,$0) }.min() ?? 0.5
                // A broad open aperture, coherent proportions and quiet foreground beat clutter.
                let composition = Self.compositionScore(g)
                let score = nearest*2 + composition
                if score > bestScore {
                    bestScore=score; selectedCode=code; selected=g; selectedScore=score
                }
            }
            recent.append(selected)
            if recent.count > 3 { recent.removeFirst() }
        }
        code=selectedCode; genes=selected; candidateScore=selectedScore
    }
    private static func compositionScore(_ genes: [Float]) -> Float {
        // Sample the same rounded ridges used by the final terrain, at the
        // edges of a portrait camera's view. Prefer readable layered shoulders
        // without a wall that fills the sky. This is a heuristic, not an art judge.
        var score: Float=0
        for z: Float in [-260,-500,-850] {
            for side: Float in [-1,1] {
                let rise=surroundingHeight(lateral: side * -z * 0.20,z: z,genes: genes)
                score += max(0,1-abs(rise / -z-0.20)*4)
            }
        }
        return score/6*0.36
    }
    static func distance(_ a: [Float],_ b: [Float]) -> Float {
        let indices = [2,8,13,20,21,22,23,24,25,26,27,28,29]
        return indices.reduce(Float(0)) { $0 + abs(a[$1]-b[$1]) } / Float(indices.count)
    }
    static func mix(_ input: UInt64) -> UInt64 {
        var v=input
        v=(v ^ (v >> 30)) &* 0xBF58476D1CE4E5B9
        v=(v ^ (v >> 27)) &* 0x94D049BB133111EB
        return v ^ (v >> 31)
    }
    static func unit(_ v: UInt64) -> Float { Float(v & 0xFFFFFF)/Float(0xFFFFFF) }
    func random(_ index: Int,_ salt: UInt64=0) -> Float {
        Self.unit(Self.mix(code &+ UInt64(bitPattern: Int64(index)) &* 0x9E3779B97F4A7C15 &+ salt))
    }
    static func tint(_ hue: Float,_ saturation: Float,_ value: Float) -> SIMD3<Float> {
        func channel(_ offset: Float) -> Float {
            let h=(hue+offset-floor(hue+offset))*6
            let c=min(1,max(0,abs(h-3)-1))
            return value*((1-saturation)+saturation*c)
        }
        return [channel(0),channel(2.0/3),channel(1.0/3)]
    }
    var titleKey: String { "mountain.wild.name.\(min(7,Int(genes[0]*8)))" }
    var descriptionKey: String { "mountain.wild.description.\(min(3,Int(genes[1]*4)))" }
    // Chromatic mutation stays within a botanical family; sky, stone and leaves
    // have their own pigments instead of rotating the entire world through RGB.
    var hue: Float { 0.70+genes[5]*0.09 }
    var sky: SIMD3<Float> { [0.48+genes[6]*0.06,0.66+genes[6]*0.06,0.83] }
    var haze: SIMD3<Float> { [0.84,0.85,0.91] }
    var floorDNA: MountainFloorDNA { .init(world: self) }
    var lakeLevel: Float { -23 + genes[16]*7 }
    var guide: SIMD3<Float> {
        let x=pathX(-2)
        return [x,height(x,-2)+3.2,-2]
    }
    var cameraPosition: SIMD3<Float> { [pathX(24)+1.5,11.2+genes[27],36] }
    var cameraTarget: SIMD3<Float> { [pathX(-75)*0.65,6,-75] }
    var palette: [SIMD3<Float>] {
        [SIMD3<Float>(0.68,0.61,0.65), // mineral shoulders
         [0.40,0.47,0.32], [0.91,0.79,0.62], // grass, warm trail
         [0.27,0.32,0.25], [0.39,0.49,0.37], [0.57,0.62,0.45],
         floorDNA.color(hue: 0.43),
         [0.95,0.91,0.84], [0.89,0.88,0.90], [0.49,0.48,0.62],
         Self.tint(hue,0.32,0.84), haze, [0.52,0.49,0.55],
         [0.96,0.88,0.76], [0.89,0.67,0.46],
         Self.tint(hue,0.40,0.66), // lavender spikes
         [0.78,0.48+genes[7]*0.10,0.59], [0.95,0.87,0.70],
         [0.52,0.44,0.36], [0.36,0.51,0.44], // bark, shaded jade
         [0.60,0.68,0.48], [0.91,0.72+genes[7]*0.10,0.77]]
    }
    func noise(_ x: Float,_ z: Float) -> Float {
        let ix=Int(floor(x)), iz=Int(floor(z))
        let u=x-Float(ix), v=z-Float(iz)
        let a=u*u*(3-2*u), b=v*v*(3-2*v)
        func n(_ dx: Int,_ dz: Int) -> Float { random((ix+dx) &* 73856093 ^ (iz+dz) &* 19349663) }
        let low=n(0,0)+(n(1,0)-n(0,0))*a
        let high=n(0,1)+(n(1,1)-n(0,1))*a
        return low+(high-low)*b
    }
    func fbm(_ x: Float,_ z: Float) -> Float {
        noise(x,z)*0.57 + noise(x*2.03+8,z*2.03+3)*0.27 + noise(x*4.17-5,z*4.17+7)*0.11 + noise(x*8.31,z*8.31)*0.05
    }
    func pathX(_ z: Float) -> Float {
        // Continuous through the foreground: no fixed phase, mirrored join or guide pad.
        let t = -z/110
        let phase=genes[11]*2*Float.pi
        let frequency=5.1+genes[13]
        // Broad S-curves with independent phase, amplitude and secondary bends.
        // The derivative stays bounded even where two waves reinforce each other.
        return (sin(phase+t*frequency)-sin(phase))*(7+genes[12]*4)
            + (sin(phase*0.73+t*2.8)-sin(phase*0.73))*(3+genes[15]*2)
            + t*(genes[28]-0.5)*8
    }
    /// The integral of a positive, slowly varying grade: every forward step
    /// climbs, while the slope breathes between gentler and steeper stretches.
    func pathHeight(_ z: Float) -> Float {
        let distance = -z
        let grade: Float = 0.115+genes[14]*0.035
        let frequency: Float = 0.022
        let phase = genes[17]*2*Float.pi
        if distance > 400 {
            // The distant climb gently rounds over a crest. Its continuation is
            // hidden by real terrain, rather than ending at a visible mesh edge.
            let beyond=distance-400
            let crestStart=400*grade + 0.025/frequency*(sin(400*frequency+phase)-sin(phase))
            let enteringGrade=grade+0.025*cos(400*frequency+phase)
            return crestStart+enteringGrade*(0.12*beyond+0.88*450*(1-exp(-beyond/450)))
        }
        return distance*grade + 0.025/frequency*(sin(distance*frequency+phase)-sin(phase))
    }
    func height(_ x: Float,_ z: Float) -> Float {
        let lateral=x-pathX(z)
        let floor: Float = -29 + fbm(x*0.026,z*0.026)*7
        let ascent = pathHeight(z)
        let distant=max(0,min(1,(-z-180)/1620))
        let width: Float=34+genes[13]*22+160*distant*distant*(3-2*distant)
            + 8*sin(z*0.017+genes[18]*6)
        let shoulder=exp(-pow(abs(lateral)/width,2))
        let ridge=floor+(ascent-floor)*shoulder
        let surrounding=Self.surroundingHeight(lateral: lateral,z: z,genes: genes)
        let folds=(fbm(x*0.018,z*0.018)-0.5)*(1.0+genes[15]*2.5)
        let edge=min(1,max(0,(abs(lateral)-2)/9))
        // Zero first and second derivatives at the joins soften the shoulder
        // without blurring colours or adding fog over the world.
        let blend=edge*edge*edge*(edge*(edge*6-15)+10)
        return ascent+(ridge+surrounding+folds-ascent)*blend
    }
    /// Long overlapping shoulders grow from the same terrain as the trail.
    /// Root-sum-square joins retain broad ridges without stacking their heights.
    private static func surroundingHeight(lateral: Float,z: Float,genes g: [Float]) -> Float {
        var surrounding: Float=0
        for band in 0..<3 {
            for side: Float in [-1,1] {
                let gene=g[20+band+(side>0 ? 3 : 0)]
                let centre=side*(75+Float(band)*42+gene*30)
                    + sin(z*0.006+gene*6)*(8+Float(band)*8)
                let breadth: Float=40+Float(band)*30+gene*16
                let along=(-z-300-Float(band)*280-Float(band*band)*45-gene*100)/(140+Float(band)*120)
                let crest=(55+Float(band)*95+gene*40)*exp(-along*along)
                let folds=0.88+0.12*cos(z*(0.016-gene*0.004)+gene*9)
                let mass=crest*folds*exp(-pow((lateral-centre)/breadth,2))
                surrounding += mass*mass
            }
        }
        return sqrt(surrounding)
    }
    func normal(_ x: Float,_ z: Float) -> SIMD3<Float> {
        simd_normalize(SIMD3(height(x-0.25,z)-height(x+0.25,z),0.5,height(x,z-0.25)-height(x,z+0.25)))
    }
    func clear(_ x: Float,_ z: Float) -> Bool {
        abs(x-pathX(z)) < 2
    }
}

/// A slow, bounded camera route through the already-built world. Visual time
/// advances only in the foreground; it never controls meditation completion.
struct MountainMeditationJourney {
    let duration: TimeInterval
    init(durationSeconds: Int) { duration=Double(max(300,durationSeconds)) }
    func distance(at elapsed: TimeInterval) -> Float {
        let time=min(duration,max(0,elapsed.isFinite ? elapsed : 0))
        let ramp: Double=6
        let eased=time-ramp*(1-exp(-time/ramp))
        let length=min(300,70+sqrt(duration)*4)
        return Float(length*eased/(duration-ramp*(1-exp(-duration/ramp))))
    }
    func pose(in dna: MountainWorldDNA,elapsed: TimeInterval) -> (position: SIMD3<Float>,target: SIMD3<Float>) {
        let z: Float=8-distance(at: elapsed)
        let ahead=z-18
        return ([dna.pathX(z),dna.pathHeight(z)+6.5,z],
                [dna.pathX(ahead),dna.pathHeight(ahead)+5.1,ahead])
    }
}

/// A bounded implicit scalar field. Domain warping, superelliptic envelopes and
/// intersecting cavities change topology, rather than choosing a prefab object.
/// The exact same field is reused at monumental and botanical scales.
protocol MountainDensityField {
    func value(_ p: SIMD3<Float>) -> Float
    func normal(_ p: SIMD3<Float>) -> SIMD3<Float>
}

/// Grounded, weathered stones share the rounded language of the meadow ridge.
struct MountainBoulderField: MountainDensityField {
    let phase: Float
    func value(_ p: SIMD3<Float>) -> Float {
        simd_length(p/SIMD3<Float>(1.0,0.72,0.88))-0.92
            + sin(p.x*3+phase)*sin(p.z*3)*0.035
    }
    func normal(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let h: Float=0.002
        let n=SIMD3(value(p+[h,0,0])-value(p-[h,0,0]),
                    value(p+[0,h,0])-value(p-[0,h,0]),
                    value(p+[0,0,h])-value(p-[0,0,h]))
        return simd_length_squared(n)>0.0000001 ? simd_normalize(n) : SIMD3(0,1,0)
    }
}

struct MountainFormField: Sendable, MountainDensityField {
    let genes: [Float]
    let variation: Float
    init(dna: MountainWorldDNA,variation: Float) { self.genes=dna.genes; self.variation=variation }
    init(genes: [Float],variation: Float) { self.genes=genes; self.variation=variation }
    var aperture: Float { min(0.62,max(0,genes[20]*0.78-0.10+(variation-0.5)*0.12)) }
    func value(_ p: SIMD3<Float>) -> Float {
        let g=genes
        var q=p
        let twist=(g[22]-0.5)*1.7*q.y
        let cs=cos(twist), sn=sin(twist)
        q.x=p.x*cs-p.z*sn + sin(p.y*2.7+variation*4)*(0.08+g[23]*0.17)
        q.z=p.x*sn+p.z*cs
        q.x += sin(q.y*4+q.z*2.5)*g[24]*0.028
        let taper=0.84+0.16*cos(q.y*2.1+g[25]*3)
        // Rounded envelopes with broad folds, avoiding pinched, squared crowns.
        let exponent: Float=2.0+g[26]*0.2
        let body=pow(pow(abs(q.x/taper),exponent)+pow(abs(q.y/1.22),exponent)+pow(abs(q.z/0.62),exponent),1/exponent)-0.92
        let folds=sin(q.x*(4+g[25]*4)+q.y*2)*sin(q.z*4-q.y*2)*(0.003+g[24]*0.004)
        var result=body+folds
        // Branches are part of the density field, so they fuse into the parent
        // mass and can merge into arches when the cavities cut through them.
        for branch in 0..<(1+Int(g[23]*3)) {
            let angle=Float(branch)*2.399+variation*2
            let reach: Float=0.35+g[23]*0.32
            let origin=SIMD3<Float>(cos(angle)*reach,0.46+g[28]*0.12,sin(angle)*reach*0.64)
            let radii=SIMD3<Float>(0.26+g[24]*0.13,0.46+g[25]*0.18,0.25+g[24]*0.08)
            let limb=(simd_length((q-origin)/radii)-1)*0.34
            result = -smoothMaximum(-result,-limb,0.18)
        }
        // Cavities can stay enclosed, pierce the envelope or split its crown.
        let cx=(variation-0.5)*0.43
        let cy: Float = -0.15+g[29]*0.65
        let hole=simd_length(SIMD2((q.x-cx)/(0.10+aperture*0.70),(q.y-cy)/(0.16+aperture*0.93)))-1
        result=smoothMaximum(result,-hole*0.38,0.12)
        let crossHole=simd_length(SIMD2((q.z+0.1)/(0.10+g[30]*0.28),(q.y+0.38)/(0.12+g[31]*0.36)))-1
        if g[30] > 0.55 { result=smoothMaximum(result,-crossHole*0.23,0.08) }
        return result
    }
    private func smoothMaximum(_ a: Float,_ b: Float,_ k: Float) -> Float {
        let h=min(1,max(0,0.5+0.5*(a-b)/k))
        return b+(a-b)*h+k*h*(1-h)
    }
    func normal(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let h: Float=0.002
        let n=SIMD3(value(p+[h,0,0])-value(p-[h,0,0]),
                    value(p+[0,h,0])-value(p-[0,h,0]),
                    value(p+[0,0,h])-value(p-[0,0,h]))
        return simd_length_squared(n)>0.0000001 ? simd_normalize(n) : SIMD3(0,1,0)
    }
}

/// Smoothly joined billows produce a solid cloud bank with a soft silhouette.
/// These clouds live above the terrain; the distant ridge hides the trail endpoint.
struct MountainCloudField: MountainDensityField {
    let lobes: [SIMD4<Float>]
    init(dna: MountainWorldDNA,index: Int) {
        lobes=(0..<7).map { i in
            let key=i+index*13
            let direction: Float=dna.random(index,8804)<0.5 ? -1 : 1
            let x=(Float(i%4)*0.56-0.84+(dna.random(key,8805)-0.5)*0.12)*direction
            let y: Float=i<4 ? -0.16 : 0.14+dna.random(key,8801)*0.42
            return [x,y,(dna.random(key,8802)-0.5)*0.48,0.42+dna.random(key,8803)*0.17]
        }
    }
    func value(_ p: SIMD3<Float>) -> Float {
        var result: Float=10
        for lobe in lobes {
            let d=simd_length(p-SIMD3(lobe.x,lobe.y,lobe.z))-lobe.w
            let blend=max(0,0.12-abs(result-d))/0.12
            result=min(result,d)-blend*blend*0.03
        }
        return result
    }
    func normal(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let h: Float=0.002
        let n=SIMD3(value(p+[h,0,0])-value(p-[h,0,0]),
                    value(p+[0,h,0])-value(p-[0,h,0]),
                    value(p+[0,0,h])-value(p-[0,0,h]))
        return simd_length_squared(n)>0.0000001 ? simd_normalize(n) : SIMD3(0,1,0)
    }
}

/// Related local species share a world's palette and curvature, but mutate
/// branching, leaf profile, phyllotaxy, bloom shape and growth habit independently.
struct MountainFloraDNA: Sendable, Equatable {
    let traits: [Float]
    init(world: MountainWorldDNA,species: Int) {
        traits=(0..<16).map { index in
            let inherited=world.genes[(index+7)%32]
            return inherited*0.35+world.random(species*97+index,8093)*0.65
        }
    }
    var stems: Int { 1+Int(traits[0]*3.9) }
    var spread: Float { 0.12+traits[1]*0.30 }
    var leafWidth: Float { 0.09+traits[2]*0.44 }
    var leafTaper: Float { 0.45+traits[3]*1.7 }
    var lobes: Int { 2+Int(traits[4]*6) }
    var incision: Float { max(0,traits[5]-0.3)*0.95 }
    var curl: Float { (traits[6]-0.35)*0.6 }
    var droop: Float { traits[7]*0.48 }
    var petals: Int { 5+Int(traits[8]*5) }
    var cup: Float { 0.16+traits[9]*0.60 }
    var petalWidth: Float { 0.34+traits[10]*0.46 }
    var bloom: Float { traits[11] }
    var rosette: Float { traits[12] }
}

/// Material families share continuous genes for relief, spacing and wind.
/// This describes the valley beneath the trail, never the walkable path itself.
struct MountainFloorDNA: Sendable, Equatable {
    enum Material: Int, CaseIterable { case water, dunes, moss, mineral }
    let material: Material
    let energy: Float
    let variation: Float
    init(world: MountainWorldDNA) {
        material = Material(rawValue: min(3,Int(world.random(0,9201)*4)))!
        energy = world.random(1,9201)
        variation = world.random(2,9201)
    }
    var waveStrength: Float { material == .water ? max(0,(energy-0.28)/0.72) : 0 }
    var shaderTraits: SIMD2<Float> { [Float(material.rawValue)+energy*0.9,variation] }
    func color(hue: Float) -> SIMD3<Float> {
        switch material {
        case .water: MountainWorldDNA.tint(hue+0.08+variation*0.10,0.48,0.55)
        case .dunes: MountainWorldDNA.tint(hue+0.13+variation*0.12,0.28+energy*0.15,0.76)
        case .moss: MountainWorldDNA.tint(hue+0.29+variation*0.12,0.5,0.48)
        case .mineral: MountainWorldDNA.tint(hue-0.08+variation*0.12,0.18+energy*0.25,0.8)
        }
    }
    func relief(_ x: Float,_ z: Float) -> Float {
        let a=variation*2 * Float.pi
        let u=x*cos(a)+z*sin(a),v = -x*sin(a)+z*cos(a)
        let frequency: Float=0.025+variation*0.04
        let wave=sin(u*frequency+sin(v*frequency*0.43)*1.3)
        switch material {
        case .water: return 0
        case .dunes: return (1+wave)*(1.0+energy*2.5)
        case .moss: return (sin(u*0.025)+cos(v*0.035)+2)*(0.5+energy*0.85)
        case .mineral: return pow(abs(wave),0.5+variation)*(2+energy*5)
        }
    }
    func normal(_ x: Float,_ z: Float) -> SIMD3<Float> {
        let d: Float=0.25
        return simd_normalize(SIMD3(relief(x-d,z)-relief(x+d,z),2*d,relief(x,z-d)-relief(x,z+d)))
    }
}

enum MountainWildMesh {
    static let horizonDistance: Float = 2400

    /// Shared longitudinal samples keep the path on the rendered terrain, even
    /// where distant cells become large. No extra entities or material batches.
    static func ridgeRows(economical: Bool) -> [Float] {
        var rows=Array(stride(from: -horizonDistance,to: -1000,by: 20 as Float))
        rows += Array(stride(from: -1000 as Float,to: -500,by: 8))
        rows += Array(stride(from: -500 as Float,to: -48,by: 4))
        rows += Array(stride(from: -48 as Float,through: 32,by: economical ? 2 : 1))
        rows += [36,40,46,54,64]
        return rows
    }

    static func build(_ dna: MountainWorldDNA,economical: Bool) -> [MountainMeshBatch] {
        var b=Array(repeating: MountainMeshBatch(),count: dna.palette.count)
        terrain(dna,economical: economical,batch: &b[12])
        trail(dna,economical: economical,batch: &b[2])
        // The shared terrain now includes the distant mountain ranges. Reserve
        // implicit meshes for small foreground stones, not disconnected towers.
        clouds(dna,economical: economical,batch: &b[11])
        valleyFloor(dna,economical: economical,batch: &b[6])
        grove(dna,economical: economical,b: &b)
        // Quiet foreground: do not generate small shrubs or grass. The full
        // trees remain; earned botanical specimens live only in the collection.
        // Sparse field-grown minerals echo the same holes and folds at human scale.
        for i in 0..<5 {
            let z: Float=7-Float(i)*17
            let x=dna.pathX(z)+(i%2==0 ? -1 : 1)*(9+dna.random(i,401)*4)
            let y=dna.height(x,z)
            guard y>dna.lakeLevel+1 else { continue }
            let h: Float=0.45+dna.random(i,402)*0.9
            var mineral=MountainMeshBatch()
            implicit(MountainBoulderField(phase: dna.random(i,403)*6),center: [x,y+h*0.35,z],scale: [h*1.4,h,h*1.2],
                     yaw: dna.random(i,404)*6,resolution: economical ? 9 : 13,batch: &mineral)
            clearTrail(dna,formation: &mineral,side: i%2==0 ? -1 : 1,clearance: 3)
            b[0].positions += mineral.positions; b[0].normals += mineral.normals
        }
        return b
    }

    /// Sparse, seeded leafy groves. Whole-tree bounds protect the curved
    /// trail, including branch interiors and the complete crown, not just roots.
    private static func grove(_ dna: MountainWorldDNA,economical: Bool,b: inout [MountainMeshBatch]) {
        let used=b.reduce(0) { $0+$1.positions.count/3 }
        var remaining=max(0,min(economical ? 8500 : 19000,205000-used))
        var accepted: [SIMD3<Float>]=[]
        for i in 0..<22 {
            if Task.isCancelled || remaining<800 { break }
            let z=10-Float(i)*17-dna.random(i,9701)*20
            let side: Float=dna.random(i,9702)<0.5 ? -1 : 1
            let h=5.8+dna.random(i,9703)*4.2
            let x=dna.pathX(z)+side*(7+h*0.7+dna.random(i,9704)*9)
            let p=SIMD3<Float>(x,dna.height(x,z)-0.12,z)
            guard p.y>dna.lakeLevel+2,dna.normal(x,z).y>0.70,
                  accepted.allSatisfy({ simd_distance($0,p)>11 }) else { continue }
            var tree=Array(repeating: MountainMeshBatch(),count: b.count)
            treeGeometry(at: p,height: h,phase: dna.random(i,9705)*6,
                         flowering: 0,detail: !economical && z > -100,b: &tree)
            let cost=tree.reduce(0) { $0+$1.positions.count/3 }
            guard cost<=remaining,treeClearsTrail(tree,dna: dna,side: side) else { continue }
            for index in 18...21 {
                b[index].positions += tree[index].positions
                b[index].normals += tree[index].normals
            }
            remaining-=cost; accepted.append(p)
        }
    }

    private static func treeClearsTrail(_ tree: [MountainMeshBatch],dna: MountainWorldDNA,side: Float) -> Bool {
        var low=SIMD3<Float>(repeating: .infinity),high=SIMD3<Float>(repeating: -.infinity)
        for batch in tree[18...21] { for p in batch.positions {
            low=simd_min(low,p); high=simd_max(high,p)
        } }
        guard low.x.isFinite else { return false }
        let samples=max(1,Int(ceil(high.z-low.z)))
        for i in 0...samples {
            let path=dna.pathX(low.z+(high.z-low.z)*Float(i)/Float(samples))
            // The path's derivative is bounded by 0.8; half a sample of margin
            // protects the unsampled intervals as well as triangle interiors.
            if side>0 ? low.x<path+3.9 : high.x>path-3.9 { return false }
        }
        return true
    }

    private static func treeGeometry(at p: SIMD3<Float>,height h: Float,phase: Float,
                                     flowering: Float,detail: Bool,b: inout [MountainMeshBatch]) {
        let lean=SIMD3<Float>(cos(phase)*h*0.08,0,sin(phase)*h*0.05)
        func trunk(_ t: Float) -> SIMD3<Float> { p+lean*(t*t)+[0,h*t,0] }
        for j in 0..<7 {
            let t=Float(j)/9,u=Float(j+1)/9
            tube(from: trunk(t),to: trunk(u),r0: h*(0.045-0.037*t),r1: h*(0.045-0.037*u),batch: &b[18])
        }
        let limbs=detail ? 7 : 5
        for limb in 0..<limbs {
            let t=Float(limb)/Float(limbs-1)
            let angle=phase+Float(limb)*2.399
            let direction=SIMD3<Float>(cos(angle),0,sin(angle))
            let root=trunk(0.38+t*0.30)
            let tip=trunk(0.67+t*0.24)+direction*(h*(0.40-t*0.21))
            let elbow=root+direction*h*0.12+[0,h*0.16,0]
            var previous=root
            for j in 1...5 {
                let u=Float(j)/5
                let next=root*((1-u)*(1-u))+elbow*(2*u*(1-u))+tip*(u*u)
                tube(from: previous,to: next,r0: h*0.020*(1-u)+0.025,r1: h*0.018*(1-u)+0.016,batch: &b[18])
                previous=next
            }
            let radius=h*(0.25-t*0.07)
            let pigment=flowering>0.35 && limb%3 != 0 ? 21 : 19+limb%2
            crown(at: tip,radii: [radius,radius*(0.46+flowering*0.12),radius*0.82],
                  phase: angle,detail: detail,batch: &b[pigment])
            // Rounded, offset lobes keep a soft outline. Separate pointed leaf
            // quads read as thorns through the translucent canopy, so omit them.
            for k in 0..<(detail ? 3 : 2) {
                let azimuth=angle+Float(k)*2.2
                let offset=SIMD3<Float>(cos(azimuth),0.14,sin(azimuth))*radius*0.67
                crown(at: tip+offset,radii: [radius*0.46,radius*0.30,radius*0.43],
                      phase: azimuth,detail: false,batch: &b[k%2==0 ? pigment : 20])
            }
        }
    }

    private static func crown(at centre: SIMD3<Float>,radii: SIMD3<Float>,phase: Float,
                              detail: Bool,batch: inout MountainMeshBatch) {
        let rings=detail ? 7 : 4,segments=detail ? 12 : 8
        func point(_ latitude: Float,_ longitude: Float) -> SIMD3<Float> {
            let lobes=1+0.075*sin(longitude*5+phase)*sin(latitude)*sin(latitude)
            let radial=sin(latitude)*lobes
            return centre+SIMD3<Float>(radial*cos(longitude),cos(latitude),radial*sin(longitude))*radii
        }
        func sample(_ row: Int,_ column: Int) -> (SIMD3<Float>,SIMD3<Float>) {
            let u=Float(row)/Float(rings)*Float.pi,v=Float(column)/Float(segments)*2*Float.pi
            let p=point(u,v)
            if row==0 { return (p,[0,1,0]) }
            if row==rings { return (p,[0,-1,0]) }
            let du=point(u+0.002,v)-point(u-0.002,v)
            let dv=point(u,v+0.002)-point(u,v-0.002)
            return (p,simd_normalize(simd_cross(dv,du)))
        }
        let grid=(0...rings).map { row in (0...segments).map { sample(row,$0) } }
        for row in 0..<rings { for col in 0..<segments {
            let a=grid[row][col],c=grid[row][col+1],d=grid[row+1][col+1],e=grid[row+1][col]
            smoothTriangle(a.0,c.0,d.0,a.1,c.1,d.1,batch: &batch)
            smoothTriangle(a.0,d.0,e.0,a.1,d.1,e.1,batch: &batch)
        } }
    }

    /// Marching tetrahedra avoids a large case table, permits holes/overhangs,
    /// and produces smooth field-gradient normals independent of triangulation.
    private static func implicit<Field: MountainDensityField>(_ field: Field,center: SIMD3<Float>,scale: SIMD3<Float>,
                                 yaw: Float,resolution n: Int,batch: inout MountainMeshBatch) {
        let size=n+1, step: Float=3.2/Float(n)
        let cs=cos(yaw),sn=sin(yaw)
        func rotate(_ p: SIMD3<Float>) -> SIMD3<Float> { [p.x*cs-p.z*sn,p.y,p.x*sn+p.z*cs] }
        func point(_ x: Int,_ y: Int,_ z: Int) -> SIMD3<Float> { SIMD3(Float(x),Float(y),Float(z))*step-SIMD3(repeating: 1.6) }
        func index(_ x: Int,_ y: Int,_ z: Int) -> Int { (z*size+y)*size+x }
        var samples=Array(repeating: Float(0),count: size*size*size)
        for z in 0...n { for y in 0...n { for x in 0...n { samples[index(x,y,z)]=field.value(point(x,y,z)) } } }
        let corners=[SIMD3(0,0,0),SIMD3(1,0,0),SIMD3(1,1,0),SIMD3(0,1,0),SIMD3(0,0,1),SIMD3(1,0,1),SIMD3(1,1,1),SIMD3(0,1,1)]
        let tetrahedra=[[0,5,1,6],[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6]]
        func emit(_ a: SIMD3<Float>,_ c: SIMD3<Float>,_ d: SIMD3<Float>) {
            let pa=center+rotate(a*scale), pc=center+rotate(c*scale), pd=center+rotate(d*scale)
            let na=simd_normalize(rotate(field.normal(a)/scale))
            let nc=simd_normalize(rotate(field.normal(c)/scale))
            let nd=simd_normalize(rotate(field.normal(d)/scale))
            if simd_dot(simd_cross(pc-pa,pd-pa),na+nc+nd)<0 {
                smoothTriangle(pa,pd,pc,na,nd,nc,batch: &batch)
            } else { smoothTriangle(pa,pc,pd,na,nc,nd,batch: &batch) }
        }
        for z in 0..<n {
            if Task.isCancelled { return }
            for y in 0..<n { for x in 0..<n {
                let values=corners.map { samples[index(x+$0.x,y+$0.y,z+$0.z)] }
                if values.allSatisfy({ $0>=0 }) || values.allSatisfy({ $0<0 }) { continue }
                let points=corners.map { point(x+$0.x,y+$0.y,z+$0.z) }
                func edge(_ a: Int,_ b: Int) -> SIMD3<Float> {
                    let t=values[a]/(values[a]-values[b])
                    return points[a]+(points[b]-points[a])*t
                }
                for tetra in tetrahedra {
                    let inside=tetra.filter { values[$0]<0 }, outside=tetra.filter { values[$0]>=0 }
                    if inside.count==1 {
                        emit(edge(inside[0],outside[0]),edge(inside[0],outside[1]),edge(inside[0],outside[2]))
                    } else if inside.count==3 {
                        emit(edge(outside[0],inside[0]),edge(outside[0],inside[1]),edge(outside[0],inside[2]))
                    } else if inside.count==2 {
                        let a=edge(inside[0],outside[0]),c=edge(inside[0],outside[1])
                        let d=edge(inside[1],outside[1]),e=edge(inside[1],outside[0])
                        emit(a,c,d); emit(a,d,e)
                    }
                }
            } }
        }
    }

    private static func clearTrail(_ dna: MountainWorldDNA,formation: inout MountainMeshBatch,
                                   side: Float,clearance: Float) {
        guard let first=formation.positions.first else { return }
        var low=first,high=first
        for p in formation.positions { low=simd_min(low,p); high=simd_max(high,p) }
        var minimum=Float.infinity,maximum = -Float.infinity
        // Include both ends and a derivative margin between samples. Protect
        // the entire bounding volume, including triangle interiors/overhangs.
        let count=max(1,Int(ceil((high.z-low.z)/2)))
        for i in 0...count {
            let x=dna.pathX(low.z+(high.z-low.z)*Float(i)/Float(count))
            minimum=min(minimum,x); maximum=max(maximum,x)
        }
        let shift=side>0 ? max(0,maximum+clearance+0.8-low.x)
                         : min(0,minimum-clearance-0.8-high.x)
        for i in formation.positions.indices { formation.positions[i].x += shift }
    }

    private static func clouds(_ dna: MountainWorldDNA,economical: Bool,batch: inout MountainMeshBatch) {
        let forward=simd_normalize(dna.cameraTarget-dna.cameraPosition)
        let right=simd_normalize(simd_cross(forward,SIMD3<Float>(0,1,0)))
        let up=simd_cross(right,forward)
        for i in 0..<3 {
            if Task.isCancelled { return }
            // Airy, separated cloudlets in the upper view. They remain world
            // geometry, so camera travel passes beneath them naturally.
            let distance: Float=360+Float(i)*125+dna.random(i,8810)*65
            let across=(Float(i)-1)*0.13+(dna.random(i,8811)-0.5)*0.05
            let elevation: Float=0.30+dna.random(i,8812)*0.07
            var centre=dna.cameraPosition+forward*distance+right*(across*distance)+up*(elevation*distance)
            let scale=SIMD3<Float>(18+dna.random(i,8813)*12,
                                    12+dna.random(i,8814)*7,
                                    16+dna.random(i,8815)*10)
            // Check the complete extraction volume, not only the cloud centre.
            // Rotation is bounded by the x/z diagonal. Lifting the entire cloud
            // preserves its shape and prevents any white patches on the slopes.
            let footprint=1.6*sqrt(scale.x*scale.x+scale.z*scale.z)
            let samples=Int(ceil(footprint*2/4))
            var summit = -Float.infinity
            for row in 0...samples { for column in 0...samples {
                let x=centre.x-footprint+2*footprint*Float(column)/Float(samples)
                let z=centre.z-footprint+2*footprint*Float(row)/Float(samples)
                summit=max(summit,dna.height(x,z))
            } }
            centre.y=max(centre.y,summit+40+scale.y*1.6)
            implicit(MountainCloudField(dna: dna,index: i),center: centre,scale: scale,
                     yaw: (dna.random(i,8816)-0.5)*0.30,resolution: economical ? 16 : 24,batch: &batch)
        }
    }

    private static func appendFlora(_ plant: [MountainMeshBatch],to batches: inout [MountainMeshBatch],remaining: inout Int,dna: MountainWorldDNA) {
        let cost=plant.reduce(0) { $0+$1.positions.count/3 }
        guard cost<=remaining else { return }
        // Check the full canopy, not only its root, before accepting a specimen.
        guard !plant.contains(where: { batch in
            batch.positions.contains { abs($0.x-dna.pathX($0.z))<1.2 }
        }) else { return }
        for index in plant.indices {
            batches[index].positions.append(contentsOf: plant[index].positions)
            batches[index].normals.append(contentsOf: plant[index].normals)
        }
        remaining-=cost
    }
    private static func botanical(at p: SIMD3<Float>,height h: Float,phase: Float,flora: MountainFloraDNA,
                                  detail: Bool,b: inout [MountainMeshBatch]) {
        let joints=detail ? 6 : 4
        for stem in 0..<flora.stems {
            let azimuth=phase+Float(stem)*2.399
            let direction=SIMD3<Float>(cos(azimuth),0,sin(azimuth))
            let height=h*(1-Float(stem)*0.12)
            func point(_ t: Float) -> SIMD3<Float> {
                let sweep=direction*(sin(t*1.5)*height*flora.spread)
                return p+sweep+[0,height*t*(1-flora.rosette*0.35),0]
            }
            var previous=p
            for joint in 1...joints {
                let t=Float(joint)/Float(joints),center=point(t)
                tube(from: previous,to: center,r0: h*0.015*(1-t)+0.012,r1: h*0.012*(1-t)+0.006,batch: &b[3])
                previous=center
                if joint<2 { continue }
                let whorl=flora.rosette>0.58 ? 3 : 2
                for k in 0..<whorl {
                    let angle=azimuth+Float(joint)*(1.4+flora.traits[13]*1.4)+Float(k)*2*Float.pi/Float(whorl)
                    let outward=SIMD3<Float>(cos(angle),0.15+flora.traits[14]*0.6,sin(angle))
                    let length=height*(0.22+flora.rosette*0.18)*(1-t*0.45)
                    leaf(from: center,direction: outward,length: length,flora: flora,detail: detail,batch: &b[4+(joint+k)%2])
                }
            }

        }
    }
    private static func leaf(from origin: SIMD3<Float>,direction: SIMD3<Float>,length: Float,
                             flora: MountainFloraDNA,detail: Bool,batch: inout MountainMeshBatch) {
        let axis=simd_normalize(direction)
        let side=simd_normalize(simd_cross(axis,SIMD3<Float>(0,1,0)))
        func point(_ u: Float,_ v: Float) -> SIMD3<Float> {
            let profile=pow(max(0,sin(u * .pi)),flora.leafTaper)
            let lobes=1-flora.incision*(0.5+0.5*cos(u*Float(flora.lobes)*2 * .pi))
            let width=length*flora.leafWidth*profile*lobes
            let arch=length*(sin(u * .pi)*flora.curl-u*u*flora.droop)
            let fold=abs(v)*abs(v)*length*0.09*sin(u * .pi)
            return origin+axis*(length*u)+side*(width*v)+[0,arch-fold,0]
        }
        curvedSurface(rows: detail ? 9 : 5,columns: detail ? 3 : 2,point: point,batch: &batch)
    }
    /// A curved sheet with shared analytic sample positions and finite-difference
    /// normals. Leaves/petals are deliberately double-sided in the scene renderer.
    private static func curvedSurface(rows: Int,columns: Int,point: (Float,Float)->SIMD3<Float>,batch: inout MountainMeshBatch) {
        func sample(_ row: Int,_ column: Int) -> (SIMD3<Float>,SIMD3<Float>) {
            let u=Float(row)/Float(rows),v=Float(column)/Float(columns)*2-1
            let du=point(min(1,u+0.002),v)-point(max(0,u-0.002),v)
            let dv=point(u,min(1,v+0.002))-point(u,max(-1,v-0.002))
            let cross=simd_cross(dv,du)
            let n=simd_length_squared(cross)>0.0000000001 ? simd_normalize(cross) : SIMD3<Float>(0,1,0)
            return (point(u,v),n)
        }
        let grid=(0...rows).map { row in (0...columns).map { sample(row,$0) } }
        for row in 0..<rows { for column in 0..<columns {
            let a=grid[row][column],c=grid[row][column+1],d=grid[row+1][column+1],e=grid[row+1][column]
            smoothTriangle(a.0,c.0,d.0,a.1,c.1,d.1,batch: &batch)
            smoothTriangle(a.0,d.0,e.0,a.1,d.1,e.1,batch: &batch)
        } }
    }
    private static func smoothTriangle(_ a: SIMD3<Float>,_ c: SIMD3<Float>,_ d: SIMD3<Float>,
                                       _ na: SIMD3<Float>,_ nc: SIMD3<Float>,_ nd: SIMD3<Float>,batch: inout MountainMeshBatch) {
        guard simd_length_squared(simd_cross(c-a,d-a)) > 0.00000001 else { return }
        batch.positions += [a,c,d]; batch.normals += [na,nc,nd]
    }
    private static func terrain(_ dna: MountainWorldDNA,economical: Bool,batch: inout MountainMeshBatch) {
        // Nonuniform grid: fine in the foreground, progressively coarser far away,
        // with shared vertices and normals rather than disconnected terrain tiles.
        let step: Float = economical ? 2 : 1
        var xs: [Float] = [-1000,-850,-720,-620,-530,-455,-390,-335,-285,-240,-200,-168,-144]
        xs += Array(stride(from: -120 as Float,to: -32,by: 4))
        xs += Array(stride(from: -32 as Float,through: 32,by: step))
        xs += Array(stride(from: 36 as Float,through: 120,by: 4))
        xs += [144,168,200,240,285,335,390,455,530,620,720,850,1000]
        let zs=ridgeRows(economical: economical)
        // Follow the meander so the finest cells always support the trail,
        // including bends that move outside the old fixed central grid.
        let vertices = zs.map { z in xs.map { offset in
            // Broaden the distant mountain beneath the continuation, preserving
            // the flat central corridor and all foreground proportions.
            let spread=max(0,-z-180)*0.0005
            let lateral=offset*(1+spread*max(0,min(118,abs(offset)-2))/118)
            let x=lateral+dna.pathX(z)
            return SIMD3(x,dna.height(x,z),z)
        } }
        let normals = vertices.map { row in row.map { dna.normal($0.x,$0.z) } }
        for row in 0..<zs.count-1 {
            if Task.isCancelled { return }
            for col in 0..<xs.count-1 {
                let a=vertices[row][col],c=vertices[row+1][col],d=vertices[row+1][col+1],e=vertices[row][col+1]
                let na=normals[row][col],nc=normals[row+1][col],nd=normals[row+1][col+1],ne=normals[row][col+1]
                smoothTriangle(a,c,d,na,nc,nd,batch: &batch)
                smoothTriangle(a,d,e,na,nd,ne,batch: &batch)
            }
        }
    }
    private static func trail(_ dna: MountainWorldDNA,economical: Bool,batch: inout MountainMeshBatch) {
        let rows=Array(ridgeRows(economical: economical).filter { $0<=30 }.reversed())
        for i in 0..<rows.count-1 {
            let z=rows[i], next=rows[i+1]
            func p(_ z: Float,_ side: Float) -> SIMD3<Float> {
                // Evaluate width at the vertex, so adjacent segments meet exactly.
                let w: Float = 0.95+0.09*sin(z*0.12+dna.genes[12]*6)
                let x = dna.pathX(z)+side*w
                return [x,dna.height(x,z)+0.10,z]
            }
            let a=p(z,-1),c=p(z,1),d=p(next,1),e=p(next,-1)
            smoothTriangle(a,c,d,dna.normal(a.x,a.z),dna.normal(c.x,c.z),dna.normal(d.x,d.z),batch: &batch)
            smoothTriangle(a,d,e,dna.normal(a.x,a.z),dna.normal(d.x,d.z),dna.normal(e.x,e.z),batch: &batch)
        }
    }
    private static func tube(from a: SIMD3<Float>,to c: SIMD3<Float>,r0: Float,r1: Float,batch: inout MountainMeshBatch) {
        let axis=simd_normalize(c-a)
        let tangent=simd_normalize(simd_cross(axis,abs(axis.y)<0.9 ? [0,1,0] : [1,0,0]))
        let bitangent=simd_cross(axis,tangent)
        for i in 0..<7 {
            let u=Float(i)*2*Float.pi/7,v=Float(i+1)*2*Float.pi/7
            let n=cos(u)*tangent+sin(u)*bitangent,m=cos(v)*tangent+sin(v)*bitangent
            smoothTriangle(a+n*r0,c+m*r1,a+m*r0,n,m,m,batch: &batch)
            smoothTriangle(a+n*r0,c+n*r1,c+m*r1,n,n,m,batch: &batch)
        }
    }
    private static func grass(at p: SIMD3<Float>,height h: Float,phase: Float,b: inout [MountainMeshBatch]) {
        for i in 0..<5 {
            let a=phase+Float(i)*2.399
            let direction=SIMD3<Float>(cos(a),0,sin(a))
            let side=SIMD3<Float>(-sin(a),0,cos(a))
            let foot=p+direction*0.07
            let height=h*(0.7+Float(i%3)*0.12)
            // Three curved ribbon segments replace rigid triangular prongs.
            func point(_ t: Float,_ edge: Float) -> SIMD3<Float> {
                foot+direction*(t*t*h*0.44)+[0,height*(t-0.16*t*t),0]
                    + side*(edge*0.036*(1-t))
            }
            for segment in 0..<3 {
                let t=Float(segment)/3,u=Float(segment+1)/3
                b[1].quad(point(t,-1),point(t,1),point(u,1),point(u,-1))
            }
        }
    }
    private static func valleyFloor(_ dna: MountainWorldDNA,economical: Bool,batch: inout MountainMeshBatch) {
        let floor=dna.floorDNA
        let count=floor.material == .water ? 2 : (economical ? 32 : 64)
        let grid=(0...count).map { row in
            (0...count).map { col -> (SIMD3<Float>,SIMD3<Float>) in
                let x = -600+Float(col)/Float(count)*1200
                let z = -750+Float(row)/Float(count)*1000
                return ([x,dna.lakeLevel+floor.relief(x,z),z],floor.normal(x,z))
            }
        }
        for row in 0..<count {
            if Task.isCancelled { return }
            for col in 0..<count {
                let a=grid[row][col],c=grid[row+1][col],d=grid[row+1][col+1],e=grid[row][col+1]
                smoothTriangle(a.0,c.0,d.0,a.1,c.1,d.1,batch: &batch)
                smoothTriangle(a.0,d.0,e.0,a.1,d.1,e.1,batch: &batch)
            }
        }
    }
}

/// Stylized clock-based light, not an astronomical/location-based solar model.
/// Dawn is 06:00, noon 12:00, dusk 19:00 in the device's current time zone.
struct MountainDaylight: Equatable, Sendable {
    let hour: Float
    init(hour: Float) {
        let finite=hour.isFinite ? hour : 12
        self.hour=(finite.truncatingRemainder(dividingBy: 24)+24).truncatingRemainder(dividingBy: 24)
    }
    init(date: Date,calendar: Calendar = .current) {
        let parts=calendar.dateComponents([.hour,.minute,.second],from: date)
        self.init(hour: Float(parts.hour ?? 12)+Float(parts.minute ?? 0)/60+Float(parts.second ?? 0)/3600)
    }
    var angle: Float {
        // A 13-hour day (06–19), followed by an 11-hour night. Keep the same
        // phase mapping in MountainAtmosphere.metal for sky/material agreement.
        let elapsed=(hour+18).truncatingRemainder(dividingBy: 24)
        return elapsed <= 13 ? elapsed/13 * .pi : .pi+(elapsed-13)/11 * .pi
    }
    var elevation: Float { sin(angle) }
    var daylight: Float {
        let t=min(1,max(0,(elevation+0.15)/0.45))
        return t*t*(3-2*t)
    }
    var twilight: Float { exp(-pow(elevation/0.24,2)) }
    var sunDirection: SIMD3<Float> { simd_normalize([-cos(angle)*0.85,elevation,0.4]) }
    var lightDirection: SIMD3<Float> { elevation >= 0 ? sunDirection : -sunDirection }
    var sunVisibility: Float {
        let t=min(1,max(0,(elevation+0.04)/0.10))
        return t*t*(3-2*t)
    }
    var moonVisibility: Float {
        let t=min(1,max(0,(-elevation-0.01)/0.15))
        return t*t*(3-2*t)
    }
    func orbPosition(moon: Bool) -> SIMD2<Float> {
        let wrapped=(angle / .pi + (moon ? 1 : 0)).truncatingRemainder(dividingBy: 2)
        // Sunrise begins fading in slightly before phase zero. Unwrap that
        // interval so the orb enters on the left instead of jumping across.
        let phase=wrapped>1.5 ? wrapped-2 : wrapped
        // The portrait landscape's skyline is well above the old 57% screen
        // horizon. Keep the visible arc in the sky instead of letting it travel
        // through the foreground ridge at dawn/dusk. Visibility and scene light
        // still follow civil time; the opaque terrain can naturally occlude it.
        let altitude=max(0,sin(phase * .pi))
        return [0.12+0.76*phase,0.235-0.065*pow(altitude,0.65)]
    }
    func sky(_ dna: MountainWorldDNA) -> SIMD3<Float> {
        let day=dna.sky
        return simd_mix([0.018,0.028,0.070],day,SIMD3(repeating: daylight))
    }
    func haze(_ dna: MountainWorldDNA) -> SIMD3<Float> {
        let base=simd_mix(SIMD3<Float>(0.055,0.075,0.14),dna.haze,SIMD3(repeating: daylight))
        return simd_mix(base,SIMD3<Float>(0.86,0.46,0.30),SIMD3(repeating: twilight*0.42))
    }
}
