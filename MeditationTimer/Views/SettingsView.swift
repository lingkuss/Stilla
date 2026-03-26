import SwiftUI

struct SettingsView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    @State private var showAddDuration = false
    @State private var customDurationText = ""

    var body: some View {
        @Bindable var manager = manager

        NavigationStack {
            List {
                // Duration
                Section {
                    durationGrid
                } header: {
                    Label("Duration", systemImage: "timer")
                } footer: {
                    Text("Tap \"+\" to add a custom duration. Long-press a custom duration to remove it.")
                }

                // Sounds
                Section {
                    soundPicker(title: "Start Sound", selection: $manager.startSound)
                    soundPicker(title: "End Sound", selection: $manager.endSound)
                } header: {
                    Label("Chimes", systemImage: "bell.fill")
                }

                // Ambient
                Section {
                    Toggle(isOn: $manager.ambientRainEnabled) {
                        Label("Rain Ambience", systemImage: "cloud.rain.fill")
                    }
                } header: {
                    Label("During Meditation", systemImage: "waveform")
                } footer: {
                    Text("Plays gentle rain sounds during your session")
                }

                // Haptics
                Section {
                    Toggle(isOn: $manager.hapticEnabled) {
                        Label("Haptic Feedback", systemImage: "iphone.radiowaves.left.and.right")
                    }
                } header: {
                    Label("Feedback", systemImage: "hand.tap.fill")
                } footer: {
                    Text("Gentle vibration when meditation starts and ends")
                }

                // Siri Tips
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        voiceCommandRow("\"Hey Siri, begin MeditationTimer\"", desc: "Begin with saved duration")
                        voiceCommandRow("\"Hey Siri, meditate for X minutes\"", desc: "Begin with custom duration")
                        voiceCommandRow("\"Hey Siri, begin limitless meditation with MeditationTimer\"", desc: "Begin a limitless stopwatch")
                        voiceCommandRow("\"Hey Siri, end MeditationTimer\"", desc: "End session early")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Voice Commands", systemImage: "mic.fill")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
            .scrollContentBackground(.hidden)
            .background(
                Color(hue: 0.72, saturation: 0.4, brightness: 0.10)
                    .ignoresSafeArea()
            )
            .preferredColorScheme(.dark)
            .alert("Custom Duration", isPresented: $showAddDuration) {
                TextField("Minutes (1–180)", text: $customDurationText)
                    .keyboardType(.numberPad)
                Button("Add") {
                    if let mins = Int(customDurationText), mins >= 1, mins <= 180 {
                        manager.addCustomDuration(mins)
                        manager.durationMinutes = mins
                    }
                    customDurationText = ""
                }
                Button("Cancel", role: .cancel) {
                    customDurationText = ""
                }
            } message: {
                Text("Enter a duration in minutes.")
            }
        }
    }

    // MARK: - Duration Grid

    private var durationGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            // Open-ended mode
            openEndedButton
            
            ForEach(manager.allDurations, id: \.self) { mins in
                durationButton(for: mins)
            }

            // Add button
            Button {
                showAddDuration = true
            } label: {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var openEndedButton: some View {
        let isSelected = manager.durationMinutes == 0

        return Button {
            manager.durationMinutes = 0
        } label: {
            Text("∞")
                .font(.title2.weight(.light))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected
                              ? Color(hue: 0.55, saturation: 0.6, brightness: 0.7)
                              : Color.white.opacity(0.08))
                )
                .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
        }
        .buttonStyle(.plain)
    }

    private func durationButton(for mins: Int) -> some View {
        let isSelected = manager.durationMinutes == mins
        let isCustom = manager.isCustomDuration(mins)

        return Button {
            manager.durationMinutes = mins
        } label: {
            Text(formatDuration(mins))
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected
                              ? Color(hue: 0.55, saturation: 0.6, brightness: 0.7)
                              : Color.white.opacity(0.08))
                )
                .overlay(
                    // Subtle dot for custom durations
                    Group {
                        if isCustom {
                            Circle()
                                .fill(Color(hue: 0.45, saturation: 0.5, brightness: 0.8))
                                .frame(width: 5, height: 5)
                                .padding(5)
                        }
                    },
                    alignment: .topTrailing
                )
                .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isCustom {
                Button(role: .destructive) {
                    manager.removeCustomDuration(mins)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }

    /// Formats minutes, showing "1h" / "1h30" style for 60+.
    private func formatDuration(_ mins: Int) -> String {
        if mins < 60 {
            return "\(mins)m"
        } else if mins % 60 == 0 {
            return "\(mins / 60)h"
        } else {
            return "\(mins / 60)h\(mins % 60)"
        }
    }

    // MARK: - Sound Picker

    private func soundPicker(title: String, selection: Binding<SoundEngine.Sound>) -> some View {
        Picker(title, selection: selection) {
            ForEach(SoundEngine.Sound.allCases, id: \.self) { sound in
                Text(sound.rawValue).tag(sound)
            }
        }
    }

    // MARK: - Voice Command Row

    private func voiceCommandRow(_ command: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(command)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(hue: 0.55, saturation: 0.5, brightness: 0.9))
            Text(desc)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
