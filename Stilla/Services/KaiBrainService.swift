import Foundation

@MainActor
class KaiBrainService {
    static let shared = KaiBrainService()
    
    enum BrainError: Error {
        case generationFailed
        case invalidResponse
        case trialExpired
    }

    private let freeGenMonthKey = "kai.last_free_gen_month"

    var isFreeGenerationAvailable: Bool {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let lastMonth = UserDefaults.standard.integer(forKey: freeGenMonthKey)
        return lastMonth != currentMonth
    }

    func recordFreeGeneration() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        UserDefaults.standard.set(currentMonth, forKey: freeGenMonthKey)
    }
    
    /// Generates a personalized meditation script based on mood and duration.
    func generateScript(mood: String, durationMinutes: Int) async throws -> MeditationScript {
        let apiKey = Secrets.openAIKey
        
        // If no API key is provided, indicating that Kai is resting.
        if apiKey == "YOUR_KEY_HERE" || apiKey.isEmpty {
            throw BrainError.generationFailed
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let systemPrompt = """
        You are Kai, a Zen meditation guide. Create a personalized meditation script in JSON format.
        The JSON must follow this structure exactly:
        {
          "title": "A short, poetic title",
          "durationMinutes": \(durationMinutes),
          "steps": [
            { "text": "The words to speak", "pauseDuration": 5.0 }
          ]
        }
        Guidelines:
        - The user is feeling: \(mood).
        - Total duration: \(durationMinutes) minutes (\(durationMinutes * 60) seconds).
        - The "pauseDuration" field is in SECONDS. You must provide generous pauses between steps.
        - Ensure the sum of pauseDurations plus reading time (~150 words per minute) roughly equals the total duration of \(durationMinutes * 60) seconds.
        - Be poetic, compassionate, and grounded.
        - Respond ONLY with the raw JSON. No markdown, no filler.
        """
        
        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Generate a \(durationMinutes) minute meditation for someone feeling \(mood)."]
            ],
            "response_format": ["type": "json_object"],
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ KAI ERROR: No HTTP Response")
            throw BrainError.generationFailed
        }
        
        print("🌐 KAI Status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ KAI API Error: \(errorString)")
            }
            throw BrainError.generationFailed
        }
        
        do {
            let json = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let content = json.choices.first?.message.content else {
                print("❌ KAI ERROR: No content in OpenAI response")
                throw BrainError.invalidResponse
            }
            
            print("📝 KAI Raw Script: \(content)")
            
            guard let contentData = content.data(using: .utf8) else {
                throw BrainError.invalidResponse
            }
            
            let rawScript = try JSONDecoder().decode(MeditationScript.self, from: contentData)
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
                title: script.title,
                durationMinutes: script.durationMinutes,
                steps: stretchedSteps
            )
        }
        
        return script
    }

// MARK: - OpenAI Internal Models

struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}
