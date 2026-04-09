import AppIntents
import Foundation

/// Siri intent: Start a meditation session.
struct StartMeditationIntent: AppIntent {
    static var title: LocalizedStringResource = "intent.start_meditation.title"
    static var description: IntentDescription = IntentDescription("intent.start_meditation.description")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "intent.common.duration")
    var duration: DurationOption?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = MeditationManager.shared

        if let duration {
            manager.start(durationMinutes: duration.minutes)
            return .result(dialog: IntentDialog("intent.start_meditation.dialog.started_with_duration"))
        }

        manager.start()
        return .result(dialog: IntentDialog("intent.start_meditation.dialog.started_default"))
    }
}

/// Duration options for Siri parameter
enum DurationOption: String, AppEnum {
    case one = "one"
    case three = "three"
    case five = "five"
    case ten = "ten"
    case fifteen = "fifteen"
    case twenty = "twenty"
    case thirty = "thirty"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "intent.common.duration")

    static var caseDisplayRepresentations: [DurationOption: DisplayRepresentation] = [
        .one: "intent.duration.one",
        .three: "intent.duration.three",
        .five: "intent.duration.five",
        .ten: "intent.duration.ten",
        .fifteen: "intent.duration.fifteen",
        .twenty: "intent.duration.twenty",
        .thirty: "intent.duration.thirty",
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
    static var title: LocalizedStringResource = "intent.start_open_ended.title"
    static var description: IntentDescription = IntentDescription("intent.start_open_ended.description")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = MeditationManager.shared
        manager.start(durationMinutes: 0)
        return .result(dialog: IntentDialog("intent.start_open_ended.dialog.started"))
    }
}
