import AppIntents
import Foundation

/// Siri intent: Start a meditation session.
struct StartMeditationIntent: AppIntent {
    static var title: LocalizedStringResource = "Begin Meditation"
    static var description: IntentDescription = "Begin a meditation session with Vindla"

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Duration")
    var duration: DurationOption?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = MeditationManager.shared

        if let duration = duration {
            manager.start(durationMinutes: duration.minutes)
            return .result(dialog: "Beginning \(duration.minutes) minute meditation. Find your calm.")
        } else {
            manager.start()
            return .result(dialog: "Beginning \(manager.durationMinutes) minute meditation. Find your calm.")
        }
    }
}

/// Duration options for Siri parameter
enum DurationOption: String, AppEnum {
    case one = "1 minute"
    case three = "3 minutes"
    case five = "5 minutes"
    case ten = "10 minutes"
    case fifteen = "15 minutes"
    case twenty = "20 minutes"
    case thirty = "30 minutes"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Duration")

    static var caseDisplayRepresentations: [DurationOption: DisplayRepresentation] = [
        .one: "1 minute",
        .three: "3 minutes",
        .five: "5 minutes",
        .ten: "10 minutes",
        .fifteen: "15 minutes",
        .twenty: "20 minutes",
        .thirty: "30 minutes",
    ]

    var minutes: Int {
        switch self {
        case .one: return 1
        case .three: return 3
        case .five: return 5
        case .ten: return 10
        case .fifteen: return 15
        case .twenty: return 20
        case .thirty: return 30
        }
    }
}

/// Siri intent: Start a limitless stopwatch meditation session.
struct StartOpenEndedMeditationIntent: AppIntent {
    static var title: LocalizedStringResource = "Begin Limitless Meditation"
    static var description: IntentDescription = "Begin a limitless stopwatch meditation session with Vindla"

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = MeditationManager.shared
        manager.start(durationMinutes: 0)
        return .result(dialog: "Beginning limitless meditation. End whenever you're ready.")
    }
}
