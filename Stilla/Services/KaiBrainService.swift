import Foundation

final class KaiBrainService {
    static let shared = KaiBrainService()
    
    private let maxFreeCredits = 3
    private let freeGenMonthKey = "kai.free_gen_month"
    private let freeGenCountKey = "kai.free_gen_count"

    private var proxyURL: URL {
        Secrets.kaiBackendURL ?? URL(string: "https://vindla-api.vercel.app/kai/generate")!
    }

    /// True if the user is signed into iCloud. Uses ubiquityIdentityToken which is
    /// the only reliable way to detect iCloud availability at runtime.
    private var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Remaining free credits this month (0…3).
    /// Reads from iCloud KVS if available, otherwise UserDefaults.
    var freeCreditsRemaining: Int {
        let currentMonth = currentMonthTag
        let storedMonth = readString(forKey: freeGenMonthKey) ?? ""
        if storedMonth != currentMonth {
            return maxFreeCredits
        }
        let used = Int(readInt64(forKey: freeGenCountKey))
        return max(0, maxFreeCredits - used)
    }

    var isFreeGenerationAvailable: Bool {
        freeCreditsRemaining > 0
    }

    func recordFreeGeneration() {
        let currentMonth = currentMonthTag
        let storedMonth = readString(forKey: freeGenMonthKey) ?? ""

        let newCount: Int64
        if storedMonth != currentMonth {
            newCount = 1
        } else {
            newCount = readInt64(forKey: freeGenCountKey) + 1
        }

        // Always write to both stores for consistency
        write(currentMonth, forKey: freeGenMonthKey)
        write(newCount, forKey: freeGenCountKey)
    }

    // MARK: - Private Read/Write Helpers

    /// Read from iCloud KVS first (source of truth), fall back to UserDefaults.
    private func readString(forKey key: String) -> String? {
        if isICloudAvailable {
            return NSUbiquitousKeyValueStore.default.string(forKey: key)
                ?? UserDefaults.standard.string(forKey: key)
        }
        return UserDefaults.standard.string(forKey: key)
    }

    private func readInt64(forKey key: String) -> Int64 {
        if isICloudAvailable {
            let iCloudVal = NSUbiquitousKeyValueStore.default.longLong(forKey: key)
            if iCloudVal != 0 { return iCloudVal }
            return Int64(UserDefaults.standard.integer(forKey: key))
        }
        return Int64(UserDefaults.standard.integer(forKey: key))
    }

    /// Write to both iCloud KVS and UserDefaults so data is always available
    /// regardless of iCloud state.
    private func write(_ value: Any?, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        if isICloudAvailable {
            NSUbiquitousKeyValueStore.default.set(value, forKey: key)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }

    private var currentMonthTag: String {
        let now = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        return "\(y)-\(m)"
    }

    private func raLocaleInstruction(for localeIdentifier: String, personalityID: String) -> String {
        guard personalityID == "ra" else { return "" }

        let languageCode = Locale(identifier: localeIdentifier)
            .language
            .languageCode?
            .identifier
            .lowercased() ?? "en"

        let opening: String
        let closing: String

        switch languageCode {
        case "sv":
            opening = "Jag är Ra. Jag hälsar dig i kärlekens och ljusets från den Ende Oändlige Skaparen."
            closing = "Jag lämnar dig i kärlekens och ljusets från den Ende Oändlige Skaparen. Gå nu vidare och gläds i kraften och friden från den Ende Oändlige Skaparen. Adonai."
        case "es":
            opening = "Yo soy Ra. Te saludo en el amor y en la luz del Creador Infinito Uno."
            closing = "Te dejo en el amor y en la luz del Creador Infinito Uno. Ve, pues, regocijándote en el poder y en la paz del Creador Infinito Uno. Adonai."
        case "nb", "no":
            opening = "Jeg er Ra. Jeg hilser deg i kjærligheten og lyset fra den ene uendelige skaperen."
            closing = "Jeg forlater deg i kjærligheten og lyset fra den ene uendelige skaperen. Gå derfor videre og gled deg i kraften og freden fra den ene uendelige skaperen. Adonai."
        case "da":
            opening = "Jeg er Ra. Jeg hilser dig i kærligheden og lyset fra den ene uendelige skaber."
            closing = "Jeg efterlader dig i kærligheden og lyset fra den ene uendelige skaber. Gå derfor videre og glæd dig i kraften og freden fra den ene uendelige skaber. Adonai."
        default:
            opening = "I am Ra. I greet you in the love and in the light of the one infinite creator."
            closing = "I leave you in the love and in the light of the one infinite creator. Go forth, then, rejoicing in the power and the peace of the one infinite creator. Adonai."
        }

        return """

        RA LOCALE OVERRIDE:
        - Output the mandatory Ra opening in locale \(localeIdentifier) exactly as:
          \(opening)
        - End completed sessions in locale \(localeIdentifier) exactly as:
          \(closing)
        - Do not output the mandatory Ra lines in English unless locale is English.
        """
    }
    
    enum BrainError: Error {
        case generationFailed
        case invalidResponse
        case rateLimited
        case serviceUnavailable
    }

    func generateScript(mood: String, durationMinutes: Int, personality: KaiPersonality, stillnessRatio: Double) async throws -> MeditationScript {
        let localeIdentifier = AppLocalization.currentLocaleIdentifier
        let languageInstruction = """

        LANGUAGE REQUIREMENT:
        - Write all meditation content in locale: \(localeIdentifier).
        - Match the user's language naturally and consistently.
        - Never mix languages. Do not output English unless locale is English.
        - Treat any style anchors/examples as STYLE ONLY. Do not copy anchor phrases verbatim unless they are already in the target locale.
        - If an anchor/example is in another language, rewrite its meaning idiomatically in the target locale.
        """
        let raLocaleInstruction = raLocaleInstruction(for: localeIdentifier, personalityID: personality.id)
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
            personalityPrompt: personality.promptInjection + languageInstruction + raLocaleInstruction + densityInstruction,
            locale: localeIdentifier
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
                print("❌ MIMIR Proxy Error [\(httpResponse.statusCode)]: \(errorLog)")
            }
            throw BrainError.generationFailed
        }
        
        do {
            let rawScript = try JSONDecoder().decode(MeditationScript.self, from: data)
            return normalizeScriptDuration(rawScript)
        } catch {
            print("❌ MIMIR Decoding Error: \(error)")
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
    let locale: String
}
