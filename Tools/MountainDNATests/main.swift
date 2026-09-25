import Foundation
import simd
func expect(_ condition: @autoclosure () -> Bool,_ message: String) { if !condition() { fatalError(message) } }
var codes=Set<UInt64>()
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
            expect(abs(a.height(x,z)+z*0.045)<0.001,"Path floor discontinuity")
            expect(abs(a.pathX(z+0.1)-a.pathX(z-0.1))/0.2<0.8,"Path turns too abruptly")
        }
        let slopes=stride(from: -100 as Float,through: 25,by: 2.5).map { a.pathX($0+0.1)-a.pathX($0-0.1) }
        expect(slopes.contains { $0 > 0.01 } && slopes.contains { $0 < -0.01 },"Path never meanders")
        let left=(a.pathX(0)-a.pathX(-0.01))/0.01
        let right=(a.pathX(0.01)-a.pathX(0))/0.01
        expect(abs(left-right)<0.002,"Foreground path contains a kink")
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
        for index in [3,4,5,10,13,14] {
            expect(batches[index].positions.allSatisfy { abs($0.x-dna.pathX($0.z))>=1.2 },"Foliage blocks the path")
        }
        expect(!batches[10].positions.isEmpty && !batches[14].positions.isEmpty,"World has no visible flower geometry: seed=\(seed), economical=\(economical), triangles=\(triangles)")
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
