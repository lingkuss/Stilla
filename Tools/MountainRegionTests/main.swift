import Foundation
import simd

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() { fatalError(message) }
}
typealias Place = MountainRegionRecipe.PlaceID
func context(_ address: MountainPlaceAddress, seconds: Int = 300) -> MountainSessionContext {
    .init(id: UUID(),address: address,mode: .silent,durationSeconds: seconds,startedAtUptime: 100)
}
// Every possible branch combination contains exactly five meditation stops.
for first: Place in [.pineGlade,.brookRavine] {
    for second: Place in [.mountainRidge,.templeGrove] {
        var progress = MountainJourneyProgress()
        expect(!progress.arrive(.init(region: 0,place: first)),"Locked route allowed")
        for id: Place in [.mossGate,first,.lakeTerrace,second,.cloudTemple] {
            if id != .mossGate { expect(progress.arrive(.init(region: 0,place: id)),"Unlocked arrival failed") }
            let session = context(progress.current)
            expect(!progress.complete(session,at: 399,reachedEnd: true),"Early time credited")
            expect(!progress.complete(session,at: 500,reachedEnd: false),"Aborted session credited")
            expect(progress.complete(session,at: 400,reachedEnd: true),"Completed session rejected")
            expect(!progress.complete(session,at: 500,reachedEnd: true),"Duplicate completion credited")
        }
        expect(progress.completed.count == 5,"Wrong path length")
        expect(progress.arrive(.init(region: 1,place: .mossGate)),"Next region locked")
        expect(progress.arrive(.start),"Previously discovered place inaccessible")
        let other: Place = first == .pineGlade ? .brookRavine : .pineGlade
        expect(progress.arrive(.init(region: 0,place: other)),"Alternative fork inaccessible on revisit")
        let data = try! JSONEncoder().encode(progress)
        expect(try! JSONDecoder().decode(MountainJourneyProgress.self,from: data) == progress,"Restore changed progression")
        let notAtCurrent = context(.init(region: 42,place: .cloudTemple))
        expect(!progress.complete(notAtCurrent,at: 500,reachedEnd: true),"Wrong location credited")
    }
}
let timed = context(.start)
expect(timed.elapsed(at: 99) == 0 && timed.elapsed(at: 110) == 10 && timed.elapsed(at: 1000) == 300,"Clock reconciliation failed")
// Terrain, guide clearances and seed stability across many worlds.
for seed: UInt64 in [0,1,17,MountainJourneyRecipe.defaultSeed,UInt64.max] {
    for region in [0,1,1000000] {
        let recipe = MountainRegionRecipe(seed: seed,region: region)
        let again = MountainRegionRecipe(seed: seed,region: region)
        for id in Place.allCases {
            let p = recipe.position(id)
            expect(p == again.position(id),"Unstable identity")
            for x in stride(from: -3.0 as Float,through: 3,by: 0.5) {
                for z in stride(from: -2.0 as Float,through: 2,by: 0.5) {
                    expect(recipe.height(x: p.x+x,z: p.z+z) == p.y,"Guide terrace not flat")
                    expect(!recipe.allowsProp(x: p.x+x,z: p.z+z),"Guide area accepts random prop")
                }
            }
        }
        for edge in MountainRegionRecipe.edges {
            expect(recipe.route(edge,t: 0) == recipe.position(edge.from),"Broken path start")
            expect(simd_distance(recipe.route(edge,t: 1),recipe.position(edge.to)) < 0.001,"Broken path end")
            for i in 0...100 {
                let p = recipe.route(edge,t: Float(i)/100)
                expect(!recipe.allowsProp(x: p.x,z: p.z),"Path allows clutter")
                expect(recipe.height(x: p.x,z: p.z).isFinite,"Invalid height")
            }
        }
    }
}
let recipe = MountainRegionRecipe(seed: 17,region: 2)
for level in [MountainDetail.near,.middle,.silhouette] {
    let a = MountainMeshBuilder.regionTile(recipe: recipe,tile: .init(x: 0,z: -1),detail: .near)
    let b = MountainMeshBuilder.regionTile(recipe: recipe,tile: .init(x: 1,z: -1),detail: level)
    let edgeA = Set(a[0].positions.filter { $0.x == 32 && $0.z >= -32 && $0.z <= 0 })
    let edgeB = Set(b[0].positions.filter { $0.x == 32 && $0.z >= -32 && $0.z <= 0 })
    expect(edgeA == edgeB && edgeA.count == 17,"LOD boundary seam")
    for batch in b {
        expect(batch.positions.allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.z.isFinite },"Invalid vertices")
        expect(batch.normals.allSatisfy { abs(simd_length($0)-1) < 0.001 },"Invalid normals")
    }
    let count = b.reduce(0) { $0+$1.positions.count/3 }
    expect(count < 35000,"Tile triangle budget exceeded")
    print("LOD \(level): \(count) triangles")
}
let tile = MountainTile(x: 0,z: 0)
let first = MountainMeshBuilder.regionTile(recipe: recipe,tile: tile,detail: .near)
let second = MountainMeshBuilder.regionTile(recipe: recipe,tile: tile,detail: .near)
expect(zip(first,second).allSatisfy { $0.positions == $1.positions },"Non-deterministic mesh")
print("PASS: all fork combinations, rejoins, revisits, next region, early abort, duplicate completion, persistence, clocks, clear guide areas and three seamless LODs")

