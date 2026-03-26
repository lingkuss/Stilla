import SwiftUI

/// The breathing circle animation — expands and contracts to guide breathing.
struct BreathingCircleView: View {
    let isActive: Bool
    let progress: Double

    @State private var breatheIn = false

    private let breatheDuration: Double = 4.0

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
                        startRadius: 60,
                        endRadius: 160
                    )
                )
                .frame(width: 300, height: 300)
                .scaleEffect(breatheIn ? 1.1 : 0.85)
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
                .frame(width: 200, height: 200)
                .scaleEffect(breatheIn ? 1.15 : 0.9)
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
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(-90))
                .opacity(isActive ? 1 : 0)

            // Inner circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hue: 0.72, saturation: 0.3, brightness: 0.95).opacity(0.15),
                            Color(hue: 0.72, saturation: 0.6, brightness: 0.7).opacity(0.05),
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 90
                    )
                )
                .frame(width: 180, height: 180)
                .scaleEffect(breatheIn ? 1.12 : 0.92)

            // Center dot
            Circle()
                .fill(Color(hue: 0.55, saturation: 0.5, brightness: 0.95))
                .frame(width: 8, height: 8)
                .shadow(color: Color(hue: 0.55, saturation: 0.6, brightness: 1.0).opacity(0.7), radius: 10)
                .opacity(isActive ? 1.0 : 0.4)
        }
        .animation(
            isActive
                ? .easeInOut(duration: breatheDuration).repeatForever(autoreverses: true)
                : .easeInOut(duration: 1.0),
            value: breatheIn
        )
        .onAppear {
            if isActive {
                breatheIn = true
            }
        }
        .onChange(of: isActive) { _, active in
            breatheIn = active
        }
    }
}
