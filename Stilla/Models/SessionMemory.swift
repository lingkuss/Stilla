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
}
