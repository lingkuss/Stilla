import SwiftUI

struct SavedMeditationsLibraryView: View {
    @Environment(MeditationManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedFilter: LibraryFilter = .all
    @State private var selectedPersonalityID: String = "all"
    @State private var showPaywall = false
    @State private var store = StoreKitManager.shared

    private enum LibraryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case favorites = "Favorites"

        var id: String { rawValue }
    }

    private var visibleMeditations: [MeditationScript] {
        manager.savedMeditations
            .filter(matchesFilter)
            .filter(matchesSearch)
            .sorted { lhs, rhs in
                if lhs.isFavorite != rhs.isFavorite {
                    return lhs.isFavorite && !rhs.isFavorite
                }
                return lhs.createdAt > rhs.createdAt
            }
    }

    private var suggestedTags: [String] {
        let defaults = ["Sleep", "Focus", "Calm", "Stress", "Morning", "Evening"]
        let existing = manager.savedMeditations.flatMap(\.tags)
        return Array(Set(defaults + existing)).sorted()
    }

    private var availablePersonalities: [KaiPersonality] {
        let ids = Set(manager.savedMeditations.compactMap(\.kaiPersonalityID))
        return KaiPersonality.all.filter { ids.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hue: 0.72, saturation: 0.4, brightness: 0.05)
                    .ignoresSafeArea()

                if manager.savedMeditations.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            libraryControls

                            if visibleMeditations.isEmpty {
                                filteredEmptyState
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(visibleMeditations) { script in
                                        SavedMeditationRow(
                                            script: script,
                                            suggestedTags: suggestedTags,
                                            onPlay: { playScript(script) },
                                            onToggleFavorite: { manager.toggleFavoriteSavedMeditation(script.id) },
                                            onRename: { manager.renameSavedMeditation(script.id, to: $0) },
                                            onDelete: { manager.removeSavedMeditation(script.id) },
                                            onAddTag: { manager.addTag($0, toSavedMeditation: script.id) },
                                            onRemoveTag: { manager.removeTag($0, fromSavedMeditation: script.id) }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
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
            .sheet(isPresented: $showPaywall) {
                KAIPaywallView()
            }
        }
    }

    private var libraryControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.35))

