import Foundation
import Observation

@MainActor @Observable
final class DestinationJourneyStore {
    static let shared = DestinationJourneyStore()
    private(set) var catalog: DestinationCatalog?
    private(set) var progress = DestinationProgress()
    private(set) var storageUnavailable = false
    private let defaults: UserDefaults
    private let progressKey = "destinationJourney.progress.v1"

    init(defaults: UserDefaults = .standard, catalogURL: URL? = Bundle.main.url(
        forResource: "destinations", withExtension: "json", subdirectory: "Journeys")) {
        self.defaults = defaults
        do {
            guard let catalogURL else { throw DestinationCatalog.ValidationError.invalidCatalog }
            catalog = try JSONDecoder().decode(DestinationCatalog.self, from: Data(contentsOf: catalogURL)).validated()
            if let data = defaults.data(forKey: progressKey) {
                progress = try JSONDecoder().decode(DestinationProgress.self, from: data)
            }
            if let catalog { progress.reconcile(with: catalog) }
            save()
        } catch {
            // Never overwrite unreadable progress with an empty journey.
            storageUnavailable = true
        }
    }

    var firstDestination: JourneyDestination? { catalog?.destinations.first }

    func steps(for destination: JourneyDestination) -> Int {
        min(destination.totalSteps, max(0, progress.steps[destination.id, default: 0]))
    }

    func canStart(_ destination: JourneyDestination) -> Bool {
        !storageUnavailable && destination.isAvailable && progress.hasAccess(
            to: destination, purchasedProductIDs: StoreKitManager.shared.purchasedProductIDs)
    }

    @discardableResult
    func complete(_ session: DestinationSession, elapsedSeconds: Int, reachedEnd: Bool) -> Bool {
        guard !storageUnavailable, let catalog else { return false }
        let credited = progress.credit(session, elapsedSeconds: elapsedSeconds, reachedEnd: reachedEnd,
            catalog: catalog, purchasedProductIDs: StoreKitManager.shared.purchasedProductIDs)
        if credited { save() }
        return credited
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(progress) else { storageUnavailable = true; return }
        defaults.set(data, forKey: progressKey)
    }
}
