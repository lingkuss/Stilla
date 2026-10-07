import Foundation
import simd
func expect(_ condition: @autoclosure () -> Bool,_ message: String) { if !condition() { fatalError(message) } }
var codes=Set<UInt64>()
func rayHitsTriangle(from origin: SIMD3<Float>,to target: SIMD3<Float>,
                     _ a: SIMD3<Float>,_ b: SIMD3<Float>,_ c: SIMD3<Float>) -> Bool {
    let ray=target-origin,ab=b-a,ac=c-a
    let p=simd_cross(ray,ac),det=simd_dot(ab,p)
    guard abs(det)>0.000001 else { return false }
    let t=origin-a,u=simd_dot(t,p)/det
    guard u>=0 && u<=1 else { return false }
    let q=simd_cross(t,ab),v=simd_dot(ray,q)/det
    guard v>=0 && u+v<=1 else { return false }
    let depth=simd_dot(ac,q)/det
    return depth>0 && depth<1
}
for region in 0..<100 {
    for place in MountainRegionRecipe.PlaceID.allCases {
        let a=MountainWorldDNA(seed: 17,address: .init(region: region,place: place))
        let b=MountainWorldDNA(seed: 17,address: .init(region: region,place: place))
        expect(a==b,"Genome not repeatable")
        expect(codes.insert(a.code).inserted,"Genome repeated")
        expect(a.genes.allSatisfy { (0...1).contains($0) },"Gene outside bounds")
        let p=a.guide
        expect(abs(p.y-a.height(p.x,p.z)-3.2)<0.001,"Guide does not hover above terrain")
        for z in stride(from: -100 as Float,through: 25,by: 2.5) {
            let x=a.pathX(z)
            expect(a.clear(x,z),"Path accepts vegetation")
            let rise=a.height(a.pathX(z-0.5),z-0.5)-a.height(x,z)
            expect(rise>0.04 && rise<0.095,"Trail descends or becomes too steep")
            expect(abs(a.height(x-0.8,z)-a.height(x+0.8,z))<0.001,"Trail has cross-slope")
            expect(abs(a.pathX(z+0.1)-a.pathX(z-0.1))/0.2<0.8,"Path turns too abruptly")
        }
        let slopes=stride(from: -100 as Float,through: 25,by: 2.5).map { a.pathX($0+0.1)-a.pathX($0-0.1) }
        expect(slopes.contains { $0 > 0.01 } && slopes.contains { $0 < -0.01 },"Path never meanders")
        let left=(a.pathX(0)-a.pathX(-0.01))/0.01
        let right=(a.pathX(0.01)-a.pathX(0))/0.01
        expect(abs(left-right)<0.002,"Foreground path contains a kink")
        expect(a.pathHeight(-100)-a.pathHeight(25)>11,"Climb is too flat to read")
        for z in stride(from: -MountainWildMesh.horizonDistance,through: -380,by: 20) {
            expect(a.pathHeight(z-1)>a.pathHeight(z),"Distant continuation descends")
        }
        let endpoint=SIMD3<Float>(a.pathX(-MountainWildMesh.horizonDistance),
                                 a.pathHeight(-MountainWildMesh.horizonDistance)+0.1,
                                 -MountainWildMesh.horizonDistance)
        let hiddenByCrest=stride(from: 0.2 as Float,through: 0.95,by: 0.025).contains { t in
            let sightline=a.cameraPosition+(endpoint-a.cameraPosition)*t
            return a.height(sightline.x,sightline.z)>sightline.y+1
        }
        expect(hiddenByCrest,"Finite trail endpoint is visible beyond the distant crest")
        for side: Float in [-1,1] {
            for offset: Float in [2,9] {
                let x=a.pathX(-20)+side*offset
                expect(simd_distance(a.normal(x-0.01,-20),a.normal(x+0.01,-20))<0.02,
                       "Terrain shoulder contains a lighting crease")
            }
        }
    }
}
for seed: UInt64 in Array(0..<32)+[94872845700161] {
    let dna=MountainWorldDNA(seed: seed,address: .init(region: 0,place: .lakeTerrace))
    var counts: [Int]=[]
    for economical in [false,true] {
        let started=Date()
        let batches=MountainWildMesh.build(dna,economical: economical)
        let triangles=batches.reduce(0) { $0+$1.positions.count/3 }
        for b in batches {
            expect(b.positions.count==b.normals.count,"Normals missing")
            expect(b.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite },"Invalid vertex")
            expect(b.normals.allSatisfy { abs(simd_length($0)-1)<0.002 },"Invalid normal")
        }
        for index in [3,4,5,10,13,14,15,16,17] {
            expect(batches[index].positions.allSatisfy { abs($0.x-dna.pathX($0.z))>=1.2 },"Foliage blocks the path")
        }
        for index in [0,9] {
            let rock=batches[index].positions
            for i in stride(from: 0,to: rock.count,by: 3) {
                let a=rock[i],b=rock[i+1],c=rock[i+2]
                let ab=(a+b)*Float(0.5),bc=(b+c)*Float(0.5),ca=(c+a)*Float(0.5)
                let centre=(a+b+c)/Float(3)
                for p in [a,b,c,ab,bc,ca,centre] {
                    expect(abs(p.x-dna.pathX(p.z))>=3,"Rock intersects the trail corridor")
                }
            }
        }
        expect(!batches[18].positions.isEmpty && !batches[19].positions.isEmpty,
               "No procedural trees accepted: seed=\(seed), economical=\(economical)")
        for index in 18...21 {
            let tree=batches[index].positions
            for i in stride(from: 0,to: tree.count,by: 3) {
                let a=tree[i],b=tree[i+1],c=tree[i+2]
                let ab=(a+b)*Float(0.5),bc=(b+c)*Float(0.5),ac=(a+c)*Float(0.5)
                let centre=(a+b+c)/Float(3)
                for p in [a,b,c,ab,bc,ac,centre] {
                    expect(abs(p.x-dna.pathX(p.z))>=3.5,"Tree branch/crown crosses the protected trail")
                }
            }
        }
        let cloud=batches[11].positions
        let farPath=SIMD3<Float>(dna.pathX(-520),dna.pathHeight(-520)+0.1,-520)
        let cloudOccludesTrail=stride(from: 0,to: cloud.count,by: 3).contains { i in
            rayHitsTriangle(from: dna.cameraPosition,to: farPath,cloud[i],cloud[i+1],cloud[i+2])
        }
        expect(!cloudOccludesTrail,"Sky clouds obscure the distant trail as a ground bank")
        expect(!cloud.isEmpty,"Missing procedural sky clouds")
        for i in stride(from: 0,to: cloud.count,by: 3) {
            let a=cloud[i],b=cloud[i+1],c=cloud[i+2]
            let centre=(a+b+c)/Float(3)
            for p in [a,b,c,centre] {
                expect(p.y-dna.height(p.x,p.z)>30,"Cloud touches or lies too close to the terrain")
            }
        }
        let trail=batches[2].positions
        expect(trail.map(\.z).min() == -MountainWildMesh.horizonDistance,"Trail ends before the horizon")
        expect(batches[12].positions.map(\.z).min() == trail.map(\.z).min(),"Distant trail has no supporting terrain")
        for segment in 1..<trail.count/6 {
            expect(simd_distance(trail[(segment-1)*6+2],trail[segment*6+1])<0.0001,
                   "Trail edge has a crack between segments")
            expect(simd_distance(trail[(segment-1)*6+5],trail[segment*6])<0.0001,
                   "Trail edge has a crack between segments")
        }
        for vertex in trail {
            expect(abs(vertex.y-dna.pathHeight(vertex.z)-0.10)<0.0001,"Trail leaves the flat ridge corridor")
        }
        // Scenery is flower-free. Only the persistent garden creates blooms.
        expect([10,13,14,15,16,17,21].allSatisfy { batches[$0].positions.isEmpty },
               "World generated an unearned flower")
        expect([1,3,4,5].allSatisfy { batches[$0].positions.isEmpty },
               "Removed grass or small shrubs returned to the landscape")
        expect(triangles<250000,"Scene geometry budget exceeded: \(triangles), seed=\(seed)")
        counts.append(triangles)
        if [1,17,94872845700161].contains(seed) { print("DNA \(String(dna.code,radix:16)): economical=\(economical), \(triangles) triangles, CPU \(Date().timeIntervalSince(started))s") }
    }
    expect(counts[1]<counts[0],"Economical mode did not reduce geometry")
}
print("PASS: 700 distinct reproducible genomes, clear paths, hovering guide, finite smooth geometry, bounded triangles and lower economical budget")

