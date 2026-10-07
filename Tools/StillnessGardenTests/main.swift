import Foundation
import simd

func check(_ condition: @autoclosure () -> Bool, _ message: String = "", line: UInt = #line) {
    guard condition() else { print("FAIL line \(line): \(message)"); exit(1) };
}

@main struct GardenChecks {
    @MainActor static func main() throws {
        let suite = "vindla.garden.tests.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StillnessGardenStore(defaults: defaults)
        check(store.flowers.isEmpty && store.crystals.isEmpty && store.trees.isEmpty && !store.storageUnavailable)
        check(store.earnedNoticeKey == nil)
        check(!StillnessGarden.qualifies(reachedEnd: false,openEnded: false,elapsedSeconds: 299,sleepStory: false))
        check(!StillnessGarden.qualifies(reachedEnd: true,openEnded: false,elapsedSeconds: 300,sleepStory: true))
        check(!StillnessGarden.qualifies(reachedEnd: false,openEnded: true,elapsedSeconds: 0,sleepStory: false))
        check(StillnessGarden.qualifies(reachedEnd: false,openEnded: true,elapsedSeconds: 90,sleepStory: false))
        check(StillnessGarden.qualifies(reachedEnd: true,openEnded: false,elapsedSeconds: 300,sleepStory: false))
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        for i in 1...201 {
            let previous = Dictionary(uniqueKeysWithValues: GardenKind.allCases.flatMap { store.specimens($0) }.map { ($0.id,$0.seed) })
            let id = UUID(uuidString: String(format: "A11CE000-0000-4000-8000-%012d",i))!
            check(store.record(sessionID: id,at: date))
            check(!store.record(sessionID: id,at: date))
            check(store.meditationCount == i)
            check(store.flowers.count == i/10 && store.crystals.count == i/25 && store.trees.count == i/100)
            check((store.earnedNoticeKey != nil) == (i.isMultiple(of: 10) || i.isMultiple(of: 25)))
            if i.isMultiple(of: 100) { check(store.earnedNoticeKey == "garden.earned.tree") }
            else if i.isMultiple(of: 50) { check(store.earnedNoticeKey == "garden.earned.both") }
            else if i.isMultiple(of: 25) { check(store.earnedNoticeKey == "garden.earned.crystal") }
            let restored = StillnessGardenStore(defaults: defaults)
            check(restored.flowers == store.flowers && restored.crystals == store.crystals && restored.trees == store.trees)
            check(restored.meditationCount == i)
            for kind in GardenKind.allCases {
                for specimen in restored.specimens(kind) where previous[specimen.id] != nil {
                    check(previous[specimen.id] == specimen.seed,"Later practice changed an existing DNA")
                }
                check(restored.remaining(kind) == kind.interval-i%kind.interval)
                if let specimen = restored.specimens(kind).last {
                    let milestone = i/kind.interval*kind.interval
                    check(specimen.sessionID == UUID(uuidString: String(format: "A11CE000-0000-4000-8000-%012d",milestone)))
                }
            }
            check(!restored.record(sessionID: id))
        }
        check(store.remaining(.crystal) == 24 && store.remaining(.flower) == 9 && store.remaining(.tree) == 99)
        var signatures: Set<String> = []
        var maxPortrait = 0, maxWorld = 0
        var crystalMax = 0
        var crystalShapes = Array(repeating: Set<String>(),count: 6)
        let specimens = GardenKind.allCases.flatMap { kind in
            (0..<192).map { index in
                GardenSpecimen(sessionID: UUID(),seed: GardenDNA.mix(UInt64(index)),kind: kind,ordinal: index+1,earnedAt: date)
            }
        }
        let started = Date()
        for item in specimens {
            let mesh = GardenGeometry.build(item,detail: .portrait)
            let again = GardenGeometry.build(item,detail: .portrait)
            check(mesh.positions == again.positions && mesh.pigments == again.pigments,"Repeatability: \(item.kind) seed \(item.seed)")
            check(mesh.positions.count == mesh.normals.count && mesh.normals.count == mesh.pigments.count)
            check(mesh.indices.allSatisfy { Int($0)<mesh.positions.count })
            check(mesh.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
            check(mesh.normals.allSatisfy { abs(simd_length($0)-1)<0.001 })
            if item.kind == .crystal {
                check(mesh.mineralSurfaces.count == mesh.positions.count,"Mineral surface payload misaligned")
                check(mesh.mineralSurfaces.allSatisfy { $0.x>=0 && $0.x<=2 && $0.y>=0 && $0.y<=1 })
                let lower = mesh.positions.reduce(SIMD3<Float>(repeating: .infinity)) { simd_min($0,$1) }
                let upper = mesh.positions.reduce(SIMD3<Float>(repeating: -.infinity)) { simd_max($0,$1) }
                let size = upper-lower
                check(abs(lower.y+0.70)<0.0001,"Specimen is not grounded")
                let shape = "\(mesh.triangleCount)-\(Int(size.y/max(size.x,size.z)*20))"
                crystalShapes[GardenGeometry.family(item.seed,count: 6)].insert(shape)
                crystalMax = max(crystalMax,mesh.triangleCount)
            } else { check(mesh.mineralSurfaces.isEmpty) }
            check(mesh.pigments.allSatisfy { let c=GardenMesh.rgb($0); return c.min()>=0 && c.max()<=1 })
            let bounds = mesh.positions.reduce(SIMD3<Float>(repeating: 0)) { simd_max($0,simd_abs($1)) }
            signatures.insert("\(item.kind)-\(bounds)-\(mesh.pigments.first!)-\(mesh.positions.count)")
            check(mesh.triangleCount<18_000)
            maxPortrait=max(maxPortrait,mesh.triangleCount)
            let low=GardenGeometry.build(item,detail: .world)
            check(low.triangleCount<2_500 && low.triangleCount<=mesh.triangleCount,"LOD: \(item.kind) \(low.triangleCount)/\(mesh.triangleCount)")
            check(low.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite })
            check(low.normals.allSatisfy { abs(simd_length($0)-1)<0.001 })
            maxWorld=max(maxWorld,low.triangleCount)
        }
        check(signatures.count==specimens.count)
        let seconds=Date().timeIntervalSince(started)
        for kind in GardenKind.allCases {
            let count = kind == .tree ? 4 : 6
            let families = Set(specimens.filter { $0.kind == kind }.map { GardenGeometry.family($0.seed,count: count) })
            check(families.count == count)
        }
        print("PASS: 0–201 awards, overlapping 10/25/100 milestones, replay/relaunch, completion policy, all 16 morphology families")
        print("Portrait max: \(maxPortrait) triangles; world max: \(maxWorld); \(specimens.count*2) portrait builds: \(seconds)s")
        check(crystalShapes.allSatisfy { $0.count>=16 },"Variation collapsed within a mineral habit")
        print("PASS: mineral UV/material alignment, grounded crystals, within-habit shape counts \(crystalShapes.map(\.count)); crystal max \(crystalMax) triangles")
        // Transparent bark exposes disconnected roots and buried caps. Verify
        // the stem/root skin is a single closed, consistently wound manifold.
        for sample in 0..<64 { for detail in [GardenGeometry.Detail.portrait,.world] {
            let seed = GardenDNA.mix(UInt64(sample))
            let stem = GardenGeometry.treeStem(seed: seed,detail: detail,hue: 0.08) { u in
                [sin(u*3)*0.04,u-0.68,u*u*0.06]
            }
            var edges: [UInt64: (count: Int, winding: Int)] = [:]
            var neighbours = Array(repeating: [Int](),count: stem.positions.count)
            var volume: Float = 0
            for index in stride(from: 0,to: stem.indices.count,by: 3) {
                let ids = (0..<3).map { Int(stem.indices[index+$0]) }
                let a = stem.positions[ids[0]], b = stem.positions[ids[1]], c = stem.positions[ids[2]]
                check(simd_length_squared(simd_cross(b-a,c-a))>1e-16,"Degenerate root face")
                volume += simd_dot(a,simd_cross(b,c))/6
                for j in 0..<3 {
                    let a = ids[j], b = ids[(j+1)%3]
                    let key = UInt64(min(a,b))<<32 | UInt64(max(a,b))
                    let old = edges[key] ?? (0,0)
                    edges[key] = (old.count+1,old.winding+(a<b ? 1 : -1))
                    neighbours[a].append(b); neighbours[b].append(a)
                }
            }
            check(edges.values.allSatisfy { $0.count==2 && $0.winding==0 },"Open or inverted root seam")
            check(volume>0,"Root skin points inward")
            var visited: Set<Int> = [0], queue = [0], cursor = 0
            while cursor<queue.count {
                for next in neighbours[queue[cursor]] where visited.insert(next).inserted { queue.append(next) }
                cursor += 1
            }
            check(visited.count==stem.positions.count,"Detached root or internal shell")
            check(stem.positions.count-edges.count+stem.triangleCount==2,"Unexpected root topology")
            let feet = stem.positions.filter { $0.y < -0.55 }
            let spread = feet.map { simd_length(SIMD2($0.x,$0.z)) }.max() ?? 0
            check(spread>0.50 && spread<0.95,"Root reach is too small or unbounded")
        } }
        print("PASS: 64 stem/root systems in both LODs are connected, closed, outward-facing and have extended roots")
        // Clipped growth faces must remain inside every constraint and face
        // outward. This matters for both realistic facets and dual-layer glass.
        for sample in 0..<48 {
            var planes = [GardenGeometry.MineralPlane([1,0,0],1),.init([-1,0,0],1),
                          .init([0,1,0],1),.init([0,-1,0],1),.init([0,0,1],1),.init([0,0,-1],1)]
            for j in 0..<8 {
                let seed = GardenDNA.mix(UInt64(sample*8+j))
                let direction = SIMD3<Float>(GardenDNA.value(seed,0)-0.5,GardenDNA.value(seed,1)-0.5,GardenDNA.value(seed,2)-0.5)
                planes.append(.init(simd_normalize(direction),0.65+GardenDNA.value(seed,3)*0.5))
            }
            let faces = GardenGeometry.mineralPolyhedron(planes)
            check(faces.count>=6)
            for face in faces {
                check(face.allSatisfy { p in planes.allSatisfy { simd_dot($0.normal,p)<=$0.distance+0.0001 } })
                let normal = simd_cross(face[1]-face[0],face[2]-face[0])
                let center = face.reduce(SIMD3<Float>.zero,+)/Float(face.count)
                check(simd_dot(normal,center)>0,"Inward mineral face")
            }
        }
        print("PASS: 48 clipped mineral volumes keep planar, outward faces inside growth constraints")
        // Large collections cannot grow world geometry without bound.
        let large = StillnessGardenStore.preview(count: 1000)
        check(large.flowers.count==100 && large.crystals.count==40 && large.trees.count==10 && large.worldSpecimens.count==116)
        for kind in GardenKind.allCases {
            let families = large.specimens(kind).map { GardenGeometry.family($0.seed,count: kind.familyCount) }
            for index in 1..<families.count { check(families[index] != families[index-1],"Consecutive silhouettes repeated") }
            for start in stride(from: 0,to: families.count,by: kind.familyCount) {
                let end = min(families.count,start+kind.familyCount)
                check(Set(families[start..<end]).count == end-start,"Discovery cycle repeated a silhouette")
            }
        }
        for seed: UInt64 in [1,17,99] {
            let dna=MountainWorldDNA(seed: seed,address: .init(region: 0,place: .mossGate))
            let empty=GardenGeometry.world([],dna: dna,economical: false)
            check(empty.allSatisfy { $0.positions.isEmpty })
            let scenery=MountainWildMesh.build(dna,economical: false)
            let terrainCount=scenery.reduce(0) { $0+$1.positions.count/3 }
            let world=GardenGeometry.world(large.worldSpecimens,dna: dna,economical: false,
                triangleBudget: min(70_000,248_000-terrainCount))
            let low=GardenGeometry.world(large.worldSpecimens,dna: dna,economical: true,triangleBudget: 28_000)
            let normalCount=world.reduce(0) { $0+$1.triangleCount }
            let lowCount=low.reduce(0) { $0+$1.triangleCount }
            check(normalCount<=70_000 && lowCount<=28_000 && lowCount<normalCount)
            check(!world[2].positions.isEmpty && !low[2].positions.isEmpty)
            check([10,13,14,15,16,17,21].allSatisfy { scenery[$0].positions.isEmpty })
            let total=scenery.reduce(0) { $0+$1.positions.count/3 }+normalCount
            check(total<250_000)
            print("Seed \(seed): combined world \(total) triangles; garden \(normalCount), economical \(lowCount)")
        }
        let dna=MountainWorldDNA(seed: 11,address: .init(region: 0,place: .mossGate))
        for budget in [0,400,4000,12_000] {
            let capped=GardenGeometry.world(large.worldSpecimens,dna: dna,economical: false,triangleBudget: budget)
            check(capped.reduce(0) { $0+$1.triangleCount } <= budget)
        }
        for seed in 0..<64 {
            let world=MountainWorldDNA(seed: UInt64(seed),address: .init(region: seed,place: .mountainRidge))
            let foot=GardenGeometry.placement(rank:0,kind:.flower,variation:0.5,dna:world)
            check(abs(foot.x-world.pathX(foot.y))>=3.5)
            let eye=world.cameraPosition,forward=simd_normalize(world.cameraTarget-eye)
            let right=simd_normalize(simd_cross(forward,SIMD3<Float>(0,1,0)))
            let p=SIMD3<Float>(foot.x,world.height(foot.x,foot.y)+1.5,foot.y)-eye
            let nx=simd_dot(p,right)/(simd_dot(p,forward)*tan(Float(55)*Float.pi/360)*0.46)
            check(abs(nx)<0.85,"First flower outside portrait frame: \(seed), \(nx)")
        }
        print("PASS: first flower stays in portrait view across 64 winding worlds")
        let key="vindla.stillnessGarden.v1"
        // A v1 ledger from the original one-flower-per-session implementation
        // stays readable; cadence changes must never discard completed practice.
        let legacyData = defaults.data(forKey: key)!
        let legacy = try JSONDecoder().decode(StillnessGarden.self,from: legacyData)
        check(legacy.version == 1 && legacy.completions.count == 201)
        let again = StillnessGardenStore(defaults: defaults)
        check(again.meditationCount == 201 && again.flowers.count == 20 && again.trees.count == 2)
        check(defaults.data(forKey: key) == legacyData)
        try again.setMockMeditations(300)
        let mock = StillnessGardenStore(defaults: defaults)
        check(mock.meditationCount == 300 && mock.flowers.count == 30 && mock.crystals.count == 12 && mock.trees.count == 3)
        check(defaults.data(forKey: key+".beforeMock") == legacyData)
        try mock.setMockMeditations(100)
        check(defaults.data(forKey: key+".beforeMock") == legacyData,"Repeated mock overwrote real backup")
        do { try mock.setMockMeditations(-1); check(false,"Accepted invalid mock count") } catch { }
        try mock.restoreBeforeMock()
        check(defaults.data(forKey: key) == legacyData && mock.meditationCount == 201)
        check(defaults.data(forKey: key+".beforeMock") == nil)
        print("PASS: persistent 300-meditation mock, 30/12/3 rewards, preserved backup and exact restoration")
        let corrupt=Data("preserve this data".utf8)
        defaults.set(corrupt,forKey:key)
        let broken=StillnessGardenStore(defaults:defaults)
        check(broken.storageUnavailable && !broken.record(sessionID:UUID()))
        check(defaults.data(forKey:key)==corrupt)
        defaults.set(Data("{\"version\":999,\"completions\":[]}".utf8),forKey:key)
        check(StillnessGardenStore(defaults: defaults).storageUnavailable)
        print("PASS: bounded world/detail budgets, no unearned flora, corrupt/future-version preservation")
    }
}
