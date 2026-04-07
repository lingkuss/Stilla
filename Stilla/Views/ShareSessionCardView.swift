import SwiftUI

struct ShareSessionCardView: View {
    let script: MeditationScript
    let personaUIImage: UIImage?

    private var personaName: String {
        script.resolvedKaiPersonalityName ?? "Mimir"
    }

    private var snippet: String {
        // Pick the most evocative step — skip short openers, find something meaty
        let best = script.steps
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 30 }
            .first ?? script.steps.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if best.count <= 160 { return best }
        return String(best.prefix(157)) + "…"
    }

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM d, yyyy"
        return f.string(from: script.createdAt)
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hue: 0.68, saturation: 0.5, brightness: 0.16),
                    Color(hue: 0.74, saturation: 0.55, brightness: 0.10),
                    Color(hue: 0.78, saturation: 0.4, brightness: 0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Persona image — large hero area
                if let uiImage = personaUIImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 420, height: 280)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [.clear, Color(hue: 0.74, saturation: 0.55, brightness: 0.10)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 16) {
                    // Persona name + title
                    VStack(alignment: .leading, spacing: 6) {
                        Text(personaName.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .kerning(2)
                            .foregroundStyle(.white.opacity(0.5))

                        Text(script.title)
                            .font(.system(size: 26, weight: .light, design: .serif))
                            .italic()
                            .foregroundStyle(.white)
                    }

                    // Quote snippet
                    Text("\u{201C}\(snippet)\u{201D}")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    // Footer
                    HStack {
                        HStack(spacing: 6) {
                            Text("✦")
                                .font(.system(size: 10))
                            Text("Vindla")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.5))

                        Spacer()

                        Text("\(script.durationMinutes) min · \(formattedDate)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 420, height: 560)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}