                TextField("Search title or tag", text: $searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.25))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )

            Picker("Filter", selection: $selectedFilter) {
                ForEach(LibraryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            if !availablePersonalities.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        personalityFilterChip(title: "All Personas", personalityID: "all")

                        ForEach(availablePersonalities) { personality in
                            personalityFilterChip(title: personality.name, personalityID: personality.id)
                        }
                    }
                }
            }
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

                Text("Complete a session with Kai and save it to build your personal collection.")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)
        }
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.15))

            Text("No Matches")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)

            Text("Try a different search or switch back to all meditations.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func matchesFilter(_ script: MeditationScript) -> Bool {
        switch selectedFilter {
        case .all:
            break
        case .favorites:
            guard script.isFavorite else { return false }
        }

        if selectedPersonalityID != "all" {
            return script.kaiPersonalityID == selectedPersonalityID
        }

        return true
    }

    private func matchesSearch(_ script: MeditationScript) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        if script.title.localizedCaseInsensitiveContains(query) {
            return true
        }

        if let personalityName = script.resolvedKaiPersonalityName,
           personalityName.localizedCaseInsensitiveContains(query) {
            return true
        }

        return script.tags.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func playScript(_ script: MeditationScript) {
        if !store.isKAISubscribed {
            showPaywall = true
            return
        }

        manager.durationMinutes = script.durationMinutes
        manager.isGuruEnabled = true
        manager.currentScript = script

        GuruManager.shared.play(script: script)
        manager.start(durationMinutes: script.durationMinutes)

        dismiss()
    }

    private func personalityFilterChip(title: String, personalityID: String) -> some View {
        Button {
            selectedPersonalityID = personalityID
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(selectedPersonalityID == personalityID ? .black : .white.opacity(0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selectedPersonalityID == personalityID ? Color.white : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
    }
}

struct SavedMeditationRow: View {
    let script: MeditationScript
    let suggestedTags: [String]
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onAddTag: (String) -> Void
    let onRemoveTag: (String) -> Void

    @State private var isExpanded = false
    @State private var draftTitle: String
    @State private var newTagText = ""

    private static let createdDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    init(
        script: MeditationScript,
        suggestedTags: [String],
        onPlay: @escaping () -> Void,
        onToggleFavorite: @escaping () -> Void,
        onRename: @escaping (String) -> Void,
        onDelete: @escaping () -> Void,
        onAddTag: @escaping (String) -> Void,
        onRemoveTag: @escaping (String) -> Void
    ) {
        self.script = script
        self.suggestedTags = suggestedTags
        self.onPlay = onPlay
        self.onToggleFavorite = onToggleFavorite
        self.onRename = onRename
        self.onDelete = onDelete
        self.onAddTag = onAddTag
        self.onRemoveTag = onRemoveTag
        _draftTitle = State(initialValue: script.title)
    }

    private var displayedSuggestions: [String] {
        suggestedTags.filter { suggestion in
            !script.tags.contains(where: { $0.caseInsensitiveCompare(suggestion) == .orderedSame })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 48, height: 48)

                        if let personality = script.generatedPersonality {
                            Image(personality.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: script.isFavorite ? "heart.fill" : "quote.bubble.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(script.isFavorite ? .pink : Color(hue: 0.55, saturation: 0.4, brightness: 0.9))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(script.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)

                            if script.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.yellow)
                            }
                        }

                        Text("\(script.durationMinutes)m Journey")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.4))

                        Text("Created \(Self.createdDateFormatter.string(from: script.createdAt))")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.35))

                        if let personalityName = script.resolvedKaiPersonalityName {
                            personalityBadge(personalityName)
                        }

                        if !script.tags.isEmpty {
                            tagWrap(script.tags, removable: false)
                        }
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

                    HStack(spacing: 10) {
                        libraryActionButton(
                            title: script.isFavorite ? "Unfavorite" : "Favorite",
                            systemImage: script.isFavorite ? "heart.slash" : "heart"
                        ) {
                            onToggleFavorite()
                        }

                        libraryActionButton(title: "Rename", systemImage: "pencil") {
                            rename()
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Created")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))

                            Text(Self.createdDateFormatter.string(from: script.createdAt))
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.72))
                        }

                        if let personalityName = script.resolvedKaiPersonalityName {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Generated With")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.6))

                                personalityBadge(personalityName)
                            }
                        }

                        Text("Title")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))

                        HStack(spacing: 10) {
                            TextField("Meditation title", text: $draftTitle)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .onSubmit(rename)

                            Button("Save") {
                                rename()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hue: 0.55, saturation: 0.4, brightness: 0.8))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tags")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))

                        if !script.tags.isEmpty {
                            tagWrap(script.tags, removable: true)
                        }

                        HStack(spacing: 10) {
                            TextField("Add a tag", text: $newTagText)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()

                            Button("Add") {
                                addTag()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(hue: 0.55, saturation: 0.4, brightness: 0.8))
                        }

                        if !displayedSuggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(displayedSuggestions.prefix(6), id: \.self) { suggestion in
                                        Button(suggestion) {
                                            onAddTag(suggestion)
                                        }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.75))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(Color.white.opacity(0.06)))
                                    }
                                }
                            }
                        }
                    }

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
            Button(action: onToggleFavorite) {
                Label(script.isFavorite ? "Unfavorite" : "Favorite", systemImage: script.isFavorite ? "heart.slash" : "heart")
            }

            Button(action: rename) {
                Label("Rename", systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .padding(.vertical, 6)
        .onChange(of: script.title) { _, newValue in
            draftTitle = newValue
        }
    }

    @ViewBuilder
    private func tagWrap(_ tags: [String], removable: Bool) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                if removable {
                    Button {
                        onRemoveTag(tag)
                    } label: {
                        HStack(spacing: 6) {
                            Text(tag)
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(tag)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }
            }
        }
    }

    private func libraryActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private func addTag() {
        let tag = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        onAddTag(tag)
        newTagText = ""
    }

    private func rename() {
        let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            draftTitle = script.title
            return
        }
        onRename(trimmed)
        draftTitle = trimmed
    }

    private func personalityBadge(_ name: String) -> some View {
        Text(name)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(hue: 0.55, saturation: 0.35, brightness: 0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(hue: 0.55, saturation: 0.4, brightness: 0.18).opacity(0.55)))
            .overlay(
                Capsule()
                    .strokeBorder(Color(hue: 0.55, saturation: 0.3, brightness: 0.85).opacity(0.35), lineWidth: 1)
            )
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }

            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth.isFinite ? maxWidth : currentX, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
