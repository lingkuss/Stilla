import Foundation
import ActivityKit

public struct LiveTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentPhrase: String
        public var estimatedEndTime: Date
        
        public init(currentPhrase: String, estimatedEndTime: Date) {
            self.currentPhrase = currentPhrase
            self.estimatedEndTime = estimatedEndTime
        }
    }

    public var title: String
    
    public init(title: String) {
        self.title = title
    }
}