// Structural mutations change occupancy, not just a colour or object transform.
var closedGenes=Array(repeating: Float(0.5),count: 32)
closedGenes[20]=0; closedGenes[29]=0.25; closedGenes[30]=0
var openGenes=closedGenes; openGenes[20]=0.95
let closed=MountainFormField(genes: closedGenes,variation: 0.5)
let opened=MountainFormField(genes: openGenes,variation: 0.5)
expect(closed.value([0.3,0,0])<0 && opened.value([0.3,0,0])>0,"Aperture gene does not change topology")
var silhouettes=Set<String>()
var minimumNovelty: Float=1
for index in 0..<56 {
    let places=MountainRegionRecipe.PlaceID.allCases
    let dna=MountainWorldDNA(seed: 17,address: .init(region: index/7,place: places[index%7]))
    let field=MountainFormField(dna: dna,variation: 0.5)
    var signature="", interior=0
    for y in -5...5 { for x in -5...5 {
        let inside=field.value([Float(x)*0.23,Float(y)*0.23,0])<0
        signature += inside ? "1" : "0"
        if inside { interior += 1 }
    } }
    expect(interior>4 && interior<110,"Degenerate field silhouette")
    silhouettes.insert(signature)
    for axis in 0..<3 { for side: Float in [-1,1] {
        var p=SIMD3<Float>(repeating: 0); p[axis]=side*1.6
        expect(field.value(p)>0,"Field crosses its mesh volume boundary")
    } }
    if index>0 && index%8 != 0 {
        let previous=MountainWorldDNA(seed: 17,address: .init(region: (index-1)/7,place: places[(index-1)%7]))
        minimumNovelty=min(minimumNovelty,MountainWorldDNA.distance(dna.genes,previous.genes))
    }
}
expect(silhouettes.count>45,"Morphology repeats too often")
expect(minimumNovelty>0.20,"Candidate selection accepted near-duplicate morphology")
let far=MountainWorldDNA(seed: UInt64.max,address: .init(region: Int.max-2,place: .cloudTemple))
expect(far.genes.count==32 && far.candidateScore.isFinite,"Far future reconstruction failed")
print("PASS: structural cavity mutation, \(silhouettes.count) distinct field silhouettes, bounded field, minimum selected novelty \(minimumNovelty), far-future reconstruction")

