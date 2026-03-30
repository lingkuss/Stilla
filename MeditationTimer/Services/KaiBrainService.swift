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
        // Simulate "Thinking" time for the AI
        try await Task.sleep(for: .seconds(2))
        
        // This is a placeholder for a real LLM API call (OpenAI/Claude).
        // For now, we use a sophisticated template system to provide an "AI-like" experience.
        
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
            title: "Kai's Personalized Session",
            durationMinutes: durationMinutes,
            steps: steps
        )
    }
}
