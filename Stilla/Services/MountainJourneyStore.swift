import Foundation
import Observation

@MainActor @Observable
final class MountainJourneyStore {
    static let shared = MountainJourneyStore()
    private(set) var progress = MountainJourneyProgress()
    private(set) var storageUnavailable = false
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "mountainJourney.region.preview.v1") {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key) {
            do {
                let saved = try JSONDecoder().decode(MountainJourneyProgress.self, from: data)
                guard saved.generatorVersion == MountainRegionRecipe.version,
                      saved.current.region >= 0, saved.discovered.contains(saved.current),
                      saved.discovered.allSatisfy({ $0.region >= 0 }) else {
                    storageUnavailable = true
                    return
                }
                progress = saved
            } catch { storageUnavailable = true }
        }
    }
    @discardableResult func arrive(_ address: MountainPlaceAddress) -> Bool {
        guard !storageUnavailable, progress.arrive(address) else { return false }
        save()
        return true
    }
    #if DEBUG
    var nextPreviewAddress: MountainPlaceAddress? {
        let places = MountainRegionRecipe.PlaceID.allCases
        guard let index = places.firstIndex(of: progress.current.place) else { return nil }
        if index + 1 < places.count {
            return .init(region: progress.current.region, place: places[index + 1])
        }
        guard progress.current.region < Int.max - 1 else { return nil }
        return .init(region: progress.current.region + 1, place: .mossGate)
    }

    // Preview travel records only an arrival, never a completed meditation or reward.
    @discardableResult func arriveForPreview(_ address: MountainPlaceAddress) -> Bool {
        guard !storageUnavailable, address == nextPreviewAddress else { return false }
        progress.current = address
        progress.discovered.insert(address)
        save()
        return true
    }
    #endif
    @discardableResult func complete(_ session: MountainSessionContext, at uptime: TimeInterval,
                                     reachedEnd: Bool) -> Bool {
        guard !storageUnavailable, progress.complete(session, at: uptime, reachedEnd: reachedEnd) else { return false }
        save()
        return true
    }
    private func save() {
        guard let data = try? JSONEncoder().encode(progress) else { storageUnavailable = true; return }
        defaults.set(data, forKey: key)
    }
}