// Civil time follows the supplied time zone, including DST boundaries.
var calendar=Calendar(identifier: .gregorian)
calendar.timeZone=TimeZone(identifier: "Europe/Stockholm")!
let iso=ISO8601DateFormatter()
expect(abs(MountainDaylight(date: iso.date(from: "2026-09-25T10:00:00Z")!,calendar: calendar).hour-12)<0.001,"Local daylight hour incorrect")
expect(abs(MountainDaylight(date: iso.date(from: "2026-03-29T00:30:00Z")!,calendar: calendar).hour-1.5)<0.001,"Pre-DST clock incorrect")
expect(abs(MountainDaylight(date: iso.date(from: "2026-03-29T01:30:00Z")!,calendar: calendar).hour-3.5)<0.001,"DST clock incorrect")
expect(MountainDaylight(hour: 24)==MountainDaylight(hour: 0),"Midnight wrap differs")
expect(MountainDaylight(hour: -1)==MountainDaylight(hour: 23),"Negative preview hour fails")
expect(MountainDaylight(hour: .nan)==MountainDaylight(hour: 12),"Invalid preview hour not sanitized")
expect(MountainDaylight(hour: 12).daylight>0.99 && MountainDaylight(hour: 0).daylight<0.01,"No noon/night contrast")
let sampleDNA=MountainWorldDNA(seed: 17,address: .start)
for minute in 0..<1440 {
    let light=MountainDaylight(hour: Float(minute)/60)
    expect((0...1).contains(light.daylight) && (0...1).contains(light.sunVisibility) && (0...1).contains(light.moonVisibility),"Lighting outside bounds")
    expect(abs(simd_length(light.lightDirection)-1)<0.001,"Invalid light direction")
    for moon in [false,true] {
        let visibility=moon ? light.moonVisibility : light.sunVisibility
        if visibility>0.01 {
            let orb=light.orbPosition(moon: moon)
            expect(orb.y>=0.10 && orb.y<0.25,"Visible celestial body falls into mountain/foreground band")
            expect(orb.x>0.05 && orb.x<0.95,"Visible celestial body leaves the screen")
        }
    }
    for color in [light.sky(sampleDNA),light.haze(sampleDNA)] {
        expect(color.x.isFinite && color.y.isFinite && color.z.isFinite && color.min()>=0 && color.max()<=1,"Invalid sky color")
    }
}
print("PASS: smooth varied paths, floating guide clearance, local time, DST, midnight wrap and full-day lighting bounds")

var botanicalSignatures=Set<String>()
for seed: UInt64 in 0..<40 {
    let world=MountainWorldDNA(seed: seed,address: .start)
    for family in 0..<5 {
        let flora=MountainFloraDNA(world: world,species: family)
        expect(flora==MountainFloraDNA(world: world,species: family),"Flora does not reproduce")
        expect(flora.traits.allSatisfy { (0...1).contains($0) },"Flora trait outside bounds")
        let key="\(flora.stems)-\(flora.lobes)-\(flora.petals)-\(Int(flora.leafWidth*100))-\(Int(flora.droop*100))"
        botanicalSignatures.insert(key)
    }
}
expect(botanicalSignatures.count>190,"Plant silhouettes repeat too often")
print("PASS: generated S-curves and \(botanicalSignatures.count) repeatable botanical trait combinations")

