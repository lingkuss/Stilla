import SwiftUI

/// Only the invitation observes this per-frame projection, not the whole world view.
@MainActor @Observable final class GuideCreationPlacement {
    var frame: CGRect = .zero
}

struct GuideCreationInvitation: View {
    let placement: GuideCreationPlacement
    let isSelected: Bool
    var create: () -> Void

    var body: some View {
        let frame = placement.frame
        ZStack {
            GuideCreationSilhouette()
                .frame(width: frame.width, height: frame.height)
                .allowsHitTesting(false)
            Color.clear
                .frame(width: max(44, frame.width * 0.22), height: max(44, frame.height * 0.22))
                .contentShape(Circle())
                .onTapGesture(perform: create)
                .offset(y: frame.height * 0.005)
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(GuideCreatorCopy.title)
                .accessibilityIdentifier("mountainJourney.createGuide")
                .accessibilityAction { create() }
        }
        .position(x: frame.midX, y: frame.midY)
        .opacity(frame.isEmpty ? 0 : 1)
        .allowsHitTesting(isSelected && !frame.isEmpty)
        .accessibilityHidden(!isSelected || frame.isEmpty)
        // The scene's camera already eases the movement. Never animate it twice.
        .transaction { $0.animation = nil }
    }
}

/// The Stillness Guide's outline, rendered as translucent glass without portrait details.
struct GuideCreationSilhouette: View {
    var showsPlus = true

    // Alpha bounds of SereneGuide-front.png (1000 × 1100), fitted into a square.
    // Keep the gallery's figure height and vertical alignment tied to the visible image.
    static let visibleBounds = CGRect(x: 94.0 / 1100, y: 118.0 / 1100,
                                      width: 909.0 / 1100, height: 880.0 / 1100)

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let outlineWidth = min(0.8, size * 0.004)
            ZStack {
                Ellipse().fill(.white.opacity(0.09))
                    .frame(width: size * 0.76, height: size * 0.10)
                    .blur(radius: 12).offset(y: size * (Self.visibleBounds.maxY - 0.5))
                silhouette
                    .foregroundStyle(LinearGradient(
                        colors: [.white.opacity(0.72), .white.opacity(0.40), .white.opacity(0.58)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                // Expand the alpha mask, then remove its centre to leave a fine rim.
                // The source colours never appear, and the centre stays transparent.
                ZStack {
                    ForEach(0..<8) { index in
                        let angle = Double(index) * .pi / 4
                        silhouette.offset(x: cos(angle) * outlineWidth, y: sin(angle) * outlineWidth)
                    }
                    silhouette.blendMode(.destinationOut)
                }
                .foregroundStyle(.white)
                .compositingGroup()
                .opacity(0.85)
                .shadow(color: .white.opacity(0.24), radius: 10)
                if showsPlus {
                    Image(systemName: "plus").font(.system(size: size * 0.09, weight: .ultraLight))
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(width: size * 0.22, height: size * 0.22)
                        .background(.white.opacity(0.07), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 0.7))
                        .offset(y: size * 0.005)
                }
            }.frame(width: size, height: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }.accessibilityHidden(true)
    }

    private var silhouette: some View {
        Image("guide_creation_silhouette")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
    }
}
