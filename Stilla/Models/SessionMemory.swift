import Foundation

struct SessionMemory: Identifiable, Codable, Hashable {
    let id: UUID
    let startedAt: Date
    let durationSeconds: Int
    let moodSummary: String?
    let intention: String?
    let proactiveHeader: String?
    let proactiveBody: String?
    let suggestionOptions: [String]
    var reflection: String?
    var reflectionDate: Date?

    init(
        id: UUID = UUID(),
        startedAt: Date,
        durationSeconds: Int,
        moodSummary: String? = nil,
        intention: String? = nil,
        proactiveHeader: String? = nil,
        proactiveBody: String? = nil,
        suggestionOptions: [String] = [],
        reflection: String? = nil,
        reflectionDate: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.moodSummary = moodSummary
        self.intention = intention
        self.proactiveHeader = proactiveHeader
        self.proactiveBody = proactiveBody
        self.suggestionOptions = suggestionOptions
        self.reflection = reflection
        self.reflectionDate = reflectionDate
    }

    var durationMinutesRounded: Int {
        Int((Double(durationSeconds) / 60.0).rounded())
    }
    
    // MARK: - Safe Decoding for Legacy Records
    
    enum CodingKeys: String, CodingKey {
        case id, startedAt, durationSeconds, moodSummary, intention
        case proactiveHeader, proactiveBody, suggestionOptions, reflection, reflectionDate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        moodSummary = try container.decodeIfPresent(String.self, forKey: .moodSummary)
        intention = try container.decodeIfPresent(String.self, forKey: .intention)
        proactiveHeader = try container.decodeIfPresent(String.self, forKey: .proactiveHeader)
        proactiveBody = try container.decodeIfPresent(String.self, forKey: .proactiveBody)
        suggestionOptions = (try? container.decode([String].self, forKey: .suggestionOptions)) ?? []
        reflection = try container.decodeIfPresent(String.self, forKey: .reflection)
        reflectionDate = try container.decodeIfPresent(Date.self, forKey: .reflectionDate)
    }
}

struct PracticeJourneyStepCompletion: Codable, Hashable {
    let completedAt: Date
    let sessionMemoryID: UUID?
    var reflection: String?

    init(
        completedAt: Date = Date(),
        sessionMemoryID: UUID? = nil,
        reflection: String? = nil
    ) {
        self.completedAt = completedAt
        self.sessionMemoryID = sessionMemoryID
        self.reflection = reflection
    }
}

struct PracticeJourneyStep: Identifiable, Codable, Hashable {
    var id: UUID
    var dayNumber: Int
    var title: String
    var focus: String
    var purpose: String
    var meditationPrompt: String
    var adaptationTip: String
    var suggestedDurationMinutes: Int
    var completion: PracticeJourneyStepCompletion?

    init(
        id: UUID = UUID(),
        dayNumber: Int,
        title: String,
        focus: String,
        purpose: String,
        meditationPrompt: String,
        adaptationTip: String,
        suggestedDurationMinutes: Int,
        completion: PracticeJourneyStepCompletion? = nil
    ) {
        self.id = id
        self.dayNumber = dayNumber
        self.title = title
        self.focus = focus
        self.purpose = purpose
        self.meditationPrompt = meditationPrompt
        self.adaptationTip = adaptationTip
        self.suggestedDurationMinutes = suggestedDurationMinutes
        self.completion = completion
    }

    var isCompleted: Bool {
        completion != nil
    }
}

struct PracticeJourneyPlan: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var summary: String
    var goalSummary: String
    var cycleNumber: Int
    var personaID: String?
    var personaName: String?
    var stillnessRatio: Double
    var createdAt: Date
    var completedAt: Date?
    var steps: [PracticeJourneyStep]

    init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        goalSummary: String,
        cycleNumber: Int = 1,
        personaID: String? = nil,
        personaName: String? = nil,
        stillnessRatio: Double = 0.5,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        steps: [PracticeJourneyStep]
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.goalSummary = goalSummary
        self.cycleNumber = cycleNumber
        self.personaID = personaID
        self.personaName = personaName
        self.stillnessRatio = stillnessRatio
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.steps = steps.sorted { $0.dayNumber < $1.dayNumber }
    }

    var nextStep: PracticeJourneyStep? {
        steps.sorted { $0.dayNumber < $1.dayNumber }.first(where: { !$0.isCompleted })
    }

    var completedStepCount: Int {
        steps.filter { $0.isCompleted }.count
    }

    var isCompleted: Bool {
        completedStepCount >= steps.count && !steps.isEmpty
    }
}
