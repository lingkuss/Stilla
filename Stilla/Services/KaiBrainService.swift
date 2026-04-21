import Foundation

final class KaiBrainService {
    static let shared = KaiBrainService()
    static let maxAIGenerationDurationMinutes = 30
    
    private let maxFreeCredits = 3
    private let freeGenMonthKey = "kai.free_gen_month"
    private let freeGenCountKey = "kai.free_gen_count"

    private var proxyURL: URL {
        Secrets.kaiBackendURL ?? URL(string: "https://vindla-api.vercel.app/kai/generate")!
    }

    private var sleepStoryURL: URL {
        if let explicit = Secrets.kaiSleepStoryBackendURL {
            return explicit
        }

        guard var components = URLComponents(url: proxyURL, resolvingAgainstBaseURL: false) else {
            return proxyURL
        }
        components.query = nil
        components.fragment = nil
        components.path = "/kai/sleep/generate"
        return components.url ?? proxyURL
    }

    private var practiceJourneyURL: URL {
        guard var components = URLComponents(url: proxyURL, resolvingAgainstBaseURL: false) else {
            return proxyURL
        }
        components.query = nil
        components.fragment = nil
        components.path = "/kai/journey/generate"
        return components.url ?? proxyURL
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

    func generateSleepStory(
        themeTitle: String,
        themeSubtitle: String?,
        durationMinutes: Int,
        excluding recentTitles: [String]
    ) async throws -> SleepStoryGenerationResult {
        let cappedDuration = min(durationMinutes, Self.maxAIGenerationDurationMinutes)
        let localeIdentifier = AppLocalization.currentLocaleIdentifier
        let request = SleepStoryGenerationRequest(
            themeTitle: themeTitle,
            themeSubtitle: themeSubtitle,
            durationMinutes: cappedDuration,
            locale: localeIdentifier,
            excludeTitles: recentTitles
        )

        var urlRequest = URLRequest(url: sleepStoryURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AppAttestAuthManager.shared.authorize(&urlRequest)

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BrainError.generationFailed
        }

        if httpResponse.statusCode != 200 {
            throw BrainError.generationFailed
        }

        let decoder = JSONDecoder()

        let script: MeditationScript
        let headersFromResponse: [SleepStoryHeader]
        if let payload = try? decoder.decode(SleepStoryGenerationEnvelope.self, from: data) {
            script = payload.story
            headersFromResponse = payload.nextHeaders
                .filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else {
            script = try decoder.decode(MeditationScript.self, from: data)
            headersFromResponse = []
        }

        var normalizedScript = script
        normalizedScript = normalizeSleepStoryFlow(normalizedScript)
        normalizedScript.contentType = .sleepStory
        normalizedScript.durationMinutes = cappedDuration
        if normalizedScript.tags.contains(where: { $0.caseInsensitiveCompare("Sleep Story") == .orderedSame }) == false {
            normalizedScript.tags.append("Sleep Story")
        }

        let nextHeaders = headersFromResponse.isEmpty
            ? fallbackSleepStoryHeaders(excluding: recentTitles)
            : headersFromResponse

        return SleepStoryGenerationResult(script: normalizedScript, nextHeaders: nextHeaders)
    }

    func fallbackSleepStoryHeaders(excluding recentTitles: [String], count: Int = 6) -> [SleepStoryHeader] {
        let normalizedRecent = Set(recentTitles.map(Self.normalizedHeaderTitle))
        let available = Self.defaultSleepStoryHeaders.filter { header in
            !normalizedRecent.contains(Self.normalizedHeaderTitle(header.title))
        }

        let source = available.isEmpty ? Self.defaultSleepStoryHeaders : available
        return Array(source.shuffled().prefix(max(1, count)))
    }

    func generatePracticeJourneyPlan(
        goalSummary: String,
        preferredDurationMinutes: Int,
        personality: KaiPersonality,
        stillnessRatio: Double,
        memoryContext: String?,
        historyContext: String?,
        cycleNumber: Int
    ) async throws -> PracticeJourneyPlan {
        let localeIdentifier = AppLocalization.currentLocaleIdentifier
        let request = PracticeJourneyGenerationRequest(
            goalSummary: goalSummary,
            preferredDurationMinutes: min(preferredDurationMinutes, Self.maxAIGenerationDurationMinutes),
            personalityName: personality.name,
            personalityPrompt: personality.promptInjection,
            stillnessRatio: stillnessRatio,
            locale: localeIdentifier,
            memoryContext: memoryContext,
            historyContext: historyContext,
            cycleNumber: max(1, cycleNumber)
        )

        var urlRequest = URLRequest(url: practiceJourneyURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AppAttestAuthManager.shared.authorize(&urlRequest)

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
                print("❌ JOURNEY Proxy Error [\(httpResponse.statusCode)]: \(errorLog)")
            }
            throw BrainError.generationFailed
        }

        do {
            let rawPlan = try JSONDecoder().decode(PracticeJourneyPlanResponse.self, from: data)
            let steps = rawPlan.steps.enumerated().map { offset, step in
                PracticeJourneyStep(
                    dayNumber: step.dayNumber > 0 ? step.dayNumber : offset + 1,
                    title: step.title,
                    focus: step.focus,
                    purpose: step.purpose,
                    meditationPrompt: step.meditationPrompt,
                    adaptationTip: step.adaptationTip,
                    suggestedDurationMinutes: min(max(3, step.suggestedDurationMinutes), Self.maxAIGenerationDurationMinutes)
                )
            }

            return PracticeJourneyPlan(
                title: rawPlan.title,
                summary: rawPlan.summary,
                goalSummary: goalSummary,
                cycleNumber: rawPlan.cycleNumber > 0 ? rawPlan.cycleNumber : cycleNumber,
                personaID: personality.id,
                personaName: personality.name,
                stillnessRatio: stillnessRatio,
                steps: steps
            )
        } catch {
            print("❌ JOURNEY Decoding Error: \(error)")
            throw BrainError.invalidResponse
        }
    }
}

struct SleepStoryGenerationResult {
    let script: MeditationScript
    let nextHeaders: [SleepStoryHeader]
}

extension KaiBrainService {
    func generateScript(mood: String, durationMinutes: Int, personality: KaiPersonality, stillnessRatio: Double) async throws -> MeditationScript {
        let cappedDuration = min(durationMinutes, Self.maxAIGenerationDurationMinutes)
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
        let wordBudget = Int(Double(cappedDuration * 150) * (1.0 - stillnessRatio))
        
        let densityInstruction = """
        
        🎯 KAI RHYTHM TARGET:
        The user has requested a Stillness Ratio of \(Int(stillnessRatio * 100))%.
        Your goal is to provide approximately \(wordBudget) words total for this \(cappedDuration) minute journey.

        EXECUTION RULES:
        1. SILENCE IS PRIMARY: To respect the word budget, you MUST use significantly longer 'pauseDuration' values (often 60–180s in high stillness).
        2. JSON SYNC: Ensure the total of all 'text' words is ~\(wordBudget) and the total sum of pauses + reading time is exactly \(durationMinutes * 60) seconds.
        3. ADAPTATION: If you provide very few words, use very few steps with massive pauses.
        """
        
        let request = KaiGenerationRequest(
            mood: mood,
            durationMinutes: cappedDuration,
            personalityName: personality.name,
            personalityPrompt: personality.promptInjection + languageInstruction + raLocaleInstruction + densityInstruction,
            locale: localeIdentifier
        )
        
        var urlRequest = URLRequest(url: proxyURL)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        try await AppAttestAuthManager.shared.authorize(&urlRequest)
        
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
            var normalized = normalizeScriptDuration(rawScript)
            normalized.durationMinutes = cappedDuration
            return normalized
        } catch {
            print("❌ MIMIR Decoding Error: \(error)")
            throw BrainError.invalidResponse
        }
    }

