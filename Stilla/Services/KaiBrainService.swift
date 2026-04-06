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

    func generateScript(mood: String, durationMinutes: Int, personality: KaiPersonality, stillnessRatio: Double) async throws -> MeditationScript {
        let wordBudget = Int(Double(durationMinutes * 150) * (1.0 - stillnessRatio))
        
        let densityInstruction = """
        
        🎯 KAI RHYTHM TARGET:
        The user has requested a Stillness Ratio of \(Int(stillnessRatio * 100))%.
        Your goal is to provide approximately \(wordBudget) words total for this \(durationMinutes) minute journey.

        EXECUTION RULES:
        1. SILENCE IS PRIMARY: To respect the word budget, you MUST use significantly longer 'pauseDuration' values (often 60–180s in high stillness).
        2. JSON SYNC: Ensure the total of all 'text' words is ~\(wordBudget) and the total sum of pauses + reading time is exactly \(durationMinutes * 60) seconds.
        3. ADAPTATION: If you provide very few words, use very few steps with massive pauses.
        """
        
        let request = KaiGenerationRequest(
            mood: mood,
            durationMinutes: durationMinutes,
            personalityName: personality.name,
            personalityPrompt: personality.promptInjection + densityInstruction
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
            return normalizeScriptDuration(rawScript)
        } catch {
            print("❌ KAI Decoding Error: \(error)")
            throw BrainError.invalidResponse
        }
    }
    
    private func normalizeScriptDuration(_ script: MeditationScript) -> MeditationScript {
        let startDelay = 2.0 // GuruManager delay
        let targetSeconds = Double(script.durationMinutes * 60) - startDelay
        let secondsPerChar = 0.07 // Calibrated for typical iOS voice rate
        let minPause: TimeInterval = 1.5 // Minimum gap for clarity
        
        // 1. Calculate pure speaking time
        let speakingTime = script.steps.reduce(0.0) { $0 + (Double($1.text.count) * secondsPerChar) }
        
        // 2. Remaining time available for pauses
        let totalPauseTime = max(Double(script.steps.count) * minPause, targetSeconds - speakingTime)
        
        // 3. Current sum of pauses provided by LLM
        let originalPauseSum = script.steps.reduce(0.0) { $0 + $1.pauseDuration }
        
        var newSteps = script.steps
        
        if originalPauseSum > 0 {
            // Proportional scaling (Shrink or Stretch)
            let scale = totalPauseTime / originalPauseSum
            for i in 0..<newSteps.count {
                newSteps[i].pauseDuration = max(minPause, newSteps[i].pauseDuration * scale)
            }
        } else {
            // Distribute pause time evenly if LLM forgot pauses
            let evenPause = totalPauseTime / Double(newSteps.count)
            for i in 0..<newSteps.count {
                newSteps[i].pauseDuration = max(minPause, evenPause)
            }
        }
        
        var normalized = script
        normalized.steps = newSteps
        return normalized
    }
}

private struct KaiGenerationRequest: Codable {
    let mood: String
    let durationMinutes: Int
    let personalityName: String
    let personalityPrompt: String
}
