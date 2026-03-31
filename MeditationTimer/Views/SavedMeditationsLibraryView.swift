import SwiftUI

struct SavedMeditationsLibraryView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(hue: 0.72, saturation: 0.4, brightness: 0.05)
                    .ignoresSafeArea()
                
                if manager.savedMeditations.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(manager.savedMeditations) { script in
                            SavedMeditationRow(script: script) {
                                playScript(script)
                            } onDelete: {
                                manager.removeSavedMeditation(script.id)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .padding(.top, 10)
                }
            }
            .navigationTitle("Your Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.1))
            
            VStack(spacing: 8) {
                Text("Your Library is Empty")
                    .font(.system(size: 18, weight: .medium))
                
                Text("Complete a session with Kai and save it to see it here.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
        }
    }
    
    private func playScript(_ script: MeditationScript) {
        // Prepare state
        manager.durationMinutes = script.durationMinutes
        manager.isGuruEnabled = true
        manager.currentScript = script
        
        // Load into player
        GuruManager.shared.play(script: script)
        
        // Start timer
        manager.start(durationMinutes: script.durationMinutes)
        
        dismiss()
    }
}

struct SavedMeditationRow: View {
    let script: MeditationScript
    let onPlay: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "quote.bubble.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hue: 0.55, saturation: 0.4, brightness: 0.9))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(script.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                    
                    Text("\(script.durationMinutes)m Journey")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding(.vertical, 6)
    }
}
