import Foundation

@MainActor
class KaiBrainService {
    static let shared = KaiBrainService()
    
    enum BrainError: Error {
        case generationFailed
        case invalidResponse
    }
    
    /// Generates a personalized meditation script based on mood and duration.
    func generateScript(mood: String, durationMinutes: Int) async throws -> MeditationScript {
        let apiKey = Secrets.openAIKey
        
        // If no API key is provided in Secrets.swift, fallback to the template system.
        if apiKey == "YOUR_KEY_HERE" || apiKey.isEmpty {
            return generateTemplateScript(mood: mood, durationMinutes: durationMinutes)
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
    
    private func generateTemplateScript(mood: String, durationMinutes: Int) -> MeditationScript {
        let introMood = mood.lowercased()
        let steps: [ScriptStep]
        
        switch durationMinutes {
        case 5:
            steps = [
                ScriptStep(text: "Hello, I am Kai. I hear that you are feeling \(introMood). Let's take these five minutes to find some space.", pauseDuration: 5),
                ScriptStep(text: "Close your eyes. Notice where that \(introMood) lives in your body right now.", pauseDuration: 15),
                ScriptStep(text: "Imagine a soft light washing over you, dissolving any tension.", pauseDuration: 30),
                ScriptStep(text: "Your breath is a steady wave. Let it carry you away from the noise.", pauseDuration: 60),
                ScriptStep(text: "You are safe here. You are present. You are still.", pauseDuration: 60),
                ScriptStep(text: "Gently returning. Carrying this calm with you.", pauseDuration: 5)
            ]
        case 30:
            steps = [
                ScriptStep(text: "Welcome to this deep immersion. I am Kai. We will sit with your \(introMood) today, and let it pass through us like clouds.", pauseDuration: 10),
                ScriptStep(text: "Finding your anchor. The breath at the tip of the nose.", pauseDuration: 60),
                ScriptStep(text: "Expand your awareness to the whole body. Every cell at rest.", pauseDuration: 120),
                ScriptStep(text: "If thoughts of \(introMood) arise, acknowledge them, then watch them drift away.", pauseDuration: 300),
                ScriptStep(text: "Resting in the pure awareness of the present moment.", pauseDuration: 600),
                ScriptStep(text: "Softening the heart. Softening the mind.", pauseDuration: 300),
                ScriptStep(text: "Returning slowly. Grounded and clear.", pauseDuration: 10)
            ]
        default: // 10 minutes (Medium)
            steps = [
                ScriptStep(text: "I am Kai. Let's explore this feeling of being \(introMood) together for the next ten minutes.", pauseDuration: 8),
                ScriptStep(text: "Inhale the present. Exhale the past.", pauseDuration: 20),
                ScriptStep(text: "Letting the shoulders drop. Letting the jaw soften.", pauseDuration: 40),
                ScriptStep(text: "Visualizing a clear, still lake. Your mind is like that surface.", pauseDuration: 60),
                ScriptStep(text: "Resting in the silence between breaths.", pauseDuration: 120),
                ScriptStep(text: "You are much larger than any single emotion or mood.", pauseDuration: 60),
                ScriptStep(text: "When you are ready, carry this stillness into the world.", pauseDuration: 5)
            ]
        }
        
        return MeditationScript(
            title: "Kai's Session: \(mood.capitalized)",
            durationMinutes: durationMinutes,
            steps: steps
        )
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