var floorMaterials=Set<Int>(),calm=0,waves=0
for seed: UInt64 in 0..<128 {
    let dna=MountainWorldDNA(seed: seed,address: .start),floorDNA=dna.floorDNA
    expect(floorDNA == MountainWorldDNA(seed: seed,address: .start).floorDNA,"Floor not repeatable")
    floorMaterials.insert(floorDNA.material.rawValue)
    if floorDNA.material == .water {
        if floorDNA.waveStrength == 0 { calm += 1 } else { waves += 1 }
    }
    for z in stride(from: -700 as Float,through: 200,by: 70) {
        for x in stride(from: -600 as Float,through: 600,by: 80) {
            let relief=floorDNA.relief(x,z),n=floorDNA.normal(x,z)
            expect(relief.isFinite && relief >= 0 && relief <= 7.1,"Unbounded valley relief")
            expect(abs(simd_length(n)-1)<0.001,"Invalid floor normal")
            expect(dna.lakeLevel+relief < -8,"Valley floor rises into trail")
        }
    }
}
expect(floorMaterials.count==4 && calm>0 && waves>0,"Missing floor/water variation")
print("PASS: 128 repeatable valley surfaces, four materials, \(calm) calm and \(waves) wavy waters, bounded relief")

expect(abs(MountainDaylight(hour: 19).elevation)<0.0001 && MountainDaylight(hour: 19).twilight>0.99,"Dusk not at 19")
expect(MountainDaylight(hour: 18).daylight>0.8,"Day ends too early")
expect(MountainDaylight(hour: 0).daylight<0.01,"Midnight should remain night")
for hour: Float in [6,19,24] {
    let before=MountainDaylight(hour: hour-0.001),after=MountainDaylight(hour: hour+0.001)
    expect(simd_distance(before.sunDirection,after.sunDirection)<0.002,"Clock phase jumps")
}
print("PASS: dusk at 19, midnight night and continuous light at phase boundaries")

for seconds in [8,300,600,1800,7200] {
    let route=MountainMeditationJourney(durationSeconds: seconds)
    expect(route.distance(at: 0)==0 && route.distance(at: -1)==0,"Travel must start at rest")
    expect(route.distance(at: .nan)==0,"Invalid flight time")
    expect(route.distance(at: route.duration+60)==route.distance(at: route.duration),"Flight leaves its bounded route")
    for seed: UInt64 in 0..<32 {
        let dna=MountainWorldDNA(seed: seed,address: .start)
        for time in stride(from: 0.0,through: route.duration,by: 7) {
            let a=route.pose(in: dna,elapsed: time),b=route.pose(in: dna,elapsed: time+0.1)
            expect(dna.clear(a.position.x,a.position.z),"Camera leaves the trail")
            expect(abs(a.position.y-dna.height(a.position.x,a.position.z)-6.5)<0.001,"Camera crosses the ground")
            expect(a.position.z >= -292 && a.position.z <= 8,"Flight exceeds protected scenery")
            expect(simd_distance(a.position,b.position)<0.065,"Meditation camera moves too fast")
            let direction=simd_normalize(a.target-a.position),next=simd_normalize(b.target-b.position)
            expect(simd_dot(direction,next)>0.9999,"Camera turns abruptly")
        }
    }
}
print("PASS: meditation flights stay above the trail, bounded and smooth across 32 seeds and 5 durations")

// The landscape identity now comes from continuous ridges, not cavity meshes.
var ridgeProfiles=Set<String>()
for index in 0..<56 {
    let places=MountainRegionRecipe.PlaceID.allCases
    let world=MountainWorldDNA(seed: 17,address: .init(region: index/7,place: places[index%7]))
    let profile: [Int]=[-250,-450,-650,-850].flatMap { distance in
        [-120,-60,60,120].map { offset in
            Int(world.height(world.pathX(Float(distance))+Float(offset),Float(distance)))
        }
    }
    ridgeProfiles.insert(profile.map(String.init).joined(separator: ","))
    let pigments=world.palette
    expect(pigments.allSatisfy { $0.min()>=0 && $0.max()<=1 },"Pigment outside display range")
    expect(pigments[2].x > pigments[12].x+0.2,"Trail loses its warm luminance separation")
}
expect(ridgeProfiles.count>50,"Rounded mountain profiles repeat too often")
print("PASS: \(ridgeProfiles.count) distinct rounded ridge profiles, legible trail pigments and flower-free scenery")
