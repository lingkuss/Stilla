import SwiftUI
import PhotosUI
import ImageIO

/// This first experiment follows the app's Swedish/English language choice.
enum GuideCreatorCopy {
    static var swedish: Bool { AppLocalization.preferredLanguageCodes.first == "sv" }
    static func text(_ english: String, _ swedish: String) -> String { self.swedish ? swedish : english }
    static var title: String { text("Create your own guide", "Skapa din egen guide") }
    static var invitation: String { text("Start with words, an image, or both. Create a guide of your own.", "Utgå från ord, en bild eller båda. Skapa en guide som känns som din.") }
}

struct CustomGuideCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CustomGuideDraft()
    @State private var hasLoaded = false
    @State private var loadFailed = false
    @State private var saving = false
    @State private var photo: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var loadingPhoto = false
    @State private var generatedPreview: UIImage?
    @State private var generationID: UUID?
    @State private var generating = false
    @State private var generatingImage = false
    @State private var generationError: String?
    @State private var generationProgress = ""
    @State private var lightPreview = false
    @State private var choosingVoice = false
    @State private var describingVoice = false
    @FocusState private var editingVoice: Bool
    @State private var issue: Issue?
    @FocusState private var editingPersonality: Bool
    @FocusState private var editingAppearance: Bool

    private enum Issue: String, Identifiable {
        case photo, load, save
        var id: String { rawValue }
        var message: String {
            switch self {
            case .photo: return GuideCreatorCopy.text("This photo couldn't be opened. Please try another image.", "Bilden kunde inte öppnas. Försök med en annan bild.")
            case .load: return GuideCreatorCopy.text("Your saved draft couldn't be opened. It has been kept unchanged.", "Ditt sparade utkast kunde inte öppnas. Det finns kvar oförändrat.")
            case .save: return GuideCreatorCopy.text("Your guide couldn't be saved. Your image and choices are still here — please try again.", "Guiden kunde inte sparas. Din bild och dina val finns kvar här – försök igen.")
            }
        }
    }

    private let ink = Color(red: 0.88, green: 0.91, blue: 0.86)
    private let accent = Color(red: 0.74, green: 0.85, blue: 0.74)
    private var selectedVoiceName: String? {
        guard let id = draft.voiceID else { return nil }
        return draft.voiceName ?? CustomGuideVoice.examples(for: draft.language).first { $0.id == id }?.name
            ?? GuideCreatorCopy.text("Saved voice", "Sparad röst")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    introduction
                    nameSection
                    appearanceSection
                    referenceSection
                    languageSection
                    voiceSection
                    personalitySection
                    imageGenerationSection

                }
                .frame(maxWidth: 520).padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background {
                LinearGradient(colors: [Color(red: 0.10, green: 0.17, blue: 0.17), Color(red: 0.055, green: 0.095, blue: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { if loadFailed { dismiss() } else { save() } } label: {
                        Image(systemName: "xmark").font(.body.weight(.medium)).frame(width: 36, height: 36)
                    }.accessibilityLabel(GuideCreatorCopy.text("Close", "Stäng"))
                        .accessibilityIdentifier("guideCreator.close")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(GuideCreatorCopy.text("Done", "Klart")) { editingPersonality = false; editingVoice = false; editingAppearance = false }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .foregroundStyle(ink).tint(accent)
            .disabled(saving || generating)
            .navigationDestination(isPresented: $choosingVoice) {
                CustomGuideVoicePickerView(language: draft.language, selectedID: draft.voiceID) { voice in
                    draft.voiceID = voice.id
                    draft.voiceName = voice.name
                    draft.voicePreviewURL = voice.previewURL
                    choosingVoice = false
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(saving || generating || draft.hasContent)
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            do {
                draft = try CustomGuideDraftStore.load(defaultLanguage: .preferred(for: AppLocalization.preferredLanguageCodes.first))
                if CustomGuideCatalog.shared.personalities.contains(where: { $0.id == draft.guideID }) {
                    draft = CustomGuideDraft(language: .preferred(for: AppLocalization.preferredLanguageCodes.first))
                } else if draft.generatedImage != nil && draft.generatedImageFingerprint == nil {
                    // An existing image-only draft can be added without another paid generation.
                    draft.generatedImageFingerprint = draft.imageFingerprint
                }
                describingVoice = !draft.voiceDescription.isEmpty
                if let data = draft.referenceImage { image = UIImage(data: data) }
                if let data = draft.generatedImage { generatedPreview = UIImage(data: data) }
            } catch { loadFailed = true; issue = .load }
        }
        .task(id: photo) { await loadPhoto() }
        .task(id: generationID) {
            guard generationID != nil else { return }
            await createGuide()
        }
        .alert(item: $issue) { problem in
            Alert(title: Text(GuideCreatorCopy.text("Something went wrong", "Något gick fel")), message: Text(problem.message), dismissButton: .default(Text("OK")))
        }
    }

    private var canSave: Bool { hasLoaded && !loadFailed && !saving && !loadingPhoto && !generating }
    private var canCreate: Bool {
        canSave && draft.voiceID != nil && (draft.hasCurrentImage || draft.referenceImage != nil
            || !draft.imageDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(GuideCreatorCopy.text("A name", "Ett namn"), detail: GuideCreatorCopy.text("What would you like to call your guide?", "Vad vill du kalla din guide?"))
            TextField(GuideCreatorCopy.text("My guide", "Min guide"), text: $draft.name)
                .padding(18).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
                .accessibilityIdentifier("guideCreator.name")
                .onChange(of: draft.name) { _, value in
                    if value.count > 60 { draft.name = String(value.prefix(60)) }
                }
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(GuideCreatorCopy.text("Imagine your guide", "Föreställ dig din guide"), detail: GuideCreatorCopy.text("Describe your guide's appearance. A reference image is optional.", "Beskriv hur din guide ska se ut. En referensbild är valfri."))
            TextField(GuideCreatorCopy.text("A peaceful fox with silver fur and a moss-green robe…", "En fridfull räv med silverpäls och mossgrön mantel…"), text: $draft.imageDescription, axis: .vertical)
                .lineLimit(4...8).focused($editingAppearance)
                .padding(18).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 0.7))
                .accessibilityLabel(GuideCreatorCopy.text("Describe your guide's appearance", "Beskriv guidens utseende"))
                .accessibilityIdentifier("guideCreator.appearance")
                .onChange(of: draft.imageDescription) { _, value in
                    if value.count > 2000 { draft.imageDescription = String(value.prefix(2000)) }
                }
            Text(GuideCreatorCopy.text("Your guide will be seated in meditation, with a transparent background.", "Din guide får en sittande meditationsställning och transparent bakgrund."))
                .font(.footnote).foregroundStyle(ink.opacity(0.60))
        }
    }

    private var imageGenerationSection: some View {
        VStack(spacing: 16) {
            if let generatedPreview {
                Image(uiImage: generatedPreview).resizable().scaledToFit()
                    .frame(maxWidth: .infinity).frame(height: 310)
                    .background(lightPreview ? Color(red: 0.91, green: 0.91, blue: 0.84) : Color(red: 0.055, green: 0.09, blue: 0.15), in: RoundedRectangle(cornerRadius: 24))
                    .accessibilityLabel(GuideCreatorCopy.text("Your generated guide", "Din skapade guide"))
                    .accessibilityIdentifier("guideCreator.generatedImage")
                Button { lightPreview.toggle() } label: {
                    Label(lightPreview ? GuideCreatorCopy.text("Dark background", "Mörk bakgrund") : GuideCreatorCopy.text("Light background", "Ljus bakgrund"), systemImage: lightPreview ? "moon" : "sun.max")
                        .font(.footnote).frame(minHeight: 44)
                }.buttonStyle(.plain).accessibilityIdentifier("guideCreator.previewBackground")
            }
            Button {
                guard canCreate else { return }
                editingAppearance = false
                editingPersonality = false
                editingVoice = false
                generationError = nil
                generationProgress = GuideCreatorCopy.text("Preparing your guide…", "Förbereder din guide…")
                generating = true
                generationID = UUID()
            } label: {
                HStack(spacing: 10) {
                    if generating { ProgressView().tint(accent) }
                    else { Image(systemName: "sparkles") }
                    Text(generating ? GuideCreatorCopy.text("Creating your guide…", "Skapar din guide…") : GuideCreatorCopy.text("Create", "Skapa"))
                }.frame(maxWidth: .infinity, minHeight: 54)
                    .background(accent.opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke(accent.opacity(0.35), lineWidth: 1))
            }.buttonStyle(.plain).foregroundStyle(accent)
                .disabled(!canCreate)
                .accessibilityIdentifier("guideCreator.generateImage")
            Text(GuideCreatorCopy.text("Creates your guide and meditations for 5, 10, 15, 20, 25 and 30 minutes with your chosen voice. Saved for offline listening.", "Skapar din guide och meditationer på 5, 10, 15, 20, 25 och 30 minuter med din valda röst. Sparas för lyssning offline."))
                .font(.footnote).foregroundStyle(ink.opacity(0.65)).multilineTextAlignment(.center)
            if generating {
                Text(generationProgress).accessibilityIdentifier("guideCreator.progress")
                if generatingImage {
                    Text(GuideCreatorCopy.text("Creating your guide image in parallel…", "Skapar guidebilden samtidigt…"))
                        .font(.footnote).foregroundStyle(ink.opacity(0.65))
                }
                Text(GuideCreatorCopy.text("Keep the app open while your guide takes shape. Completed parts are saved along the way.", "Låt appen vara öppen medan guiden tar form. Färdiga delar sparas längs vägen."))
                    .font(.footnote).foregroundStyle(ink.opacity(0.65)).multilineTextAlignment(.center)
            }
            if let generationError {
                Text(generationError).font(.footnote).foregroundStyle(.orange.opacity(0.9))
                    .multilineTextAlignment(.center).accessibilityIdentifier("guideCreator.imageError")
            }
        }
    }

    private func createGuide() async {
        defer { generating = false }
        var audioPack: CustomGuideMeditationPack?
        do {
            // Keep the reference and brief even if generation fails.
            let brief = draft
            try await Task.detached(priority: .userInitiated) { try CustomGuideDraftStore.save(brief) }.value
            async let imageCreation: Void = createImageIfNeeded(brief: brief)
            do {
                audioPack = try await CustomGuideMeditationGenerator.generate(draft: brief) { generationProgress = $0 }
            } catch {
                // Preserve the already-started image even if the voice provider rejects a request.
                _ = try? await imageCreation
                throw error
            }
            generationProgress = GuideCreatorCopy.text("Voice recordings complete.", "Röstinspelningarna är klara.")
            try await imageCreation
        } catch is CancellationError { return }
        catch let error as CustomGuideAudioError { generationError = error.message; return }
        catch let error as CustomGuideImageError { generationError = error.message; return }
        catch { generationError = CustomGuideImageError.failed.message; return }

        do {
            guard let data = draft.generatedImage, let audioPack else { throw CustomGuideImageError.invalidImage }
            try CustomGuideImageGenerator.validateImage(data)
            let finished = draft
            let name = finished.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let presence = finished.personality.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = presence.isEmpty
                ? GuideCreatorCopy.text("Your own meditation guide.", "Din egen meditationsguide.") : presence
            let guide = KaiPersonality(id: finished.guideID,
                name: name.isEmpty ? GuideCreatorCopy.text("My guide", "Min guide") : name,
                shortDescription: summary, longDescription: summary, traits: [],
                sampleLine: audioPack.cues.first(where: { $0.id == "introduction" })?.text ?? "", promptInjection: "You are a calm meditation guide. " + presence,
                symbolName: "sparkles", imageName: finished.guideID, isFreeTier: true)
            try await Task.detached(priority: .userInitiated) {
                try CustomGuideDraftStore.save(finished)
                try CustomGuideMeditationLibrary.publish(audioPack, personality: guide)
                try CustomGuideCatalog.shared.add(guide, image: data, brief: JSONEncoder().encode(finished))
            }.value
            NotificationCenter.default.post(name: CustomGuideCatalog.didChange, object: guide.id)
            dismiss()
        } catch { issue = .save }
    }

    @MainActor private func createImageIfNeeded(brief: CustomGuideDraft) async throws {
        guard !brief.hasCurrentImage else { return }
        generatingImage = true
        defer { generatingImage = false }
        let data = try await CustomGuideImageGenerator.generate(description: brief.imageDescription, reference: brief.referenceImage)
        try Task.checkCancellation()
        draft.generatedImage = data
        draft.generatedImageFingerprint = brief.imageFingerprint
        generatedPreview = UIImage(data: data)
        let imageCheckpoint = draft
        try await Task.detached(priority: .userInitiated) { try CustomGuideDraftStore.save(imageCheckpoint) }.value
    }

    private var introduction: some View {
        VStack(spacing: 14) {
            GuideCreationSilhouette(showsPlus: false).frame(width: 94, height: 94)
            Text(GuideCreatorCopy.title).font(.system(.largeTitle, design: .serif)).multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(GuideCreatorCopy.invitation).font(.subheadline).foregroundStyle(ink.opacity(0.68))
                .multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(GuideCreatorCopy.text("Reference image", "Referensbild"), detail: GuideCreatorCopy.text("Optional · use an image as inspiration for your guide.", "Valfritt · använd en bild som inspiration för din guide."))
            PhotosPicker(selection: $photo, matching: .images) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.045))
                        if let image { Image(uiImage: image).resizable().scaledToFill() }
                        else { Image(systemName: "photo.badge.plus").font(.system(size: 23, weight: .light)).foregroundStyle(accent) }
                        if loadingPhoto { ProgressView().padding(12).background(.ultraThinMaterial, in: Circle()) }
                    }.frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(image == nil ? GuideCreatorCopy.text("Add a reference image", "Lägg till en referensbild") : GuideCreatorCopy.text("Change image", "Byt bild"))
                            .font(.subheadline.weight(.medium))
                        Text(GuideCreatorCopy.text("A person, an animal, a character, or inspiration.", "En människa, ett djur, en figur eller inspiration."))
                            .font(.footnote).foregroundStyle(ink.opacity(0.60))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "plus").font(.body.weight(.light))
                }.padding(14).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.10), lineWidth: 0.7))
            }.buttonStyle(.plain).accessibilityIdentifier("guideCreator.photo")
            if image != nil {
                Button(GuideCreatorCopy.text("Remove image", "Ta bort bild")) { photo = nil; loadingPhoto = false; draft.referenceImage = nil; image = nil }
                    .font(.footnote).frame(minHeight: 30).accessibilityIdentifier("guideCreator.removePhoto")
            }
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(GuideCreatorCopy.text("A language", "Ett språk"), detail: GuideCreatorCopy.text("The language of your guide and meditations.", "Språket för din guide och dina meditationer."))
            Menu {
                Picker(GuideCreatorCopy.text("Language", "Språk"), selection: Binding(
                    get: { draft.language },
                    set: { language in
                        guard language != draft.language else { return }
                        draft.selectLanguage(language)
                        choosingVoice = false
                        editingPersonality = false
                    }
                )) {
                    ForEach(CustomGuideLanguage.allCases) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "globe").foregroundStyle(accent)
                    Text(draft.language.nativeName).frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down").font(.caption)
                }.padding(18).contentShape(Rectangle())
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 0.7))
            }.buttonStyle(.plain)
                .accessibilityLabel(GuideCreatorCopy.text("Language", "Språk"))
                .accessibilityValue(draft.language.nativeName)
                .accessibilityIdentifier("guideCreator.language")
        }
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(GuideCreatorCopy.text("A voice", "En röst"), detail: GuideCreatorCopy.text("Listen. Find the one that feels right.", "Lyssna. Hitta den som känns rätt."))
            Button {
                editingPersonality = false
                editingVoice = false
                choosingVoice = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "waveform").foregroundStyle(accent)
                    Text(selectedVoiceName ?? GuideCreatorCopy.text("Explore voices", "Utforska röster"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right").font(.caption)
                }.padding(18).contentShape(Rectangle())
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 0.7))
            }.buttonStyle(.plain).accessibilityIdentifier("guideCreator.voices")
            Text(GuideCreatorCopy.text("Preview freely. Standard voices work with free credits; library voices require a paid ElevenLabs plan.", "Provlyssna fritt. Standardröster fungerar med gratiskrediter; biblioteksröster kräver en betald ElevenLabs-plan."))
                .font(.caption).foregroundStyle(ink.opacity(0.55))

        }
    }

    private var personalitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle(GuideCreatorCopy.text("A way of being", "Ett sätt att vara"), detail: GuideCreatorCopy.text("Your guide's personality", "Din guides personlighet"))
            ZStack(alignment: .topLeading) {
                if draft.personality.isEmpty {
                    Text(GuideCreatorCopy.text("Warm and grounded. A little poetic. Someone who reminds me that I don't have to rush…", "Varm och jordnära. Lite poetisk. Någon som påminner mig om att jag inte behöver skynda…"))
                        .foregroundStyle(ink.opacity(0.38)).padding(.horizontal, 18).padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $draft.personality).scrollContentBackground(.hidden)
                    .padding(12).frame(minHeight: 165)
                    .focused($editingPersonality)
                    .accessibilityLabel(GuideCreatorCopy.text("Personality", "Personlighet"))
                    .accessibilityIdentifier("guideCreator.personality")
                    .onChange(of: draft.personality) { _, value in
                        if value.count > 2000 { draft.personality = String(value.prefix(2000)) }
                    }
            }.font(.body).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.10), lineWidth: 0.7))
            Button {
                editingPersonality = false
                draft.personality = GuidePersonalityGenerator.generate(swedish: GuideCreatorCopy.swedish, excluding: draft.personality)
            } label: {
                Label(GuideCreatorCopy.text("Surprise me", "Slumpa personlighet"), systemImage: "shuffle")
                    .font(.subheadline).frame(minHeight: 44)
            }.buttonStyle(.plain).foregroundStyle(accent).accessibilityIdentifier("guideCreator.randomize")
        }
    }

    private func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(.title3, design: .serif)).accessibilityAddTraits(.isHeader)
            Text(detail).font(.footnote).foregroundStyle(ink.opacity(0.60))
        }
    }

    private func save() {
        guard canSave else { return }
        editingPersonality = false
        editingVoice = false
        editingAppearance = false
        saving = true
        var snapshot = draft
        snapshot.personality = snapshot.personality.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.voiceDescription = snapshot.voiceDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        snapshot.imageDescription = snapshot.imageDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await Task.detached(priority: .userInitiated) { try CustomGuideDraftStore.save(snapshot) }.value
                saving = false
                dismiss()
            } catch { saving = false; issue = .save }
        }
    }

    private func loadPhoto() async {
        guard let selection = photo else { return }
        loadingPhoto = true
        defer { if photo == selection { loadingPhoto = false } }
        do {
            guard let data = try await selection.loadTransferable(type: Data.self), data.count <= 30_000_000 else { throw CocoaError(.fileReadTooLarge) }
            let prepared = try await Task.detached(priority: .userInitiated) { try Self.prepareImage(data) }.value
            try Task.checkCancellation()
            guard photo == selection else { return }
            draft.referenceImage = prepared
            image = UIImage(data: prepared)
        } catch {
            guard !Task.isCancelled, photo == selection else { return }
            issue = .photo
        }
    }

    nonisolated private static func prepareImage(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024
              ] as CFDictionary), let jpeg = UIImage(cgImage: thumbnail).jpegData(compressionQuality: 0.84) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard jpeg.count <= 1_500_000 else { throw CocoaError(.fileReadTooLarge) }
        return jpeg
    }
}
