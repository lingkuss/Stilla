import Foundation

struct ScriptStep: Identifiable, Codable {
    let id = UUID()
    let text: String
    let pauseDuration: TimeInterval
}

struct MeditationScript: Identifiable, Codable {
    let id = UUID()
    let title: String
    let durationMinutes: Int
    let steps: [ScriptStep]
}

extension MeditationScript {
    static func sample(for minutes: Int) -> MeditationScript {
        switch minutes {
        case 1:
            return quickReset()
        case 3...5:
            return deepCalm()
        default:
            return stillnessJourney()
        }
    }
    
    private static func quickReset() -> MeditationScript {
        MeditationScript(
            title: "Quick Reset",
            durationMinutes: 1,
            steps: [
                ScriptStep(text: "Welcome, I am Kai. Close your eyes and settle in for this quick reset.", pauseDuration: 3),
                ScriptStep(text: "Inhale deeply through your nose, filling your lungs completely.", pauseDuration: 4),
                ScriptStep(text: "Hold the breath for a moment of stillness.", pauseDuration: 2),
                ScriptStep(text: "Exhale slowly through your mouth, letting go of any tension.", pauseDuration: 5),
                ScriptStep(text: "Notice the weight of your body supported by the earth.", pauseDuration: 10),
                ScriptStep(text: "Observe the natural rhythm of your breath as it returns to normal.", pauseDuration: 15),
                ScriptStep(text: "When you are ready, gently open your eyes.", pauseDuration: 2)
            ]
        )
    }
    
    private static func deepCalm() -> MeditationScript {
        MeditationScript(
            title: "Deep Calm",
            durationMinutes: 5,
            steps: [
                ScriptStep(text: "Hello, I am Kai. Let's begin by finding a comfortable position. Allow your shoulders to drop.", pauseDuration: 5),
                ScriptStep(text: "Tuning into the breath. Notice the cool air entering your nostrils.", pauseDuration: 10),
                ScriptStep(text: "And the warm air as it leaves. There is nowhere else to be.", pauseDuration: 15),
                ScriptStep(text: "If your mind wanders, gently bring it back to the rise and fall of your chest.", pauseDuration: 20),
                ScriptStep(text: "Feel the calm spreading from your head, down through your spine.", pauseDuration: 30),
                ScriptStep(text: "Everything you need is already within you. Just breathe.", pauseDuration: 40),
                ScriptStep(text: "As we conclude, keep this sense of stillness with you throughout your day.", pauseDuration: 5)
            ]
        )
    }
    
    private static func stillnessJourney() -> MeditationScript {
        MeditationScript(
            title: "Stillness Journey",
            durationMinutes: 10,
            steps: [
                ScriptStep(text: "Welcome to this longer journey into stillness. I am Kai, and I will be your guide.", pauseDuration: 8),
                ScriptStep(text: "Starting at your feet, notice any sensations. Relax them completely.", pauseDuration: 15),
                ScriptStep(text: "Moving up your legs, hips, and into your belly. Let go.", pauseDuration: 20),
                ScriptStep(text: "Your breath is an anchor. Always here, always steady.", pauseDuration: 30),
                ScriptStep(text: "Rest in the wide open space of your awareness.", pauseDuration: 60),
                ScriptStep(text: "You are the observer of your thoughts, not the thinker.", pauseDuration: 60),
                ScriptStep(text: "Gently return to the room. Feeling refreshed and clear.", pauseDuration: 10)
            ]
        )
    }
}
