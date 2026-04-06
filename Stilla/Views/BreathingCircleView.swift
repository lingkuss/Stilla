import SwiftUI

/// The breathing circle animation — expands and contracts based on the selected technique.
struct BreathingCircleView: View {
    let isActive: Bool
    let progress: Double
    let technique: BreathingTechnique
    var imageName: String? = nil
    var onPhaseChange: ((_ phase: String, _ duration: Double) -> Void)? = nil

    @State private var scale: CGFloat = 0.85
    @State private var status: String = ""
    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hue: 0.72, saturation: 0.6, brightness: 0.8).opacity(0.3),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 50,
                        endRadius: 140
                    )
                )
                .frame(maxWidth: 260, maxHeight: 260)
                .scaleEffect(scale)
                .blur(radius: 30)

            // Middle ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color(hue: 0.72, saturation: 0.5, brightness: 0.9),
                            Color(hue: 0.80, saturation: 0.4, brightness: 0.8),
                            Color(hue: 0.72, saturation: 0.5, brightness: 0.9),
                        ],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(maxWidth: 180, maxHeight: 180)
                .scaleEffect(scale * 1.1)
                .opacity(isActive ? 0.8 : 0.3)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.55, saturation: 0.7, brightness: 0.9),
                            Color(hue: 0.72, saturation: 0.6, brightness: 0.95),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(maxWidth: 180, maxHeight: 180)
                .rotationEffect(.degrees(-90))
                .opacity(isActive ? 1 : 0)

            // Inner circle / Persona Image
            Group {
                if let imageName = imageName {
                    Image(imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                } else {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(hue: 0.72, saturation: 0.3, brightness: 0.95).opacity(0.15),
                                    Color(hue: 0.72, saturation: 0.6, brightness: 0.7).opacity(0.05),
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(maxWidth: 160, maxHeight: 160)
                }
            }
            .scaleEffect(scale * 1.05)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: imageName)

            // Center dot (only if not showing persona)
            if imageName == nil {
                Circle()
                    .fill(Color(hue: 0.55, saturation: 0.5, brightness: 0.95))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color(hue: 0.55, saturation: 0.6, brightness: 1.0).opacity(0.7), radius: 10)
                    .opacity(isActive ? 1.0 : 0.4)
            }
        }
        .onChange(of: isActive, initial: true) { _, active in
            if active {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }

    private func startAnimation() {
        stopAnimation()
        animationTask = Task {
            while !Task.isCancelled {
                // Inhale
                status = "Inhale"
                onPhaseChange?("Inhale", technique.inhale)
                withAnimation(.easeInOut(duration: technique.inhale)) {
                    scale = 1.15
                }
                try? await Task.sleep(for: .seconds(technique.inhale))
                if Task.isCancelled { return }

                // Hold
                if technique.holdIn > 0 {
                    status = "Hold"
                    onPhaseChange?("Hold", technique.holdIn)
                    try? await Task.sleep(for: .seconds(technique.holdIn))
                }
                if Task.isCancelled { return }

                // Exhale
                status = "Exhale"
                onPhaseChange?("Exhale", technique.exhale)
                withAnimation(.easeInOut(duration: technique.exhale)) {
                    scale = 0.85
                }
                try? await Task.sleep(for: .seconds(technique.exhale))
                if Task.isCancelled { return }

                // Hold
                if technique.holdOut > 0 {
                    status = "Hold"
                    onPhaseChange?("Hold", technique.holdOut)
                    try? await Task.sleep(for: .seconds(technique.holdOut))
                }
            }
        }
    }

    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
        withAnimation(.easeInOut(duration: 1.0)) {
            scale = 0.85
            status = ""
        }
    }
}

