import Foundation
import simd

/// Versioned, addressable visual genomes. Six candidates compete on morphology,
/// negative space and novelty; names are labels, never scene templates.
struct MountainWorldDNA: Sendable, Equatable {
    static let version: UInt64 = 5
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
        let field=MountainFormField(genes: genes,variation: 0.5)
        var filled=0, edges=0
        // A cheap silhouette/volume sketch, not a full mesh or an AI request.
        for y in -3...3 { for x in -3...3 {
            let p=SIMD3<Float>(Float(x)*0.3,Float(y)*0.34,0)
            if field.value(p)<0 { filled += 1 }
            if (field.value(p)<0) != (field.value(p+[0.15,0,0])<0) { edges += 1 }
        } }
        let occupancy=Float(filled)/49
        let mass=1-min(1,abs(occupancy-0.48)*2)
        let legibility=1-min(1,abs(Float(edges)-9)/18)
        return mass*0.24 + legibility*0.12 + (1-genes[24])*0.05
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
    var hue: Float { genes[5] }
    var sky: SIMD3<Float> { Self.tint(hue+0.06,0.26,0.62+genes[6]*0.14) }
    var haze: SIMD3<Float> { Self.tint(hue+0.10,0.13,0.87) }
    var floorDNA: MountainFloorDNA { .init(world: self) }
    var lakeLevel: Float { -23 + genes[16]*7 }
    var guide: SIMD3<Float> {
        let x=pathX(-2)
        return [x,height(x,-2)+3.2,-2]
    }
    var cameraPosition: SIMD3<Float> { [pathX(24)+3,9+genes[27]*2,36] }
    var cameraTarget: SIMD3<Float> { [pathX(-60)*0.5,1+genes[21]*2,-48] }
    var palette: [SIMD3<Float>] {
        [Self.tint(hue,0.25+genes[6]*0.16,0.70),
         Self.tint(hue+0.12,0.34,0.55), Self.tint(hue+0.06,0.12,0.78),
         Self.tint(hue-0.08,0.31,0.28), Self.tint(hue+0.30,0.48,0.47),
         Self.tint(hue+0.36,0.34,0.68), floorDNA.color(hue: hue),
         Self.tint(hue+0.12,0.09,0.94), Self.tint(hue,0.08,0.91),
         Self.tint(hue+0.04,0.22,0.69), Self.tint(hue+0.48,0.42,0.91), haze, Self.tint(hue+0.10,0.34,0.40),
         Self.tint(hue+0.48,0.14,0.97), Self.tint(hue+0.59,0.46,0.85)]
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
    func height(_ x: Float,_ z: Float) -> Float {
        let lateral=x-pathX(z)
        let floor: Float = -29 + fbm(x*0.026,z*0.026)*7
        let ascent = -z*0.045
        let width: Float=8+genes[13]*14
        let shoulder=exp(-pow(abs(lateral)/width,2))
        let ridge=floor+(ascent-floor)*shoulder
        let folds=(fbm(x*0.052,z*0.052)-0.5)*(4+genes[15]*8)
        let edge=min(1,max(0,(abs(lateral)-2)/4))
        let blend=edge*edge*(3-2*edge)
        return ascent+(ridge+folds-ascent)*blend
    }
    func normal(_ x: Float,_ z: Float) -> SIMD3<Float> {
        simd_normalize(SIMD3(height(x-0.25,z)-height(x+0.25,z),0.5,height(x,z-0.25)-height(x,z+0.25)))
    }
    func clear(_ x: Float,_ z: Float) -> Bool {
        abs(x-pathX(z)) < 2
    }
}

/// A bounded implicit scalar field. Domain warping, superelliptic envelopes and
/// intersecting cavities change topology, rather than choosing a prefab object.
/// The exact same field is reused at monumental and botanical scales.
struct MountainFormField: Sendable {
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
        q.x += sin(q.y*5+q.z*3)*g[24]*0.055
        let taper=0.77+0.23*cos(q.y*2.1+g[25]*3)
        // A superellipsoid continuously ranges from rounded to folded/columnar.
        let exponent: Float=1.6+g[26]*1.3
        let body=pow(pow(abs(q.x/taper),exponent)+pow(abs(q.y/1.22),exponent)+pow(abs(q.z/0.62),exponent),1/exponent)-0.92
        let folds=sin(q.x*(8+g[25]*8)+q.y*2)*sin(q.z*7-q.y*3)*(0.010+g[24]*0.016)
        var result=body+folds
        // Branches are part of the density field, so they fuse into the parent
        // mass and can merge into arches when the cavities cut through them.
        for branch in 0..<(1+Int(g[23]*3)) {
            let angle=Float(branch)*2.399+variation*2
            let reach: Float=0.35+g[23]*0.32
            let origin=SIMD3<Float>(cos(angle)*reach,0.46+g[28]*0.12,sin(angle)*reach*0.64)
            let radii=SIMD3<Float>(0.26+g[24]*0.13,0.46+g[25]*0.18,0.25+g[24]*0.08)
            let limb=(simd_length((q-origin)/radii)-1)*0.34
            result = -smoothMaximum(-result,-limb,0.10)
        }
        // Cavities can stay enclosed, pierce the envelope or split its crown.
        let cx=(variation-0.5)*0.43
        let cy: Float = -0.15+g[29]*0.65
        let hole=simd_length(SIMD2((q.x-cx)/(0.10+aperture*0.70),(q.y-cy)/(0.16+aperture*0.93)))-1
        result=smoothMaximum(result,-hole*0.38,0.06)
        let crossHole=simd_length(SIMD2((q.z+0.1)/(0.10+g[30]*0.28),(q.y+0.38)/(0.12+g[31]*0.36)))-1
        if g[30] > 0.55 { result=smoothMaximum(result,-crossHole*0.23,0.04) }
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
    var petals: Int { 4+Int(traits[8]*8) }
    var cup: Float { (traits[9]-0.35)*0.85 }
    var petalWidth: Float { 0.22+traits[10]*0.55 }
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
    static func build(_ dna: MountainWorldDNA,economical: Bool) -> [MountainMeshBatch] {
        var b=Array(repeating: MountainMeshBatch(),count: dna.palette.count)
        terrain(dna,economical: economical,batch: &b[12])
        trail(dna,batch: &b[2])
        // Nested depth bands, with an open central view and ample negative space.
        // All formations come from one field; no biome/type switch exists.
        let nearCount=3+Int(dna.genes[27]*3)
        for i in 0..<(nearCount+8) {
            if Task.isCancelled { return b }
            let near=i<nearCount
            let z: Float = near ? -155-Float(i/2)*48-dna.random(i,5)*20 : -260-Float((i-nearCount)/4)*100
            let side: Float=i%2==0 ? -1 : 1
            let vertical=dna.genes[21]
            let height: Float=(near ? 22 : 45)+(near ? 60 : 100)*vertical*(0.6+dna.random(i,7)*0.4)
            let width: Float=(23+dna.random(i,11)*18)*(1.6-vertical*0.9)
            let x: Float=near ? side*(width*0.75+12+dna.random(i,3)*12) : Float((i-nearCount)%4)*100-150
            let lift=max(0,dna.genes[31]-0.58)*60
            let center=SIMD3<Float>(x,-23+height*0.62+lift,z)
            let scale=SIMD3<Float>(width,height*0.68,width*(0.8+dna.genes[23]*0.5))
            let field=MountainFormField(dna: dna,variation: dna.random(i,17))
            implicit(field,center: center,scale: scale,yaw: (dna.random(i,23)-0.5)*0.6,
                     resolution: near ? (economical ? 20 : 35) : (economical ? 13 : 20),
                     batch: &b[near ? 0 : 9])
        }
        valleyFloor(dna,economical: economical,batch: &b[6])
        let species=(0..<5).map { MountainFloraDNA(world: dna,species: $0) }
        // Vegetation grows in related patches, with airy openings along the path.
        let baseTriangles=b.reduce(0) { $0+$1.positions.count/3 }
        let floraBudget=max(0,min(economical ? 22000 : 65000,230000-baseTriangles))
        let plantBudget=Int(Float(floraBudget)*0.65)
        var plantRemaining=plantBudget
        let plants=economical ? 45 : 100
        let plantOrder=(0..<plants).sorted { dna.random($0,103)<dna.random($1,103) }
        for i in plantOrder {
            if plantRemaining<100 || Task.isCancelled { break }
            let z=14-dna.random(i,103)*145
            let side: Float=dna.random(i,104)>0.5 ? 1 : -1
            let h: Float=1.1+dna.random(i,107)*(2.0+dna.genes[8]*1.2)
            let x=dna.pathX(z)+side*(3+h*0.75+dna.random(i,105)*4)
            let y=dna.height(x,z)
            guard y>dna.lakeLevel+2, !dna.clear(x,z), dna.normal(x,z).y>0.40,
                  !(z > -8 && abs(x-dna.pathX(z))<6.5) else { continue }
            let family=min(4,Int(dna.noise(x*0.047,z*0.047)*5))
            var plant=Array(repeating: MountainMeshBatch(),count: b.count)
            botanical(at: [x,y,z],height: h,phase: dna.random(i,108)*6,
                      flora: species[family],detail: !economical && z > -48,b: &plant)
            appendFlora(plant,to: &b,remaining: &plantRemaining,dna: dna)
        }
        // Flowering drifts sit close enough to read at the camera's scale.
        var flowerRemaining=floraBudget-(plantBudget-plantRemaining)
        let flowerOrder=(0..<115).sorted { dna.random($0,701)<dna.random($1,701) }
        for i in flowerOrder {
            if flowerRemaining<100 || Task.isCancelled { break }
            let z=20-dna.random(i,701)*105
            let side: Float=i%2==0 ? -1 : 1
            let x=dna.pathX(z)+side*(2.7+dna.random(i,702)*6)
            let y=dna.height(x,z)
            guard y>dna.lakeLevel+1,dna.normal(x,z).y>0.6,
                  dna.noise(x*0.09,z*0.09)>0.30 else { continue }
            let family=min(4,Int(dna.noise(x*0.047,z*0.047)*5))
            let flora=species[family],h: Float=0.45+dna.random(i,703)*0.85
            let p=SIMD3<Float>(x,y,z),top=p+[sin(Float(i))*h*0.18,h,0]
            var flower=Array(repeating: MountainMeshBatch(),count: b.count)
            tube(from: p,to: top,r0: 0.018,r1: 0.009,batch: &flower[3])
            leaf(from: p+[0,h*0.25,0],direction: [side*0.8,0.45,0.2],length: h*0.45,
                 flora: flora,detail: false,batch: &flower[5])
            blossom(at: top,radius: 0.18+dna.random(i,704)*0.27,phase: dna.random(i,705)*6,
                    flora: flora,detail: !economical && z > -35,b: &flower)
            appendFlora(flower,to: &b,remaining: &flowerRemaining,dna: dna)
        }
        // Sparse field-grown minerals echo the same holes and folds at human scale.
        for i in 0..<5 {
            let z: Float=7-Float(i)*17
            let x=dna.pathX(z)+(i%2==0 ? -1 : 1)*(9+dna.random(i,401)*4)
            let y=dna.height(x,z)
            guard y>dna.lakeLevel+1 else { continue }
            let h: Float=1+dna.random(i,402)*2.5
            implicit(.init(dna: dna,variation: dna.random(i,403)),center: [x,y+h,z],scale: [h*0.65,h,h*0.7],
                     yaw: dna.random(i,404)*6,resolution: economical ? 9 : 13,batch: &b[0])
        }
        for i in 0..<(economical ? 240 : 600) {
            let x=(dna.random(i,301)-0.5)*64, z=22-dna.random(i,303)*90
            let y=dna.height(x,z)
            guard y>dna.lakeLevel+1,!dna.clear(x,z),dna.normal(x,z).y>0.7 else { continue }
            grass(at: [x,y,z],height: 0.2+dna.random(i,305)*0.5,phase: dna.random(i,306)*6,b: &b)
        }
        return b
    }

