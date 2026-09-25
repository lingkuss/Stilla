import Foundation

/// Content, access and progress are separate so a catalog update never renumbers a user's journey.
struct JourneyDestination: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let locationKey: String
    let totalSteps: Int
    let prerequisiteID: String?
    let backgroundAsset: String?
    let isAvailable: Bool
    let productID: String?
    let milestones: [JourneyMilestone]
    var elevationMeters: Double? = nil

    func milestone(at steps: Int) -> JourneyMilestone {
        milestones.last(where: { $0.step <= steps }) ?? milestones[0]
    }
}

struct JourneyMilestone: Codable, Equatable {
    let step: Int
    let titleKey: String
    /// A restrained crop, not a claim that the illustrated environment is navigable 3D.
    let sceneScale: Double
}

struct DestinationCatalog: Codable {
    let version: Int
    let destinations: [JourneyDestination]

    enum ValidationError: Error { case invalidCatalog }

    func validated() throws -> Self {
        guard version == 1, !destinations.isEmpty,
              Set(destinations.map(\.id)).count == destinations.count else {
            throw ValidationError.invalidCatalog
        }
        var preceding = Set<String>()
        var previousElevation: Double = 0
        for destination in destinations {
            guard !destination.id.isEmpty, destination.totalSteps > 0,
                  !destination.milestones.isEmpty, destination.milestones.first?.step == 0,
                  destination.milestones.map(\.step) == destination.milestones.map(\.step).sorted(),
                  Set(destination.milestones.map(\.step)).count == destination.milestones.count,
                  destination.milestones.allSatisfy({
                      (0...destination.totalSteps).contains($0.step)
                      && $0.sceneScale.isFinite && (1...1.2).contains($0.sceneScale)
                  }),
                  destination.prerequisiteID.map({ preceding.contains($0) }) ?? true,
                  !destination.isAvailable || destination.backgroundAsset != nil else {
                throw ValidationError.invalidCatalog
            }
            if let elevation = destination.elevationMeters {
                guard elevation.isFinite, elevation > previousElevation else {
                    throw ValidationError.invalidCatalog
                }
                previousElevation = elevation
            }
            preceding.insert(destination.id)
        }
        return self
    }

    func destination(_ id: String) -> JourneyDestination? {
        destinations.first { $0.id == id }
    }
}

enum DestinationMeditationMode: String, Codable, CaseIterable {
    case guided, silent
}

struct DestinationSession: Identifiable {
    let id: UUID
    let destinationID: String
    let mode: DestinationMeditationMode
    let durationSeconds: Int
    let startedAtUptime: TimeInterval

    func elapsed(at uptime: TimeInterval) -> Int {
        min(durationSeconds, max(0, Int(uptime - startedAtUptime)))
    }
}

struct DestinationProgress: Codable, Equatable {
    var steps: [String: Int] = [:]
    var completedDestinationIDs: Set<String> = []
    var earnedAccessIDs: Set<String> = []
    var creditedSessionIDs: Set<UUID> = []

    func hasAccess(to destination: JourneyDestination, purchasedProductIDs: Set<String> = []) -> Bool {
        destination.prerequisiteID == nil
            || earnedAccessIDs.contains(destination.id)
            || completedDestinationIDs.contains(destination.id)
            || destination.productID.map { purchasedProductIDs.contains($0) } == true
            || destination.prerequisiteID.map { completedDestinationIDs.contains($0) } == true
    }

    /// Call on catalog updates as well as completion. Earned access survives insertion/reordering.
    mutating func reconcile(with catalog: DestinationCatalog) {
        for destination in catalog.destinations {
            if destination.prerequisiteID == nil
                || destination.prerequisiteID.map({ completedDestinationIDs.contains($0) }) == true {
                earnedAccessIDs.insert(destination.id)
            }
        }
    }

    @discardableResult
    mutating func credit(_ session: DestinationSession, elapsedSeconds: Int,
                         reachedEnd: Bool, catalog: DestinationCatalog,
                         purchasedProductIDs: Set<String> = []) -> Bool {
        guard reachedEnd, session.durationSeconds > 0, elapsedSeconds >= session.durationSeconds,
              !creditedSessionIDs.contains(session.id),
              let destination = catalog.destination(session.destinationID), destination.isAvailable,
              hasAccess(to: destination, purchasedProductIDs: purchasedProductIDs),
              !completedDestinationIDs.contains(destination.id) else { return false }
        creditedSessionIDs.insert(session.id)
        let count = min(destination.totalSteps, max(0, steps[destination.id, default: 0]) + 1)
        steps[destination.id] = count
        // Access bought via StoreKit is not converted to earned access until the place is completed.
        if count == destination.totalSteps {
            completedDestinationIDs.insert(destination.id)
            earnedAccessIDs.insert(destination.id)
        }
        reconcile(with: catalog)
        return true
    }
}
