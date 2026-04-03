import Foundation
import ActivityKit

public struct LiveTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentPhrase: String
        public var estimatedEndTime: Date
        public var personaImageName: String?
        public var personaName: String?
        
        public init(
            currentPhrase: String,
            estimatedEndTime: Date,
            personaImageName: String? = nil,
            personaName: String? = nil
        ) {
            self.currentPhrase = currentPhrase
            self.estimatedEndTime = estimatedEndTime
            self.personaImageName = personaImageName
            self.personaName = personaName
        }
    }

    public var title: String
    public var personaImageName: String?
    public var personaName: String?
    
    public init(title: String, personaImageName: String? = nil, personaName: String? = nil) {
        self.title = title
        self.personaImageName = personaImageName
        self.personaName = personaName
    }
}