    func normalizeScriptDuration(_ script: MeditationScript) -> MeditationScript {
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

    func normalizeSleepStoryFlow(_ script: MeditationScript) -> MeditationScript {
        var adjusted = script
        let steps = script.steps.map { step in
            let text = step.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let chars = text.count

            var pause: TimeInterval = 0.9
            if chars > 120 { pause += 0.1 }
            if chars > 190 { pause += 0.15 }
            if text.contains(",") || text.contains(";") { pause += 0.05 }
            if text.contains(".") || text.contains("!") || text.contains("?") { pause += 0.08 }

            // Keep flow gentle and readable with about 1s between story beats.
            pause = min(1.35, max(0.75, pause))
            pause = min(1.6, max(0.75, pause))
            return ScriptStep(text: step.text, pauseDuration: pause)
        }
        adjusted.steps = steps
        return adjusted
    }
}

private struct KaiGenerationRequest: Codable {
    let mood: String
    let durationMinutes: Int
    let personalityName: String
    let personalityPrompt: String
    let locale: String
}

struct SleepStoryHeader: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
}

private struct SleepStoryGenerationRequest: Codable {
    let themeTitle: String
    let themeSubtitle: String?
    let durationMinutes: Int
    let locale: String
    let excludeTitles: [String]
}

private struct SleepStoryGenerationEnvelope: Codable {
    let story: MeditationScript
    let nextHeaders: [SleepStoryHeader]
}

private struct PracticeJourneyGenerationRequest: Codable {
    let goalSummary: String
    let preferredDurationMinutes: Int
    let personalityName: String
    let personalityPrompt: String
    let stillnessRatio: Double
    let locale: String
    let memoryContext: String?
    let historyContext: String?
    let cycleNumber: Int
}

