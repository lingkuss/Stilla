import SwiftUI

struct CustomGuideVoicePickerView: View {
    let language: CustomGuideLanguage
    let selectedID: String?
    let onSelect: (CustomGuideVoice) -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var audition = CustomGuidePreviewPlayer()
    @State private var search = ""
    @State private var tone = CustomGuideVoiceCatalog.Tone.all
    @State private var gender = CustomGuideVoiceCatalog.Gender.all
    @State private var favoritesOnly = false
    @State private var standardOnly = true
    @State private var favorites: [CustomGuideVoice] = []
    @State private var matches: [CustomGuideVoice] = []
    @State private var visibleCount = 30
    @State private var searching = true
    @AppStorage("guideCreator.favoriteVoices.v1") private var favoritesData = Data()
    private let ink = Color(red: 0.88, green: 0.91, blue: 0.86)
    private let accent = Color(red: 0.74, green: 0.85, blue: 0.74)

    private struct Query: Equatable, Sendable {
        let language: CustomGuideLanguage
        let text: String
        let tone: CustomGuideVoiceCatalog.Tone
        let gender: CustomGuideVoiceCatalog.Gender
        let favoritesOnly: Bool
        let standardOnly: Bool
        let favorites: [CustomGuideVoice]
    }
    private var query: Query {
        .init(language: language, text: search, tone: tone, gender: gender,
              favoritesOnly: favoritesOnly, standardOnly: standardOnly, favorites: favoritesOnly ? favorites : [])
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text(GuideCreatorCopy.text("A voice to come home to.", "En röst att landa hos."))
                    .font(.system(.title, design: .serif))
                Text(language.nativeName)
                    .font(.subheadline).foregroundStyle(ink.opacity(0.65))
                Toggle(GuideCreatorCopy.text("Standard voices · free trial", "Standardröster · gratis test"), isOn: $standardOnly)
                    .accessibilityIdentifier("guideVoices.standardOnly")
                searchField
                Picker(GuideCreatorCopy.text("Voice", "Röst"), selection: $gender) {
                    ForEach(CustomGuideVoiceCatalog.Gender.allCases) { value in
                        Text(genderName(value)).tag(value)
                            .accessibilityIdentifier("guideVoices.gender.\(value.rawValue)")
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("guideVoices.gender")
                filters
                Text(standardOnly
                     ? GuideCreatorCopy.text("Standard voices use the free credits. Previews are in English; your meditations use the language above.", "Standardröster använder gratiskrediterna. Röstproven är på engelska; meditationerna skapas på språket ovan.")
                     : GuideCreatorCopy.text("Library voices require a paid ElevenLabs plan for generation. Previews are free.", "Biblioteksröster kräver en betald ElevenLabs-plan för att skapa tal. Röstproven är gratis."))
                    .font(.caption).foregroundStyle(ink.opacity(0.60))
                if searching {
                    ProgressView().frame(maxWidth: .infinity).padding()
                } else if matches.isEmpty {
                    Text(favoritesOnly
                         ? GuideCreatorCopy.text("No matching favourites yet. Tap a heart to save a voice.", "Inga matchande favoriter ännu. Tryck på ett hjärta för att spara en röst.")
                         : GuideCreatorCopy.text("No voices match. Try another search or filter.", "Inga röster matchar. Prova en annan sökning eller ett annat filter."))
                        .font(.subheadline).foregroundStyle(ink.opacity(0.7)).padding(.vertical, 24)
                } else {
                    Text("\(matches.count) " + GuideCreatorCopy.text("voices", "röster"))
                        .font(.caption).foregroundStyle(ink.opacity(0.6)).accessibilityIdentifier("guideVoices.count")
                    ForEach(Array(matches.prefix(visibleCount))) { voice in voiceRow(voice) }
                    if visibleCount < matches.count {
                        Button(GuideCreatorCopy.text("Show more voices", "Visa fler röster")) { visibleCount += 30 }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .accessibilityIdentifier("guideVoices.more")
                    }
                }
                if audition.failed {
                    Text(GuideCreatorCopy.text("This preview couldn't be played. Try again or choose another voice.", "Röstprovet kunde inte spelas. Försök igen eller välj en annan röst."))
                        .font(.footnote).foregroundStyle(accent).accessibilityIdentifier("guideVoices.error")
                }
            }.padding(24).frame(maxWidth: 560).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(red: 0.075, green: 0.125, blue: 0.13).ignoresSafeArea())
        .foregroundStyle(ink).tint(accent)
        .navigationTitle(GuideCreatorCopy.text("Find your voice", "Hitta din röst"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { favorites = (try? JSONDecoder().decode([CustomGuideVoice].self, from: favoritesData)) ?? [] }
        .task(id: query) { await updateMatches() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { audition.stop() } }
        .onDisappear { audition.stop() }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(ink.opacity(0.55))
            TextField(GuideCreatorCopy.text("Search voices", "Sök röster"), text: $search)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.search).accessibilityIdentifier("guideVoices.search")
            if !search.isEmpty {
                Button { search = "" } label: { Image(systemName: "xmark.circle.fill").frame(width: 32, height: 32) }
                    .accessibilityLabel(GuideCreatorCopy.text("Clear search", "Rensa sökning"))
            }
        }.padding(14).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
    }

