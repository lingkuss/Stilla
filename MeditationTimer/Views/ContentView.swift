import SwiftUI

struct ContentView: View {
    @Environment(MeditationManager.self) private var manager

    @State private var showSettings = false
    @State private var showStats = false

    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                HStack {
                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // Status label
                statusLabel
                    .padding(.bottom, 20)

                // Breathing circle
                BreathingCircleView(
                    isActive: manager.state == .meditating,
                    progress: manager.progress
                )

                // Timer display
                Text(timerText)
                    .font(.system(size: 64, weight: .ultraLight, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .padding(.top, 24)
                    .contentTransition(.numericText())

                Spacer()

                // Action button
                actionButton
                    .padding(.bottom, 20)

                // Siri hint
                if manager.state == .idle {
                    Text("Or say: \"Hey Siri, start MeditationTimer\"")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.bottom, 30)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(manager)
        }
        .sheet(isPresented: $showStats) {
            StatisticsView()
                .environment(manager)
        }
        .animation(.easeInOut(duration: 0.6), value: manager.state)
    }

    // MARK: - Subviews

    private var backgroundGradient: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var backgroundColors: [Color] {
        switch manager.state {
        case .idle:
            return [
                Color(hue: 0.70, saturation: 0.5, brightness: 0.12),
                Color(hue: 0.75, saturation: 0.6, brightness: 0.08),
                Color(hue: 0.80, saturation: 0.4, brightness: 0.06),
            ]
        case .meditating:
            return [
                Color(hue: 0.68, saturation: 0.5, brightness: 0.15),
                Color(hue: 0.72, saturation: 0.55, brightness: 0.10),
                Color(hue: 0.78, saturation: 0.4, brightness: 0.07),
            ]
        case .complete:
            return [
                Color(hue: 0.55, saturation: 0.4, brightness: 0.15),
                Color(hue: 0.60, saturation: 0.5, brightness: 0.10),
                Color(hue: 0.65, saturation: 0.35, brightness: 0.07),
            ]
        }
    }

    private var statusLabel: some View {
        Text(statusText)
            .font(.title3.weight(.light))
            .foregroundStyle(.white.opacity(0.6))
            .tracking(2)
    }

    private var statusText: String {
        switch manager.state {
        case .idle: return "READY"
        case .meditating: return "BREATHE"
        case .complete: return "NAMASTE"
        }
    }

    private var timerText: String {
        switch manager.state {
        case .idle:
            let mins = manager.durationMinutes
            if mins == 0 {
                return "00:00"
            }
            return String(format: "%02d:00", mins)
        case .meditating, .complete:
            return manager.formattedTime
        }
    }

    private var actionButton: some View {
        Button {
            handleAction()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: actionIcon)
                    .font(.body.weight(.semibold))
                Text(actionText)
                    .font(.body.weight(.medium))
                    .tracking(1)
            }
            .foregroundStyle(actionForeground)
            .padding(.horizontal, 36)
            .padding(.vertical, 16)
            .background(actionBackground)
            .clipShape(Capsule())
        }
    }

    private var actionIcon: String {
        switch manager.state {
        case .idle: return "play.fill"
        case .meditating: return "stop.fill"
        case .complete: return "arrow.counterclockwise"
        }
    }

    private var actionText: String {
        switch manager.state {
        case .idle: return "BEGIN"
        case .meditating: return "STOP"
        case .complete: return "DONE"
        }
    }

    private var actionForeground: Color {
        switch manager.state {
        case .idle:
            return .white
        case .meditating:
            return .white.opacity(0.9)
        case .complete:
            return .white
        }
    }

    @ViewBuilder
    private var actionBackground: some View {
        switch manager.state {
        case .idle:
            Capsule()
                .fill(Color(hue: 0.55, saturation: 0.6, brightness: 0.7).opacity(0.4))
                .overlay(
                    Capsule()
                        .stroke(Color(hue: 0.55, saturation: 0.5, brightness: 0.9).opacity(0.3), lineWidth: 1)
                )
        case .meditating:
            Capsule()
                .fill(Color.white.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        case .complete:
            Capsule()
                .fill(Color(hue: 0.45, saturation: 0.5, brightness: 0.6).opacity(0.4))
                .overlay(
                    Capsule()
                        .stroke(Color(hue: 0.45, saturation: 0.4, brightness: 0.8).opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - Actions

    private func handleAction() {
        switch manager.state {
        case .idle:
            manager.start()
        case .meditating:
            manager.stop()
        case .complete:
            manager.reset()
        }
    }
}

// MARK: - Statistics View

struct StatisticsView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Total Time Hero
                    VStack(spacing: 8) {
                        Text("Total Journey")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .textCase(.uppercase)
                            .tracking(2)
                        
                        Text(formatStatTime(manager.totalSecondsMeditated))
                            .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 40)

                    // Journey Heatmap
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Consistency Map")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: Array(repeating: GridItem(.fixed(14), spacing: 4), count: 7), spacing: 4) {
                                ForEach(heatmapDates, id: \.self) { date in
                                    heatmapSquare(for: date)
                                }
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.05))
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Journey")
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

    // MARK: - Subviews

    private func heatmapSquare(for date: Date) -> some View {
        let seconds = manager.secondsMeditated(on: date)
        let isToday = Calendar.current.isDateInToday(date)
        
        // Color based on duration
        let color: Color
        if seconds == 0 {
            color = Color.white.opacity(0.04)
        } else if seconds < 300 {         // < 5 mins
            color = Color(hue: 0.55, saturation: 0.6, brightness: 0.4)
        } else if seconds < 900 {         // < 15 mins
            color = Color(hue: 0.55, saturation: 0.7, brightness: 0.6)
        } else if seconds < 1800 {        // < 30 mins
            color = Color(hue: 0.55, saturation: 0.8, brightness: 0.8)
        } else {                          // 30+ mins
            color = Color(hue: 0.55, saturation: 0.9, brightness: 1.0)
        }

        return RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(isToday ? Color.white.opacity(0.8) : Color.clear, lineWidth: 1)
            )
    }

    // MARK: - Helpers

    private var heatmapDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dates = manager.meditationHistory.keys.compactMap { formatter.date(from: $0) }
        
        // Start from either 90 days ago OR the earliest date, whichever is earlier
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: today)!
        let earliest = dates.min() ?? ninetyDaysAgo
        let baseStart = min(earliest, ninetyDaysAgo)
        
        // Pad the start so the grid always aligns to a Sunday (weekday 1)
        let weekday = calendar.component(.weekday, from: baseStart)
        let paddedStart = calendar.date(byAdding: .day, value: -(weekday - 1), to: baseStart)!
        
        let components = calendar.dateComponents([.day], from: paddedStart, to: today)
        let dayCount = components.day ?? 0
        
        return (0...dayCount).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: paddedStart)
        }
    }

    private func formatStatTime(_ seconds: Int) -> String {
        if seconds == 0 { return "0m" }
        if seconds < 60 { return "< 1m" }
        
        let mins = seconds / 60
        let hours = mins / 60
        let remainingMins = mins % 60
        
        if hours > 0 {
            if remainingMins > 0 {
                return "\(hours)h \(remainingMins)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(mins)m"
        }
    }
}
