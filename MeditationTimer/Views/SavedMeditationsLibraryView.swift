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
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
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
                    
                    Button(action: onPlay) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color(hue: 0.55, saturation: 0.4, brightness: 0.9))
                    }
                    .buttonStyle(.plain)
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.leading, 4)
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    ForEach(script.steps) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            
                            Text(step.text)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineSpacing(4)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
                )
        }
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding(.vertical, 6)
    }
}