    private var filters: some View {
        HStack {
            Menu {
                Picker(GuideCreatorCopy.text("Tone", "Ton"), selection: $tone) {
                    ForEach(CustomGuideVoiceCatalog.Tone.allCases) { tone in Text(toneName(tone)).tag(tone) }
                }
            } label: {
                Label(toneName(tone), systemImage: "line.3.horizontal.decrease")
                    .font(.subheadline).frame(minHeight: 44)
            }.accessibilityIdentifier("guideVoices.tone")
            Spacer()
            Button { favoritesOnly.toggle() } label: {
                Label(GuideCreatorCopy.text("Favourites", "Favoriter"), systemImage: favoritesOnly ? "heart.fill" : "heart")
                    .font(.subheadline).frame(minHeight: 44)
            }.accessibilityAddTraits(favoritesOnly ? .isSelected : [])
                .accessibilityIdentifier("guideVoices.favorites")
        }
    }

    private func voiceRow(_ voice: CustomGuideVoice) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button { audition.toggle(voice) } label: {
                    ZStack {
                        Circle().fill(accent.opacity(0.13))
                        if audition.voiceID == voice.id && audition.isLoading { ProgressView().controlSize(.small) }
                        else { Image(systemName: audition.voiceID == voice.id ? "stop.fill" : "play.fill").font(.system(size: 14)) }
                    }.frame(width: 48, height: 48)
                }.accessibilityLabel((audition.voiceID == voice.id ? GuideCreatorCopy.text("Stop ", "Stoppa ") : GuideCreatorCopy.text("Listen to ", "Lyssna på ")) + voice.name)
                    .accessibilityIdentifier("guideVoices.preview.\(voice.id)")
                VStack(alignment: .leading, spacing: 5) {
                    Text(voice.name).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    if !voice.accent.isEmpty { Text(voice.accent).font(.caption).foregroundStyle(ink.opacity(0.6)) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button { toggleFavorite(voice) } label: {
                    Image(systemName: isFavorite(voice) ? "heart.fill" : "heart").frame(width: 44, height: 44)
                }.accessibilityLabel((isFavorite(voice) ? GuideCreatorCopy.text("Remove favourite ", "Ta bort favorit ") : GuideCreatorCopy.text("Save favourite ", "Spara favorit ")) + voice.name)
                    .accessibilityIdentifier("guideVoices.favorite.\(voice.id)")
            }
            if !voice.detail.isEmpty { Text(voice.detail).font(.footnote).foregroundStyle(ink.opacity(0.65)).lineLimit(3) }
            Button { audition.stop(); onSelect(voice) } label: {
                HStack {
                    Text(voice.id == selectedID ? GuideCreatorCopy.text("Selected voice", "Vald röst") : GuideCreatorCopy.text("Choose voice", "Välj röst"))
                    Spacer()
                    Image(systemName: voice.id == selectedID ? "checkmark.circle.fill" : "arrow.right")
                }.font(.subheadline).frame(minHeight: 44).contentShape(Rectangle())
            }.accessibilityLabel(GuideCreatorCopy.text("Choose ", "Välj ") + voice.name)
                .accessibilityIdentifier("guideVoices.select.\(voice.id)")
        }.padding(16).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.09), lineWidth: 0.7))
            .buttonStyle(.plain)
    }

    private func toneName(_ tone: CustomGuideVoiceCatalog.Tone) -> String {
        switch tone {
        case .all: return GuideCreatorCopy.text("All tones", "Alla toner")
        case .calm: return GuideCreatorCopy.text("Calm", "Lugn")
        case .warm: return GuideCreatorCopy.text("Warm", "Varm")
        case .deep: return GuideCreatorCopy.text("Deep", "Djup")
        case .soft: return GuideCreatorCopy.text("Soft", "Mjuk")
        }
    }

    private func genderName(_ gender: CustomGuideVoiceCatalog.Gender) -> String {
        switch gender {
        case .all: return GuideCreatorCopy.text("All", "Alla")
        case .female: return GuideCreatorCopy.text("Female", "Kvinnliga")
        case .male: return GuideCreatorCopy.text("Male", "Manliga")
        }
    }

    private func isFavorite(_ voice: CustomGuideVoice) -> Bool {
        favorites.contains { CustomGuideVoiceCatalog.key($0) == CustomGuideVoiceCatalog.key(voice) }
    }
    private func toggleFavorite(_ voice: CustomGuideVoice) {
        if isFavorite(voice) { favorites.removeAll { CustomGuideVoiceCatalog.key($0) == CustomGuideVoiceCatalog.key(voice) } }
        else { favorites.append(voice) }
        if let data = try? JSONEncoder().encode(favorites) { favoritesData = data }
    }
    private func updateMatches() async {
        audition.stop()
        searching = true
        visibleCount = 30
        do { try await Task.sleep(for: .milliseconds(180)) } catch { return }
        let query = query
        let results = await Task.detached(priority: .userInitiated) {
            let catalog = CustomGuideVoiceCatalog.voices.filter { query.standardOnly ? $0.category == "premade" : $0.category == "high_quality" }
            let voices = query.favoritesOnly ? CustomGuideVoiceCatalog.favorites(query.favorites, in: catalog) : catalog
            return CustomGuideVoiceCatalog.search(voices, language: query.language, text: query.text, tone: query.tone, gender: query.gender)
        }.value
        guard !Task.isCancelled else { return }
        matches = results
        searching = false
    }
}
