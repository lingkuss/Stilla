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
                            Text("No high-quality voices found.")
                                .font(.headline)
                            Text("Mimir works best with Enhanced or Premium voices. You can download them in your iPhone Settings.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Open iOS Settings", systemImage: "gear")
                                Label("Go to Accessibility", systemImage: "accessibility")
                                Label("Spoken Content > Voices", systemImage: "mouth")
                                Label("Download an 'Enhanced' English voice", systemImage: "icloud.and.arrow.down")
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
                                        Text("PREMIUM")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Capsule().fill(Color.orange.opacity(0.2)))
                                            .foregroundStyle(.orange)
                                    } else if voice.quality == .enhanced {
                                        Text("ENHANCED")
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
                    Text("AVAILABLE VOICES")
                } footer: {
                    if !voices.isEmpty {
                        Text("Higher quality voices provide a more natural, human-like guidance from Mimir.")
                    }
                }
            }
            .navigationTitle("Mimir's Voice Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
