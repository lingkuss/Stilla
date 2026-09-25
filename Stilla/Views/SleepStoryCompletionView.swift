import SwiftUI

struct SleepStoryCompletionView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    private let sleepPreviewURL = URL(
        string: "https://vindla-three.vercel.app/try-mimir?need=sleep&guide=guardian&campaign=website&ref=share"
    )!

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hue: 0.62, saturation: 0.28, brightness: 0.08)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(.white.opacity(0.85))

                    VStack(spacing: 8) {
                        Text(String(localized: "sleep.post_session.title"))
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)

                        Text(String(localized: "sleep.post_session.body"))
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        if manager.currentScript != nil, !manager.isCurrentScriptSaved {
                            Button {
                                manager.saveCurrentScript()
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } label: {
                                Text(String(localized: "reflection.save_sleep_story"))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Capsule().fill(.white))
                            }
                        }

                        ShareLink(
                            item: sleepPreviewURL,
                            subject: Text("Vindla"),
                            message: Text(String(localized: "sleep.post_session.share_preview_message"))
                        ) {
                            Label(
                                String(localized: "sleep.post_session.share_preview"),
                                systemImage: "square.and.arrow.up"
                            )
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                            )
                        }

                        Button(String(localized: "ui.done")) {
                            dismiss()
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.done")) {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
}
