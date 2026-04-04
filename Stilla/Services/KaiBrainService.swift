import Foundation

/// Internal protocol to allow seamless switching between iCloud KVS and UserDefaults.
protocol KeyValueStoring {
    func set(_ value: Any?, forKey defaultName: String)
    func string(forKey defaultName: String) -> String?
    func longLong(forKey defaultName: String) -> Int64
    func synchronize() -> Bool
}

class UserDefaultsStore: KeyValueStoring {
    func set(_ value: Any?, forKey defaultName: String) { UserDefaults.standard.set(value, forKey: defaultName) }
    func string(forKey defaultName: String) -> String? { UserDefaults.standard.string(forKey: defaultName) }
    func longLong(forKey defaultName: String) -> Int64 { Int64(UserDefaults.standard.integer(forKey: defaultName)) }
    func synchronize() -> Bool { UserDefaults.standard.synchronize() }
}

class ICloudStore: KeyValueStoring {
    func set(_ value: Any?, forKey defaultName: String) { NSUbiquitousKeyValueStore.default.set(value, forKey: defaultName) }
    func string(forKey defaultName: String) -> String? { NSUbiquitousKeyValueStore.default.string(forKey: defaultName) }
    func longLong(forKey defaultName: String) -> Int64 { NSUbiquitousKeyValueStore.default.longLong(forKey: defaultName) }
    func synchronize() -> Bool { NSUbiquitousKeyValueStore.default.synchronize() }
}

final class KaiBrainService {
    static let shared = KaiBrainService()
    
    private let maxFreeCredits = 3
    private let freeGenMonthKey = "kai.free_gen_month"
    private let freeGenCountKey = "kai.free_gen_count"

    private var proxyURL: URL {
        Secrets.kaiBackendURL ?? URL(string: "https://stilla-three.vercel.app/kai/generate")!
    }

    /// Strategy: Probe for iCloud first. If unavailable (e.g. personal dev team),
    /// fall back to local UserDefaults.
    private var store: KeyValueStoring {
        if NSUbiquitousKeyValueStore.default.synchronize() {
            return ICloudStore()
        }
        return UserDefaultsStore()
    }

    /// Remaining free credits this month (0…3).
    var freeCreditsRemaining: Int {
        let currentMonth = currentMonthTag
        let storedMonth = store.string(forKey: freeGenMonthKey) ?? ""
        if storedMonth != currentMonth {
            return maxFreeCredits
        }
        let used = Int(store.longLong(forKey: freeGenCountKey))
        return max(0, maxFreeCredits - used)
    }

    var isFreeGenerationAvailable: Bool {
        freeCreditsRemaining > 0
    }

    func recordFreeGeneration() {
        let currentMonth = currentMonthTag
        let storedMonth = store.string(forKey: freeGenMonthKey) ?? ""

        if storedMonth != currentMonth {
            store.set(currentMonth, forKey: freeGenMonthKey)
            store.set(Int64(1), forKey: freeGenCountKey)
        } else {
            let used = store.longLong(forKey: freeGenCountKey)
            store.set(used + 1, forKey: freeGenCountKey)
        }
        
        // Mirror to both for a smooth future transition
        UserDefaults.standard.set(currentMonth, forKey: freeGenMonthKey)
        let totalUsed = store.longLong(forKey: freeGenCountKey)
        UserDefaults.standard.set(totalUsed, forKey: freeGenCountKey)
        
        _ = store.synchronize()
    }

    private var currentMonthTag: String {
        let now = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        return "\(y)-\(m)"
    }
    
    enum BrainError: Error {
        case generationFailed
        case invalidResponse
        case rateLimited
        case serviceUnavailable
    }

    func generateScript(mood: String, durationMinutes: Int, personality: KaiPersonality) async throws -> MeditationScript {
        let request = KaiGenerationRequest(
            mood: mood,
            durationMinutes: durationMinutes,
            personalityName: personality.name,
            personalityPrompt: personality.promptInjection
        )
        
        var urlRequest = URLRequest(url: proxyURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = Secrets.kaiBackendToken {
            urlRequest.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BrainError.generationFailed
        }
        
        if httpResponse.statusCode == 429 {
            throw BrainError.rateLimited
        }
        
        if httpResponse.statusCode != 200 {
            if let errorLog = String(data: data, encoding: .utf8) {
                print("❌ KAI Proxy Error [\(httpResponse.statusCode)]: \(errorLog)")
            }
            throw BrainError.generationFailed
        }
        
        do {
            let rawScript = try JSONDecoder().decode(MeditationScript.self, from: data)
            return stretchScriptToFit(rawScript)
        } catch {
            print("❌ KAI Decoding Error: \(error)")
            throw BrainError.invalidResponse
        }
    }
    
    private func stretchScriptToFit(_ script: MeditationScript) -> MeditationScript {
        let targetSeconds = Double(script.durationMinutes * 60)
        let totalElapsed = script.steps.reduce(0.0) { sum, step in
            sum + (Double(step.text.count) * 0.12) + step.pauseDuration
        }
        
        if totalElapsed >= targetSeconds { return script }
        
        let diff = targetSeconds - totalElapsed
        let extraPerStep = diff / Double(script.steps.count)
        
        var newSteps = script.steps
        for i in 0..<newSteps.count {
            newSteps[i].pauseDuration += extraPerStep
        }
        
        var script = script
        script.steps = newSteps
        return script
    }
}

private struct KaiGenerationRequest: Codable {
    let mood: String
    let durationMinutes: Int
    let personalityName: String
    let personalityPrompt: String
}
