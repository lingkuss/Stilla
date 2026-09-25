import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let catalogURL = URL(fileURLWithPath: "Stilla/Resources/Journeys/destinations.json")
let catalog = try JSONDecoder().decode(DestinationCatalog.self, from: Data(contentsOf: catalogURL)).validated()
let temple = catalog.destinations[0]
let next = catalog.destinations[1]
var progress = DestinationProgress()
progress.reconcile(with: catalog)
check(progress.hasAccess(to: temple), "The first place must be open")
check(!progress.hasAccess(to: next), "The next place must initially be locked")

func session(_ destination: String = "borobudur", _ mode: DestinationMeditationMode = .silent) -> DestinationSession {
    DestinationSession(id: UUID(), destinationID: destination, mode: mode, durationSeconds: 300, startedAtUptime: 100)
}

let partial = session()
check(!progress.credit(partial, elapsedSeconds: 299, reachedEnd: true, catalog: catalog), "Early completion cannot earn a step")
check(!progress.credit(partial, elapsedSeconds: 300, reachedEnd: false, catalog: catalog), "Cancellation cannot earn a step")
check(progress.steps.isEmpty, "Cancelled sessions leave progress unchanged")
check(partial.elapsed(at: 105) == 5 && partial.elapsed(at: 900) == 300, "Resume clamps the elapsed clock")
check(partial.elapsed(at: 90) == 0, "Clock cannot create negative progress")
check(progress.credit(partial, elapsedSeconds: 300, reachedEnd: true, catalog: catalog), "A complete silent session earns one step")
check(!progress.credit(partial, elapsedSeconds: 300, reachedEnd: true, catalog: catalog), "A duplicate completion cannot earn a second step")
progress = try JSONDecoder().decode(DestinationProgress.self, from: JSONEncoder().encode(progress))
check(!progress.credit(partial, elapsedSeconds: 300, reachedEnd: true, catalog: catalog), "Deduplication survives a restart")
check(!progress.credit(session("tigers-nest"), elapsedSeconds: 300, reachedEnd: true, catalog: catalog), "Unavailable places cannot earn steps")

for _ in 1..<temple.totalSteps {
    check(progress.credit(session("borobudur", .guided), elapsedSeconds: 300, reachedEnd: true, catalog: catalog), "Guided and silent sessions must earn equally")
}
check(progress.steps[temple.id] == 7, "Summit requires all seven steps")
check(progress.hasAccess(to: next), "Reaching the summit unlocks its successor")
check(!progress.hasAccess(to: catalog.destinations[2]), "Completing one place does not unlock every place")
check(!progress.credit(session(), elapsedSeconds: 300, reachedEnd: true, catalog: catalog), "Revisiting the summit does not overflow its steps")

// Insert a new destination between existing places; previously earned access survives.
let inserted = JourneyDestination(id: "new-temple", name: "New", locationKey: "test", totalSteps: 10,
    prerequisiteID: "borobudur", backgroundAsset: nil, isAvailable: false, productID: nil, milestones: temple.milestones)
let reorderedNext = JourneyDestination(id: next.id, name: next.name, locationKey: next.locationKey,
    totalSteps: next.totalSteps, prerequisiteID: inserted.id, backgroundAsset: nil,
    isAvailable: false, productID: nil, milestones: next.milestones)
let revised = try DestinationCatalog(version: 1, destinations: [temple, inserted, reorderedNext]).validated()
progress.reconcile(with: revised)
check(progress.hasAccess(to: reorderedNext), "Catalog insertion must preserve previously earned access")
check(progress.hasAccess(to: inserted), "Already completed prerequisites open newly added places")

let paid = JourneyDestination(id: "paid", name: "Paid", locationKey: "test", totalSteps: 1,
    prerequisiteID: "borobudur", backgroundAsset: "test", isAvailable: true,
    productID: "test.destination", milestones: [JourneyMilestone(step: 0, titleKey: "test", sceneScale: 1)])
let paidNext = JourneyDestination(id: "paid-next", name: "Next", locationKey: "test", totalSteps: 1,
    prerequisiteID: paid.id, backgroundAsset: nil, isAvailable: false, productID: nil, milestones: paid.milestones)
let paidCatalog = try DestinationCatalog(version: 1, destinations: [temple, paid, paidNext]).validated()
var buyer = DestinationProgress()
check(!buyer.hasAccess(to: paid), "A product ID alone is not an entitlement")
check(buyer.hasAccess(to: paid, purchasedProductIDs: ["test.destination"]), "Verified ownership grants access")
check(buyer.steps[paid.id] == nil && buyer.completedDestinationIDs.isEmpty, "Buying does not grant steps or completion")
check(buyer.credit(session(paid.id), elapsedSeconds: 300, reachedEnd: true, catalog: paidCatalog,
    purchasedProductIDs: ["test.destination"]), "Bought destinations can be completed")
check(buyer.hasAccess(to: paidNext), "Completing a bought place unlocks its successor")
check(!buyer.completedDestinationIDs.contains(temple.id), "Skipped places remain incomplete")

do {
    _ = try DestinationCatalog(version: 1, destinations: [temple, temple]).validated()
    fatalError("Duplicate content IDs must be rejected")
} catch DestinationCatalog.ValidationError.invalidCatalog { }
do {
    _ = try DestinationCatalog(version: 1, destinations: [next, temple]).validated()
    fatalError("Dangling or cyclic prerequisites must be rejected")
} catch DestinationCatalog.ValidationError.invalidCatalog { }
print("PASS: catalog, silent/guided completion, cancellation, duplicate/restart safety, summit, catalog insertion, purchase access and clocks")
