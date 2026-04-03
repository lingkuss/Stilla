import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Widget UI

struct MeditationWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveTimerAttributes.self) { context in
            // Lock screen/banner UI
            HStack(alignment: .top, spacing: 12) {
                liveActivityLeadingVisual(attributes: context.attributes, state: context.state, size: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.title)
                        .font(.headline)
                        .foregroundColor(.white)

                    if !context.state.currentPhrase.isEmpty {
                        Text(context.state.currentPhrase)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                    }
                }

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
                    liveActivityLeadingVisual(attributes: context.attributes, state: context.state, size: 28)
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
                    VStack(spacing: 4) {
                        Text(context.attributes.title)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.7))

                        if !context.state.currentPhrase.isEmpty {
                            Text(context.state.currentPhrase)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                liveActivityLeadingVisual(attributes: context.attributes, state: context.state, size: 16)
            } compactTrailing: {
                Text(timerInterval: Date()...context.state.estimatedEndTime, countsDown: true)
                    .monospacedDigit()
                    .foregroundColor(.cyan)
            } minimal: {
                liveActivityLeadingVisual(attributes: context.attributes, state: context.state, size: 16)
            }
            .keylineTint(Color.cyan.opacity(0.5))
        }
    }
}

@ViewBuilder
private func liveActivityLeadingVisual(
    attributes: LiveTimerAttributes,
    state: LiveTimerAttributes.ContentState,
    size: CGFloat
) -> some View {
    if let imageName = state.personaImageName ?? attributes.personaImageName {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size, height: size)
            .clipShape(Circle())
    } else {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: size, height: size)
            Image(systemName: "quote.bubble.fill")
                .font(.system(size: size * 0.5))
                .foregroundColor(.cyan)
        }
    }
}
