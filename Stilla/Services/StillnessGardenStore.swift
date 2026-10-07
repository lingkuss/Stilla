import Foundation
import Observation

@MainActor @Observable final class StillnessGardenStore {
    static let shared = StillnessGardenStore()
    private(set) var flowers: [GardenSpecimen] = []
    private(set) var crystals: [GardenSpecimen] = []
    private(set) var trees: [GardenSpecimen] = []
    private(set) var meditationCount = 0
    private(set) var storageUnavailable = false
    @ObservationIgnored private var garden = StillnessGarden()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String
    func specimens(_ kind: GardenKind) -> [GardenSpecimen] {
        switch kind { case .flower: flowers; case .crystal: crystals; case .tree: trees }
    }
    func remaining(_ kind: GardenKind) -> Int { kind.interval - meditationCount % kind.interval }
    var earnedNoticeKey: String? {
        guard meditationCount > 0 else { return nil }
        if meditationCount.isMultiple(of: 100) { return "garden.earned.tree" }
        if meditationCount.isMultiple(of: 50) { return "garden.earned.both" }
        if meditationCount.isMultiple(of: 25) { return "garden.earned.crystal" }
        if meditationCount.isMultiple(of: 10) { return "garden.earned.flower" }
        return nil
    }
    // The whole collection is retained. Only a bounded garden is meshed in the world.
    var worldSpecimens: [GardenSpecimen] { Array(flowers.suffix(128)) + Array(crystals.suffix(12)) + Array(trees.suffix(4)) }

    init(defaults: UserDefaults = .standard, key: String = "vindla.stillnessGarden.v1") {
        self.defaults = defaults
        self.key = key
        if defaults.object(forKey: key) != nil {
            guard let data = defaults.data(forKey: key),
                  let saved = try? JSONDecoder().decode(StillnessGarden.self, from: data), saved.isValid else {
                storageUnavailable = true
                return
            }
            garden = saved
        }
        refresh()
    }

    @discardableResult func record(sessionID: UUID, at date: Date = Date()) -> Bool {
        guard !storageUnavailable else { return false }
        var next = garden
        guard next.record(sessionID: sessionID, at: date) else { return false }
        do {
            let data = try JSONEncoder().encode(next)
            defaults.set(data, forKey: key)
            garden = next
            refresh()
            return true
        } catch { storageUnavailable = true; return false }
    }

    private func refresh() {
        flowers = garden.specimens(.flower)
        crystals = garden.specimens(.crystal)
        trees = garden.specimens(.tree)
        meditationCount = garden.completions.count
    }

    #if DEBUG
    enum MockError: Error { case invalidCount, unavailable, missingBackup }

    /// Explicit development launch command only. The first real ledger is kept
    /// across repeated mock runs, and restore removes the marker for a new run.
    func setMockMeditations(_ count: Int, backupURL: URL? = nil) throws {
        guard (0...1000).contains(count) else { throw MockError.invalidCount }
        guard !storageUnavailable else { throw MockError.unavailable }
        var mock = StillnessGarden()
        let now = Date()
        for i in 0..<count {
            let id = UUID(uuidString: String(format: "A11CE000-0000-4000-8000-%012d",i))!
            mock.record(sessionID: id,at: now.addingTimeInterval(-Double(count-1-i)*86_400))
        }
        let encoded = try JSONEncoder().encode(mock)
        let backup = try defaults.data(forKey: key+".beforeMock") ?? defaults.data(forKey: key) ?? JSONEncoder().encode(garden)
        if let backupURL { try backup.write(to: backupURL,options: .atomic) }
        defaults.set(backup,forKey: key+".beforeMock")
        defaults.set(encoded,forKey: key)
        garden = mock
        refresh()
    }

    func restoreBeforeMock() throws {
        guard let data = defaults.data(forKey: key+".beforeMock") else { throw MockError.missingBackup }
        let restored = try JSONDecoder().decode(StillnessGarden.self,from: data)
        guard restored.isValid else { throw MockError.unavailable }
        defaults.set(data,forKey: key)
        defaults.removeObject(forKey: key+".beforeMock")
        garden = restored
        storageUnavailable = false
        refresh()
    }

    /// Isolated visual fixture: never changes the user's real rewards.
    static func preview(count: Int) -> StillnessGardenStore {
        let suite = "vindla.garden.preview"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = StillnessGardenStore(defaults: defaults)
        let boundedCount = min(1000, max(0, count))
        for i in 0..<boundedCount {
            let id = UUID(uuidString: String(format: "A11CE000-0000-4000-8000-%012d", i))!
            store.garden.record(sessionID: id, at: Date(timeIntervalSince1970: 1_790_848_800 - Double(boundedCount-1-i)*86_400))
        }
        store.refresh()
        return store
    }
    #endif
}
