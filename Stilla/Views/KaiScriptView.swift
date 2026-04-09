import SwiftUI
import UIKit

struct KaiScriptView: View {
    @Environment(MeditationManager.self) private var manager
    private let guru = GuruManager.shared

    @State private var showSyncButton = false
    @State private var centerNonce = UUID()

    var body: some View {
        ZStack(alignment: .bottom) {
            SingleScriptTextView(
                script: manager.currentScript,
                activeStepIndex: guru.currentStepIndex,
                activeWordRange: guru.currentWordRange,
                centerNonce: centerNonce,
                isAutoFollowEnabled: !showSyncButton
            )
            .padding(.horizontal, 16)
            .simultaneousGesture(
                DragGesture().onChanged { _ in
                    withAnimation(.spring(response: 0.3)) {
                        showSyncButton = true
                    }
                }
            )
            .onChange(of: guru.currentStepIndex) { _, _ in
                withAnimation(.spring(response: 0.3)) {
                    showSyncButton = false
                }
            }
            .onChange(of: manager.currentScript?.id) { _, _ in
                showSyncButton = false
                centerNonce = UUID()
            }

            if manager.state == .meditating, showSyncButton {
                Button {
                    centerNonce = UUID()
                    showSyncButton = false
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.to.line.compact")
                            .font(.system(size: 10, weight: .bold))
                        Text(String(localized: "script.center_on_mimir"))
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

private struct SingleScriptTextView: UIViewRepresentable {
    let script: MeditationScript?
    let activeStepIndex: Int
    let activeWordRange: NSRange?
    let centerNonce: UUID
    let isAutoFollowEnabled: Bool

    final class Coordinator {
        var lastScriptID: UUID?
        var lastCenterNonce: UUID?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.textContainerInset = UIEdgeInsets(top: 34, left: 24, bottom: 34, right: 24)
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textAlignment = .center
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        guard let script else {
            uiView.attributedText = nil
            return
        }

        let safeStep = min(max(0, activeStepIndex), max(script.steps.count - 1, 0))
        let composed = compose(script: script, activeStepIndex: safeStep, activeWordRange: activeWordRange)
        uiView.attributedText = composed.text

        let isNewScript = context.coordinator.lastScriptID != script.id
        if isNewScript {
            context.coordinator.lastScriptID = script.id
        }

        let isCenterRequest = context.coordinator.lastCenterNonce != centerNonce
        if isCenterRequest {
            context.coordinator.lastCenterNonce = centerNonce
        }

        DispatchQueue.main.async {
            if isNewScript {
                uiView.setContentOffset(.zero, animated: false)
                uiView.scrollRangeToVisible(composed.stepFocusRange)
                return
            }

            if isCenterRequest {
                uiView.scrollRangeToVisible(composed.stepFocusRange)
                return
            }

            guard isAutoFollowEnabled else { return }

            if composed.wordFocusRange.length > 0 {
                uiView.scrollRangeToVisible(composed.wordFocusRange)
            } else {
                uiView.scrollRangeToVisible(composed.stepFocusRange)
            }
        }
    }

    private func compose(
        script: MeditationScript,
        activeStepIndex: Int,
        activeWordRange: NSRange?
    ) -> (text: NSAttributedString, stepFocusRange: NSRange, wordFocusRange: NSRange) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 6

        let base: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .light),
            .foregroundColor: UIColor.white.withAlphaComponent(0.40),
            .paragraphStyle: paragraphStyle
        ]

        let past: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .light),
            .foregroundColor: UIColor.white.withAlphaComponent(0.20),
            .paragraphStyle: paragraphStyle
        ]

        let activeBase: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .light),
            .foregroundColor: UIColor.white.withAlphaComponent(0.40),
            .paragraphStyle: paragraphStyle
        ]

        let activeHighlight: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let output = NSMutableAttributedString()
        var stepFocusRange = NSRange(location: 0, length: 0)
        var wordFocusRange = NSRange(location: 0, length: 0)

        for (index, step) in script.steps.enumerated() {
            if index > 0 {
                output.append(NSAttributedString(string: "\n\n", attributes: base))
            }

            let stepStart = output.length
            let textNSString = step.text as NSString
            let stepLength = textNSString.length

            if index < activeStepIndex {
                output.append(NSAttributedString(string: step.text, attributes: past))
            } else if index > activeStepIndex {
                output.append(NSAttributedString(string: step.text, attributes: base))
            } else {
                output.append(NSAttributedString(string: step.text, attributes: activeBase))

                let safeLocation = min(max(0, activeWordRange?.location ?? 0), stepLength)
                let safeLength = min(max(0, activeWordRange?.length ?? 0), stepLength - safeLocation)
                let safeWord = NSRange(location: safeLocation, length: safeLength)

                if safeWord.length > 0 {
                    let globalWord = NSRange(location: stepStart + safeWord.location, length: safeWord.length)
                    output.addAttributes(activeHighlight, range: globalWord)
                    wordFocusRange = globalWord
                }

                stepFocusRange = NSRange(location: stepStart, length: max(stepLength, 1))
            }
        }

        return (output, stepFocusRange, wordFocusRange)
    }
}