// Actual store round-trip, corruption protection and independent storage keys.
MainActor.assumeIsolated {
    let suite = "vindla.mountain.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(37,forKey: "mountainJourney.preview.stage.v2")
    let garden = Data("existing collection ledger".utf8)
    defaults.set(garden,forKey: "vindla.stillnessGarden.v1")
    let store = MountainJourneyStore(defaults: defaults)
    let session = context(.start)
    expect(store.complete(session,at: 400,reachedEnd: true),"Store did not credit")
    expect(!store.complete(session,at: 500,reachedEnd: true),"Store duplicate credit")
    expect(store.arrive(.init(region: 0,place: .pineGlade)),"Store arrival failed")
    let reloaded = MountainJourneyStore(defaults: defaults)
    expect(reloaded.progress == store.progress,"Stored arrival/completion lost")
    expect(defaults.integer(forKey: "mountainJourney.preview.stage.v2") == 37,"Legacy prototype changed")
    expect(defaults.data(forKey: "vindla.stillnessGarden.v1") == garden,"Collection ledger changed")
    let bad = Data("unreadable".utf8)
    defaults.set(bad,forKey: "mountainJourney.region.preview.v1")
    let corrupt = MountainJourneyStore(defaults: defaults)
    expect(corrupt.storageUnavailable,"Corrupt save silently reset")
    expect(!corrupt.complete(context(.start),at: 500,reachedEnd: true),"Corrupt store credited")
    expect(defaults.data(forKey: "mountainJourney.region.preview.v1") == bad,"Corrupt data overwritten")
}
print("PASS: store round-trip, duplicate protection, corruption preservation, independent collection progress")

#if DEBUG
MainActor.assumeIsolated {
    let suite = "vindla.mountain.preview.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MountainJourneyStore(defaults: defaults)
    for _ in 0..<14 {
        let target = store.nextPreviewAddress!
        expect(store.arriveForPreview(target), "Preview arrival rejected")
        expect(!store.arriveForPreview(target), "Duplicate preview arrival accepted")
        expect(MountainJourneyStore(defaults: defaults).progress == store.progress, "Preview arrival not saved")
    }
    expect(store.progress.current == .init(region: 2, place: .mossGate), "Preview did not continue into new regions")
    expect(store.progress.discovered.count == 15, "Preview repeated a world")
    expect(store.progress.completed.isEmpty && store.progress.opened.isEmpty && store.progress.creditedSessions.isEmpty,
           "Preview incorrectly rewarded meditation")
}
print("PASS: preview travel across regions persists without meditation credit")
#endif

// Session lengths and independent saved preferences survive a fresh decode.
expect(MountainSessionContext.Mode.guided.durations == [5,10,15,20,25,30], "Guided duration range")
expect(MountainSessionContext.Mode.silent.durations == Array(stride(from: 5,through: 120,by: 5)), "Silent duration range")
var preferences = MountainMeditationPreferences()
preferences[.guided] = .init(minutes: 30,intention: "Vila",ambience: "Rain Ambience")
preferences[.silent] = .init(minutes: 120,intention: "",ambience: "None")
let encodedPreferences = try! JSONEncoder().encode(preferences)
expect(MountainMeditationPreferences.restore(encodedPreferences) == preferences, "Preferences not restored")
expect(MountainMeditationPreferences.restore(Data()) == MountainMeditationPreferences(), "First launch defaults")
let legacyAudio = Data(#"{"guided":{"minutes":25,"intention":"Rest","ambience":"Rain Ambience"},"silent":{"minutes":90,"intention":"","ambience":"None"}}"#.utf8)
let migratedAudio = MountainMeditationPreferences.restore(legacyAudio)
expect(migratedAudio.guided.minutes == 25 && migratedAudio.guided.ambience == "Rain Ambience", "Legacy audio migration lost preferences")
expect(migratedAudio.guided.startSound == "None" && migratedAudio.silent.endSound == "None" && !migratedAudio.silent.breathingCues, "Migration enabled unwanted audio")
var audioPreferences = MountainMeditationPreferences()
audioPreferences[.guided] = .init(minutes: 15, ambience: "Green Canopy", startSound: "Temple Bell",
    endSound: "Bamboo Chime", breathingCues: true, ambienceVolume: 0.3, cueVolume: 0.7)
expect(MountainMeditationPreferences.restore(try! JSONEncoder().encode(audioPreferences)) == audioPreferences, "Audio choices did not persist")
expect(audioPreferences.silent.startSound == "None" && audioPreferences.silent.ambience == "None" && !audioPreferences.silent.breathingCues, "Guided sound preferences leaked into silent mode")
audioPreferences[.guided].cueVolume = 9
audioPreferences[.silent].ambienceVolume = -1
expect(audioPreferences.guided.cueVolume == 1 && audioPreferences.silent.ambienceVolume == 0, "Volume out of bounds")
preferences[.guided].minutes = 120
expect(preferences[.guided].minutes == 10 && preferences[.silent].minutes == 120, "Mode ranges leaked")
let longSession = MountainSessionContext(id: UUID(),address: .start,mode: .silent,durationSeconds: 7200,startedAtUptime: 100)
expect(longSession.elapsed(at: 3700) == 3600 && longSession.elapsed(at: 7300) == 7200, "Two-hour elapsed time")
print("PASS: guided 5–30, silent 5–120, independent preference restoration and two-hour timing")
