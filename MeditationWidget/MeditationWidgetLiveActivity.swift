import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget UI

struct MeditationWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveTimerAttributes.self) { context in
            // Lock screen/banner UI
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 24, height: 24)
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.cyan)
                }
                Text(context.attributes.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(timerInterval: Date()...context.state.estimatedEndTime, countsDown: true)
                    .monospacedDigit()
                    .foregroundColor(.cyan)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "quote.bubble.fill")
                        .foregroundColor(.cyan)
                        .font(.title2)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: Date()...context.state.estimatedEndTime, countsDown: true)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                        .foregroundColor(.cyan)
                        .font(.title2)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // Title only, phrase removed
                    Text(context.attributes.title)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(.cyan)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.estimatedEndTime, countsDown: true)
                    .monospacedDigit()
                    .foregroundColor(.cyan)
            } minimal: {
                Image(systemName: "quote.bubble.fill")
                    .foregroundColor(.cyan)
            }
            .keylineTint(Color.cyan.opacity(0.5))
        }
    }
}
