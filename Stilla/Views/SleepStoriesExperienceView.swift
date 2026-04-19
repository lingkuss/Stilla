import SwiftUI

struct SleepStoriesExperienceView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDuration: Int = 20
    @State private var headers: [SleepStoryHeader] = []
    @State private var selectedHeaderID: String?
    @State private var isGenerating = false
    @State private var showingPaywall = false
    @State private var showingError = false
    @State private var errorMessage = ""

    private let recentHeaderTitlesKey = "sleep.story.recent.titles"
    private let hasBootstrappedHeadersKey = "sleep.story.has_bootstrapped_headers"
    private let cachedHeadersKey = "sleep.story.cached.headers"

    private var availableStoryDurations: [Int] {
        manager.allDurations.filter { $0 > 0 && $0 <= KaiBrainService.maxAIGenerationDurationMinutes }
    }

    private var selectedHeader: SleepStoryHeader? {
        guard let selectedHeaderID else { return nil }
        return headers.first(where: { $0.id == selectedHeaderID })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hue: 0.62, saturation: 0.28, brightness: 0.08)
                    .ignoresSafeArea()

                if isGenerating {
                    ProgressView(String(localized: "sleep.generating"))
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            headerView
                            storyHeaderSection
                            durationSection
                            playButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    }
                }
            }
            .navigationTitle(String(localized: "sleep.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "ui.close")) { dismiss() }
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .preferredColorScheme(.dark)
            .task {
                selectedDuration = min(selectedDuration, KaiBrainService.maxAIGenerationDurationMinutes)
                await loadHeadersIfNeeded()
            }
            .sheet(isPresented: $showingPaywall) {
                KAIPaywallView()
            }
            .alert(String(localized: "sleep.error.title"), isPresented: $showingError) {
                Button(String(localized: "common.ok"), role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "sleep.subtitle"))
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.62))
            Text(String(localized: "sleep.help"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.top, 8)
    }

    private var storyHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "sleep.pick_story"))
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1)
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                Button {
                    headers = KaiBrainService.shared.fallbackSleepStoryHeaders(excluding: recentHeaderTitles)
                    selectedHeaderID = headers.first?.id
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text(String(localized: "sleep.refresh"))
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
            }

            LazyVStack(spacing: 10) {
                ForEach(headers) { header in
                    Button {
                        selectedHeaderID = header.id
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(header.title)
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundStyle(.white)
                            if let subtitle = header.subtitle, !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedHeaderID == header.id ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(selectedHeaderID == header.id ? Color.white.opacity(0.26) : Color.white.opacity(0.08), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "sleep.duration"))
                .font(.system(size: 10, weight: .bold))
                .kerning(1)
                .foregroundStyle(.white.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(availableStoryDurations, id: \.self) { mins in
                        Button {
                            selectedDuration = mins
                        } label: {
                            Text(String(format: String(localized: "kai.duration_minutes_format"), mins))
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(selectedDuration == mins ? Color.white.opacity(0.18) : Color.white.opacity(0.07))
                                        .overlay(
                                            Capsule()
                                                .strokeBorder(Color.white.opacity(selectedDuration == mins ? 0.22 : 0.08), lineWidth: 1)
                                        )
                                )
                                .foregroundStyle(selectedDuration == mins ? .white : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var playButton: some View {
        Button {
            generateAndStartStory()
        } label: {
            Text(String(localized: "sleep.play"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(.white))
        }
        .disabled(selectedHeader == nil || headers.isEmpty)
        .opacity((selectedHeader == nil || headers.isEmpty) ? 0.35 : 1)
        .padding(.top, 4)
    }

    @MainActor
    private func loadHeadersIfNeeded() async {
        guard headers.isEmpty else { return }
        let recent = recentHeaderTitles
        let hasBootstrapped = UserDefaults.standard.bool(forKey: hasBootstrappedHeadersKey)

        if let cached = loadCachedHeaders(), !cached.isEmpty {
            headers = cached
            selectedHeaderID = headers.first?.id
            return
        }

        if !hasBootstrapped {
            headers = KaiBrainService.shared.fallbackSleepStoryHeaders(excluding: recent)
            selectedHeaderID = headers.first?.id
            UserDefaults.standard.set(true, forKey: hasBootstrappedHeadersKey)
            saveCachedHeaders(headers)
            return
        }

        headers = KaiBrainService.shared.fallbackSleepStoryHeaders(excluding: recent)
        selectedHeaderID = headers.first?.id
        saveCachedHeaders(headers)
    }

    @MainActor
    private func generateAndStartStory() {
        guard let selectedHeader else { return }
        isGenerating = true

        Task {
            await StoreKitManager.shared.updateCustomerProductStatus()
            guard StoreKitManager.shared.isVindlaProSubscribed else {
                isGenerating = false
                showingPaywall = true
                return
            }

            do {
                let generation = try await KaiBrainService.shared.generateSleepStory(
                    themeTitle: selectedHeader.title,
                    themeSubtitle: selectedHeader.subtitle,
                    durationMinutes: selectedDuration,
                    excluding: recentHeaderTitles
                )
                var script = generation.script
                script.title = selectedHeader.title
                script.contentType = .sleepStory
                if script.tags.contains(where: { $0.caseInsensitiveCompare("Sleep Story") == .orderedSame }) == false {
                    script.tags.append("Sleep Story")
                }

                pushRecentHeaderTitle(selectedHeader.title)
                if !generation.nextHeaders.isEmpty {
                    saveCachedHeaders(generation.nextHeaders)
                }

                manager.currentScript = script
                manager.durationMinutes = selectedDuration
                manager.isGuruEnabled = true
                manager.start(durationMinutes: selectedDuration)

                dismiss()
            } catch {
                errorMessage = String(localized: "sleep.error.message")
                showingError = true
                isGenerating = false
            }
        }
    }

    private var recentHeaderTitles: [String] {
        (UserDefaults.standard.array(forKey: recentHeaderTitlesKey) as? [String]) ?? []
    }

    private func pushRecentHeaderTitle(_ title: String) {
        var values = recentHeaderTitles
        values.removeAll { $0.caseInsensitiveCompare(title) == .orderedSame }
        values.insert(title, at: 0)
        UserDefaults.standard.set(Array(values.prefix(12)), forKey: recentHeaderTitlesKey)
    }

    private func loadCachedHeaders() -> [SleepStoryHeader]? {
        guard let data = UserDefaults.standard.data(forKey: cachedHeadersKey) else { return nil }
        return try? JSONDecoder().decode([SleepStoryHeader].self, from: data)
    }

    private func saveCachedHeaders(_ value: [SleepStoryHeader]) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: cachedHeadersKey)
    }
}