    /// Marching tetrahedra avoids a large case table, permits holes/overhangs,
    /// and produces smooth field-gradient normals independent of triangulation.
    private static func implicit(_ field: MountainFormField,center: SIMD3<Float>,scale: SIMD3<Float>,
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
            if flora.bloom>0.43 {
                blossom(at: point(1),radius: h*(0.09+flora.bloom*0.08),phase: azimuth,
                        flora: flora,detail: detail,b: &b)
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
    private static func blossom(at p: SIMD3<Float>,radius: Float,phase: Float,flora: MountainFloraDNA,
                                detail: Bool,b: inout [MountainMeshBatch]) {
        let layers=detail && flora.traits[15]>0.45 ? 2 : 1
        for layer in 0..<layers {
            let scale=radius*(layer==0 ? 1 : 0.65)
            for petal in 0..<flora.petals {
                let angle=phase+(Float(petal)+Float(layer)*0.5)*2*Float.pi/Float(flora.petals)
                let radial=SIMD3<Float>(cos(angle),0,sin(angle)),side=SIMD3<Float>(-sin(angle),0,cos(angle))
                func point(_ u: Float,_ v: Float) -> SIMD3<Float> {
                    let profile=pow(max(0,sin(u * .pi)),0.6+flora.traits[3]*0.9)
                    let r=scale*(0.12+u)
                    let width=scale*flora.petalWidth*profile
                    let rise=scale*(flora.cup*u*u+sin(u * .pi)*0.13+v*v*profile*0.16)
                    return p+radial*r+side*(width*v)+[0,rise+Float(layer)*radius*0.06,0]
                }
                curvedSurface(rows: detail ? 6 : 3,columns: detail ? 3 : 2,point: point,batch: &b[layer==0 ? 10 : 13])
            }
        }
        // A small convex seed head gives the flower a readable centre.
        for i in 0..<10 {
            let a=Float(i)*2 * .pi/10,c=Float(i+1)*2 * .pi/10
            b[14].triangle(p+[0,radius*0.13,0],p+[cos(c)*radius*0.20,0,sin(c)*radius*0.20],
                           p+[cos(a)*radius*0.20,0,sin(a)*radius*0.20])
        }
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
        var xs = Array(stride(from: -120 as Float,to: -32,by: 4))
        xs += Array(stride(from: -32 as Float,through: 32,by: step))
        xs += Array(stride(from: 36 as Float,through: 120,by: 4))
        var zs = Array(stride(from: -180 as Float,to: -48,by: 4))
        zs += Array(stride(from: -48 as Float,through: 32,by: step))
        zs += [36,40,46,54,64]
        let vertices = zs.map { z in xs.map { x in SIMD3(x,dna.height(x,z),z) } }
        let normals = zs.map { z in xs.map { x in dna.normal(x,z) } }
        for row in 0..<zs.count-1 {
            for col in 0..<xs.count-1 {
                let a=vertices[row][col],c=vertices[row+1][col],d=vertices[row+1][col+1],e=vertices[row][col+1]
                let na=normals[row][col],nc=normals[row+1][col],nd=normals[row+1][col+1],ne=normals[row][col+1]
                smoothTriangle(a,c,d,na,nc,nd,batch: &batch)
                smoothTriangle(a,d,e,na,nd,ne,batch: &batch)
            }
        }
    }
    private static func trail(_ dna: MountainWorldDNA,batch: inout MountainMeshBatch) {
        for i in 0..<230 {
            let z = 30-Float(i)*0.6, next = z-0.6
            let w: Float = 0.65+0.12*sin(z*0.4+dna.genes[12]*6)
            func p(_ z: Float,_ side: Float) -> SIMD3<Float> {
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
            let foot=p+[cos(a)*0.07,0,sin(a)*0.07]
            let tip=foot+[cos(a)*h*0.33,h*(0.7+Float(i%3)*0.12),sin(a)*h*0.33]
            let width=SIMD3<Float>(cos(a+1.57)*0.027,0,sin(a+1.57)*0.027)
            b[1].triangle(foot-width,foot+width,tip)

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
        let phase=(angle / .pi + (moon ? 1 : 0)).truncatingRemainder(dividingBy: 2)
        return [0.12+0.76*phase,0.57-0.43*sin(phase * .pi)]
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