private struct PracticeJourneyPlanResponse: Codable {
    let title: String
    let summary: String
    let cycleNumber: Int
    let steps: [PracticeJourneyPlanStepResponse]
}

private struct PracticeJourneyPlanStepResponse: Codable {
    let dayNumber: Int
    let title: String
    let focus: String
    let purpose: String
    let meditationPrompt: String
    let adaptationTip: String
    let suggestedDurationMinutes: Int
}

private extension KaiBrainService {
    static let defaultSleepStoryHeaders: [SleepStoryHeader] = [
        SleepStoryHeader(
            id: "astronomers-attic",
            title: localizedSleepStoryHeader("astronomers-attic", component: "title", fallback: "The Astronomer's Attic"),
            subtitle: localizedSleepStoryHeader("astronomers-attic", component: "subtitle", fallback: "Dusty maps, brass lenses, and starlight on wood")
        ),
        SleepStoryHeader(
            id: "midnight-tram",
            title: localizedSleepStoryHeader("midnight-tram", component: "title", fallback: "Last Tram Through the Rain"),
            subtitle: localizedSleepStoryHeader("midnight-tram", component: "subtitle", fallback: "Window fog, dim stations, and quiet city hum")
        ),
        SleepStoryHeader(
            id: "orchard-watchtower",
            title: localizedSleepStoryHeader("orchard-watchtower", component: "title", fallback: "The Orchard Watchtower"),
            subtitle: localizedSleepStoryHeader("orchard-watchtower", component: "subtitle", fallback: "Apple leaves, lantern glow, and slow night wind")
        ),
        SleepStoryHeader(
            id: "paper-lantern-river",
            title: localizedSleepStoryHeader("paper-lantern-river", component: "title", fallback: "Paper Lantern River"),
            subtitle: localizedSleepStoryHeader("paper-lantern-river", component: "subtitle", fallback: "Boats drifting under bridges in warm silence")
        ),
        SleepStoryHeader(
            id: "salt-glasshouse",
            title: localizedSleepStoryHeader("salt-glasshouse", component: "title", fallback: "The Salt Glasshouse"),
            subtitle: localizedSleepStoryHeader("salt-glasshouse", component: "subtitle", fallback: "Sea mist on panes and soft echoing steps")
        ),
        SleepStoryHeader(
            id: "winter-post-office",
            title: localizedSleepStoryHeader("winter-post-office", component: "title", fallback: "Winter Post Office"),
            subtitle: localizedSleepStoryHeader("winter-post-office", component: "subtitle", fallback: "Unsent letters, ticking clock, and stove heat")
        ),
        SleepStoryHeader(
            id: "cedar-bathhouse",
            title: localizedSleepStoryHeader("cedar-bathhouse", component: "title", fallback: "The Cedar Bathhouse"),
            subtitle: localizedSleepStoryHeader("cedar-bathhouse", component: "subtitle", fallback: "Steam, cedar walls, and still midnight water")
        ),
        SleepStoryHeader(
            id: "lighthouse-kitchen",
            title: localizedSleepStoryHeader("lighthouse-kitchen", component: "title", fallback: "Kitchen in the Lighthouse"),
            subtitle: localizedSleepStoryHeader("lighthouse-kitchen", component: "subtitle", fallback: "Kettle warmth and waves turning below")
        ),
        SleepStoryHeader(
            id: "snowfield-observatory",
            title: localizedSleepStoryHeader("snowfield-observatory", component: "title", fallback: "Snowfield Observatory"),
            subtitle: localizedSleepStoryHeader("snowfield-observatory", component: "subtitle", fallback: "Red lamps, wool blankets, and distant sky")
        ),
        SleepStoryHeader(
            id: "night-greenmarket",
            title: localizedSleepStoryHeader("night-greenmarket", component: "title", fallback: "Greenmarket After Closing"),
            subtitle: localizedSleepStoryHeader("night-greenmarket", component: "subtitle", fallback: "Crates, canvas awnings, and soft street rain")
        ),
        SleepStoryHeader(
            id: "quarry-garden",
            title: localizedSleepStoryHeader("quarry-garden", component: "title", fallback: "The Quarry Garden"),
            subtitle: localizedSleepStoryHeader("quarry-garden", component: "subtitle", fallback: "Stone paths, moss walls, and moonlit water")
        ),
        SleepStoryHeader(
            id: "river-mill-loft",
            title: localizedSleepStoryHeader("river-mill-loft", component: "title", fallback: "Loft Above the River Mill"),
            subtitle: localizedSleepStoryHeader("river-mill-loft", component: "subtitle", fallback: "Timber beams and a wheel turning slowly")
        )
    ]

    static func localizedSleepStoryHeader(_ id: String, component: String, fallback: String) -> String {
        let key = "sleep.header.\(id).\(component)"
        return Bundle.main.localizedString(forKey: key, value: fallback, table: nil)
    }

    static func normalizedHeaderTitle(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
