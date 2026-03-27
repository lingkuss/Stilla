import SwiftUI

struct SettingsView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var manager = manager

        NavigationStack {
            List {
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

                    Picker(selection: $manager.breathingCueMode) {
                        ForEach(MeditationManager.BreathingCueMode.allCases, id: \.self) { mode in
                            let needsIAP = (mode == .sound || mode == .both)
                            let locked = needsIAP && !StoreKitManager.shared.isPurchased(StoreKitManager.techniqueLibraryID)
                            if locked {
                                Label(mode.rawValue, systemImage: "lock.fill").tag(mode)
                            } else {
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                    } label: {
                        Label("Breathing Cues", systemImage: "metronome.fill")
                    }
                } header: {
                    Label("Feedback", systemImage: "hand.tap.fill")
                } footer: {
                    if !StoreKitManager.shared.isPurchased(StoreKitManager.techniqueLibraryID) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Sound cues require the Technique Library unlock")
                            
                            Button {
                                Task {
                                    await StoreKitManager.shared.purchase(StoreKitManager.techniqueLibraryID)
                                }
                            } label: {
                                Text("Unlock for $1.99")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color(hue: 0.55, saturation: 0.6, brightness: 0.7))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Text("Subtle breath sounds at each inhale and exhale transition")
                    }
                }

                // Daily Reminder
                Section {
                    Toggle(isOn: $manager.dailyReminderEnabled) {
                        Label("Daily Reminder", systemImage: "clock.badge.checkmark.fill")
                    }
                    .onChange(of: manager.dailyReminderEnabled) { _, newValue in
                        if newValue {
                            Task {
                                let granted = await NotificationManager.shared.requestAuthorization()
                                if !granted {
                                    manager.dailyReminderEnabled = false
                                } else {
                                    manager.updateDailyReminder()
                                }
                            }
                        } else {
                            manager.updateDailyReminder()
                        }
                    }

                    if manager.dailyReminderEnabled {
                        DatePicker("Reminder Time", selection: $manager.dailyReminderTime, displayedComponents: .hourAndMinute)
                            .onChange(of: manager.dailyReminderTime) { _, _ in
                                manager.updateDailyReminder()
                            }
                    }
                } header: {
                    Label("Mindfulness", systemImage: "sparkles")
                } footer: {
                    Text("Receive a gentle notification to help you stay consistent.")
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
