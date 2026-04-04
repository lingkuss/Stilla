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
