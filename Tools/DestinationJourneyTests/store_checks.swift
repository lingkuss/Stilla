import Foundation

@MainActor final class StoreKitManager {
    static let shared = StoreKitManager()
    var purchasedProductIDs: Set<String> = []
}

@main struct StoreChecks {
    @MainActor static func main() throws {
        let suite = "vindla.journey.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let url = URL(fileURLWithPath: "Stilla/Resources/Journeys/destinations.json")
        let store = DestinationJourneyStore(defaults: defaults, catalogURL: url)
        precondition(!store.storageUnavailable)
        let place = store.firstDestination!
        let session = DestinationSession(id: UUID(), destinationID: place.id, mode: .silent,
            durationSeconds: 300, startedAtUptime: 0)
        precondition(store.complete(session, elapsedSeconds: 300, reachedEnd: true))
        let restored = DestinationJourneyStore(defaults: defaults, catalogURL: url)
        precondition(restored.steps(for: place) == 1)
        precondition(!restored.complete(session, elapsedSeconds: 300, reachedEnd: true))
        let corruptData = Data("do not overwrite".utf8)
        defaults.set(corruptData, forKey: "destinationJourney.progress.v1")
        let corrupt = DestinationJourneyStore(defaults: defaults, catalogURL: url)
        precondition(corrupt.storageUnavailable && !corrupt.canStart(place))
        precondition(defaults.data(forKey: "destinationJourney.progress.v1") == corruptData)
        let missing = DestinationJourneyStore(defaults: defaults, catalogURL: nil)
        precondition(missing.storageUnavailable && missing.catalog == nil)
        print("PASS: real UserDefaults persistence, restart deduplication, corrupt-progress preservation and missing catalog")
    }
}
