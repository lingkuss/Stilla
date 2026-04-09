import SwiftUI
import AVFoundation

struct VoiceSelectionView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    
    private let voices = GuruManager.shared.availableHighQualityVoices
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if voices.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(localized: "voice.none_found"))
                                .font(.headline)
                            Text(String(localized: "voice.quality_help"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label(String(localized: "voice.open_ios_settings"), systemImage: "gear")
                                Label(String(localized: "voice.go_to_accessibility"), systemImage: "accessibility")
                                Label(String(localized: "voice.spoken_content_path"), systemImage: "mouth")
                                Label(String(localized: "voice.download_enhanced"), systemImage: "icloud.and.arrow.down")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(voices, id: \.identifier) { voice in
                            Button {
                                manager.kaiVoiceIdentifier = voice.identifier
                                GuruManager.shared.previewVoice(identifier: voice.identifier)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Image(systemName: voice.gender == .female ? "person.fill.viewfinder" : "person.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            Text(voice.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                        }
                                        Text(voice.language)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if voice.quality == .premium {
                                        Text(String(localized: "voice.quality.premium"))
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                                            .foregroundStyle(.orange)
                                    } else if voice.quality == .enhanced {
                                        Text(String(localized: "voice.quality.enhanced"))
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(Color.blue.opacity(0.2)))
                                            .foregroundStyle(.blue)
                                    }
                                    
                                    if manager.kaiVoiceIdentifier == voice.identifier {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text(String(localized: "voice.available_header"))
                } footer: {
                    if !voices.isEmpty {
                        Text(String(localized: "voice.quality_footer"))
                    }
                }
            }
            .navigationTitle(String(localized: "nav.voice_studio"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.done")) { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
