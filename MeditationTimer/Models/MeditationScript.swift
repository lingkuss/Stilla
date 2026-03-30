import Foundation

struct ScriptStep: Identifiable, Codable {
    let id = UUID()
    let text: String
    let pauseDuration: TimeInterval
}

struct MeditationScript: Identifiable, Codable {
    let id = UUID()
    let title: String
    let focus: MeditationFocus
    let durationMinutes: Int
    let steps: [ScriptStep]
    
    enum MeditationFocus: String, Codable, CaseIterable {
        case calm = "Calm"
        case sleep = "Sleep"
        case focus = "Focus"
        
        var icon: String {
            switch self {
            case .calm: return "wind"
            case .sleep: return "moon.stars"
            case .focus: return "bolt.shield"
            }
        }
    }
}

extension MeditationScript {
    static func sample(for minutes: Int, focus: MeditationFocus) -> MeditationScript {
        switch minutes {
        case 1:
            return quickReset(focus: focus)
        case 3...5:
            return deepCalm(focus: focus)
        default:
            return stillnessJourney(focus: focus)
        }
    }
    
    private static func quickReset(focus: MeditationFocus) -> MeditationScript {
        MeditationScript(
            title: "Quick Reset",
            focus: focus,
            durationMinutes: 1,
            steps: [
                ScriptStep(text: "Welcome to your quick reset. Close your eyes and settle in.", pauseDuration: 3),
                ScriptStep(text: "Inhale deeply through your nose, filling your lungs completely.", pauseDuration: 4),
                ScriptStep(text: "Hold the breath for a moment of stillness.", pauseDuration: 2),
                ScriptStep(text: "Exhale slowly through your mouth, letting go of any tension.", pauseDuration: 5),
                ScriptStep(text: "Notice the weight of your body supported by the earth.", pauseDuration: 10),
                ScriptStep(text: "Observe the natural rhythm of your breath as it returns to normal.", pauseDuration: 15),
                ScriptStep(text: "When you are ready, gently open your eyes.", pauseDuration: 2)
            ]
        )
    }
    
    private static func deepCalm(focus: MeditationFocus) -> MeditationScript {
        MeditationScript(
            title: "Deep Calm",
            focus: focus,
            durationMinutes: 5,
            steps: [
                ScriptStep(text: "Let's begin by finding a comfortable position. Allow your shoulders to drop.", pauseDuration: 5),
                ScriptStep(text: "Tuning into the breath. Notice the cool air entering your nostrils.", pauseDuration: 10),
                ScriptStep(text: "And the warm air as it leaves. There is nowhere else to be.", pauseDuration: 15),
                ScriptStep(text: "If your mind wanders, gently bring it back to the rise and fall of your chest.", pauseDuration: 20),
                ScriptStep(text: "Feel the calm spreading from your head, down through your spine.", pauseDuration: 30),
                ScriptStep(text: "Everything you need is already within you. Just breathe.", pauseDuration: 40),
                ScriptStep(text: "As we conclude, keep this sense of stillness with you throughout your day.", pauseDuration: 5)
            ]
        )
    }
    
    private static func stillnessJourney(focus: MeditationFocus) -> MeditationScript {
        MeditationScript(
            title: "Stillness Journey",
            focus: focus,
            durationMinutes: 10,
            steps: [
                ScriptStep(text: "Welcome to this longer journey into stillness. Settle your mind.", pauseDuration: 8),
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
