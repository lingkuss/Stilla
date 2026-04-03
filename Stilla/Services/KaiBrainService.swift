import Foundation

@MainActor
class KaiBrainService {
    static let shared = KaiBrainService()
    
    enum BrainError: Error {
        case generationFailed
        case invalidResponse
        case trialExpired
        case serviceUnavailable
    }

    private let maxFreeCredits = 3
    private let freeGenMonthKey = "kai.free_gen_month"
    private let freeGenCountKey = "kai.free_gen_count"

    private var iCloudStore: NSUbiquitousKeyValueStore { .default }

    /// Remaining free credits this month (0…3).
    var freeCreditsRemaining: Int {
        let currentMonth = currentMonthTag
        let storedMonth = iCloudStore.string(forKey: freeGenMonthKey) ?? ""
        if storedMonth != currentMonth {
            return maxFreeCredits          // new month → full credits
        }
        let used = Int(iCloudStore.longLong(forKey: freeGenCountKey))
        return max(0, maxFreeCredits - used)
    }

    var isFreeGenerationAvailable: Bool {
        freeCreditsRemaining > 0
    }

    func recordFreeGeneration() {
        let currentMonth = currentMonthTag
        let storedMonth = iCloudStore.string(forKey: freeGenMonthKey) ?? ""

        if storedMonth != currentMonth {
            // First use this month — reset counter
            iCloudStore.set(currentMonth, forKey: freeGenMonthKey)
            iCloudStore.set(Int64(1), forKey: freeGenCountKey)
        } else {
            let used = iCloudStore.longLong(forKey: freeGenCountKey)
            iCloudStore.set(used + 1, forKey: freeGenCountKey)
        }
        iCloudStore.synchronize()
    }

    /// "2026-04" style tag so we never confuse January across years.
    private var currentMonthTag: String {
        let now = Date()
        let cal = Calendar.current
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        return "\(y)-\(m)"
    }
    
    /// Generates a personalized meditation script based on mood and duration.
    func generateScript(mood: String, durationMinutes: Int, personality: KaiPersonality) async throws -> MeditationScript {
        guard let url = Secrets.kaiBackendURL else {
            throw BrainError.serviceUnavailable
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = Secrets.kaiBackendToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body = KaiGenerationRequest(
            mood: mood,
            durationMinutes: durationMinutes,
            personalityName: personality.name,
            personalityPrompt: personality.promptInjection
        )
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ KAI ERROR: No HTTP Response")
            throw BrainError.generationFailed
        }
        
        print("🌐 KAI Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ KAI backend error: \(errorString)")
            }
            throw BrainError.generationFailed
        }
        
        do {
            let rawScript = try JSONDecoder().decode(MeditationScript.self, from: data)
            return stretchScriptToFit(rawScript)
        } catch let decodingError as DecodingError {
            print("❌ KAI Decoding Error: \(decodingError)")
            throw BrainError.invalidResponse
        } catch {
            print("❌ KAI Unknown Error: \(error)")
            throw BrainError.generationFailed
        }
    }
    }
    
    /// Guarantees that the generated script actually covers the requested duration.
    /// LLMs are notoriously bad at summing pauses. This function detects any shortfall in
    /// total elapsed time and pads the `pauseDuration` of every step evenly.
    private func stretchScriptToFit(_ script: MeditationScript) -> MeditationScript {
        let targetSeconds = Double(script.durationMinutes * 60)
        
        // Count words to estimate reading time
        var totalWords = 0
        var totalPauses: Double = 0
        for step in script.steps {
            totalWords += step.text.split(separator: " ").count
            totalPauses += step.pauseDuration
        }
        
        // Assume roughly 150 words per minute -> 2.5 words per sec limit -> 0.4s per word
        let estimatedReadingSeconds = Double(totalWords) * 0.4
        let currentTotalSeconds = estimatedReadingSeconds + totalPauses
        
        let shortfall = targetSeconds - currentTotalSeconds
        if shortfall > 0, !script.steps.isEmpty {
            let extraPausePerStep = shortfall / Double(script.steps.count)
            let stretchedSteps = script.steps.map { step -> ScriptStep in
                ScriptStep(
                    text: step.text,
                    pauseDuration: step.pauseDuration + extraPausePerStep
                )
            }
            return MeditationScript(
                id: script.id,
                title: script.title,
                durationMinutes: script.durationMinutes,
                steps: stretchedSteps,
                isFavorite: script.isFavorite,
                tags: script.tags,
                kaiPersonalityID: script.kaiPersonalityID,
                kaiPersonalityName: script.kaiPersonalityName,
                guidanceHeader: script.guidanceHeader,
                guidanceBody: script.guidanceBody,
                suggestionOptions: script.suggestionOptions,
                createdAt: script.createdAt
            )
        }
        
        return script
}

private struct KaiGenerationRequest: Codable {
    let mood: String
    let durationMinutes: Int
    let personalityName: String
    let personalityPrompt: String
}
