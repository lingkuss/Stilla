import SwiftUI

struct KaiScriptView: View {
    @Environment(MeditationManager.self) private var manager
    private let guru = GuruManager.shared
    
    @State private var showSyncButton = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 40) {
                            // Top Spacer to allow first step to center
                            Color.clear.frame(height: geometry.size.height / 2 - 20)
                            
                            if let script = manager.currentScript {
                                ForEach(Array(script.steps.enumerated()), id: \.element.id) { index, step in
                                    StepRow(
                                        step: step,
                                        isActive: index == guru.currentStepIndex,
                                        isPast: index < guru.currentStepIndex,
                                        currentWordRange: index == guru.currentStepIndex ? guru.currentWordRange : nil
                                    )
                                    .id(index)
                                }
                            }
                            
                            // Bottom Spacer to allow last step to center
                            Color.clear.frame(height: geometry.size.height / 2)
                        }
                        .padding(.horizontal, 32)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .simultaneousGesture(
                        DragGesture().onChanged { _ in
                            withAnimation(.spring(response: 0.3)) {
                                showSyncButton = true
                            }
                        }
                    )
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black, location: 0.1),
                                .init(color: .black, location: 0.9),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .onChange(of: guru.currentStepIndex) { _, newIndex in
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                            showSyncButton = false
                        }
                    }
                    .onAppear {
                        if let script = manager.currentScript, guru.currentStepIndex < script.steps.count {
                            // Instant scroll on appear to ensure we are centered
                            proxy.scrollTo(guru.currentStepIndex, anchor: .center)
                        }
                    }
                    
                    if manager.state == .meditating, showSyncButton {
                        Button {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                                proxy.scrollTo(guru.currentStepIndex, anchor: .center)
                                showSyncButton = false
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.to.line.compact")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Center on Kai")
                            }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.black.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(.white.opacity(0.9)))
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }
}

struct StepRow: View {
    let step: ScriptStep
    let isActive: Bool
    let isPast: Bool
    let currentWordRange: NSRange?
    
    var body: some View {
        VStack(spacing: 0) {
            if isActive, let range = currentWordRange {
                highlightedText(fullText: step.text, range: range)
            } else {
                Text(step.text)
                    .font(.system(size: 13, weight: .light, design: .serif))
                    .italic()
                    .foregroundStyle(isPast ? .white.opacity(0.20) : .white.opacity(0.40))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
        }
        .scaleEffect(isActive ? 1.05 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isActive)
    }
    
    @ViewBuilder
    private func highlightedText(fullText: String, range: NSRange) -> some View {
        let nsString = fullText as NSString
        
        // Safety check for range
        let safeLocation = min(range.location, nsString.length)
        let safeLength = min(range.length, nsString.length - safeLocation)
        let safeRange = NSRange(location: safeLocation, length: safeLength)
        
        let before = nsString.substring(to: safeRange.location)
        let highlight = nsString.substring(with: safeRange)
        let after = nsString.substring(from: safeRange.location + safeRange.length)
        
        (
            Text(before).foregroundStyle(.white.opacity(0.40)) +
            Text(highlight).foregroundStyle(.white).fontWeight(.medium) +
            Text(after).foregroundStyle(.white.opacity(0.40))
        )
        .font(.system(size: 14, weight: .light, design: .serif))
        .italic()
        .multilineTextAlignment(.center)
        .lineSpacing(6)
    }
}
