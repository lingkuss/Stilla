import Foundation
import CoreGraphics
import ImageIO

// Networking isn't exercised by this macOS test harness. The backend has HTTP tests.
enum GuideCreatorCopy { static func text(_ en: String, _ sv: String) -> String { en } }
enum Secrets { static var kaiGuideImageBackendURL: URL? { nil } }
actor AppAttestAuthManager {
    static let shared = AppAttestAuthManager()
    func authorize(_ request: inout URLRequest) async throws {}
    func invalidateCachedToken() {}
}

@main struct GuideImageChecks {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let path = directory.appendingPathComponent("draft.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"version":1,"language":"sv","personality":"Lugn","voiceID":"existing-voice"}"#.utf8).write(to: path)
        var draft = try CustomGuideDraftStore.load(from: path)
        precondition(draft.imageDescription.isEmpty && draft.generatedImage == nil)
        precondition(draft.voiceID == "existing-voice" && draft.personality == "Lugn")

        let transparent = try png(opaque: false, blank: false)
        try CustomGuideImageGenerator.validateImage(transparent)
        for invalid in [try png(opaque: true, blank: false), try png(opaque: false, blank: true), Data("not png".utf8)] {
            do { try CustomGuideImageGenerator.validateImage(invalid); fatalError("Accepted an unusable image") }
            catch CustomGuideImageError.invalidImage { }
        }
        draft.imageDescription = "En fridfull räv"
        draft.referenceImage = Data("reference".utf8)
        draft.generatedImage = transparent
        draft.generatedImageFingerprint = draft.imageFingerprint
        precondition(draft.hasCurrentImage)
        try CustomGuideDraftStore.save(draft, to: path)
        let restored = try CustomGuideDraftStore.load(from: path)
        precondition(restored == draft)
        draft.imageDescription += " in blue"
        precondition(!draft.hasCurrentImage, "Changed appearance must not publish stale artwork")
        draft = restored
        draft.referenceImage = Data("another reference".utf8)
        precondition(!draft.hasCurrentImage, "Changed reference must regenerate artwork")
        draft = restored
        draft.name = "Moss"
        precondition(draft.hasCurrentImage, "Renaming must not charge for another image")

        let libraryURL = directory.appendingPathComponent("library")
        let library = CustomGuideCatalog(directory: libraryURL)
        func guide(_ id: String, name: String) -> KaiPersonality {
            KaiPersonality(id: id, name: name, shortDescription: "Custom", longDescription: "Custom", traits: [],
                sampleLine: "", promptInjection: "Calm", symbolName: "sparkles", imageName: id, isFreeTier: true)
        }
        let first = guide(draft.guideID, name: "Moss")
        let brief = try JSONEncoder().encode(draft)
        try library.add(first, image: transparent, brief: brief)
        try library.add(first, image: transparent, brief: brief)
        let second = guide(CustomGuideDraft().guideID, name: "River")
        try library.add(second, image: transparent, brief: brief)
        let reopened = CustomGuideCatalog(directory: libraryURL)
        precondition(reopened.personalities == [first, second], "Guides survive restart without duplicates")
        let storedArtwork = try Data(contentsOf: reopened.imageURL(for: first.imageName)!)
        precondition(storedArtwork == transparent)
        precondition(reopened.imageURL(for: "../../escape") == nil)
        let brokenURL = directory.appendingPathComponent("broken")
        try FileManager.default.createDirectory(at: brokenURL, withIntermediateDirectories: true)
        let brokenManifest = brokenURL.appendingPathComponent("guides.json")
        let corrupt = Data("keep me".utf8)
        try corrupt.write(to: brokenManifest)
        let broken = CustomGuideCatalog(directory: brokenURL)
        do { try broken.add(first, image: transparent, brief: brief); fatalError("Overwrote corrupt catalogue") }
        catch { }
        let preservedManifest = try Data(contentsOf: brokenManifest)
        precondition(preservedManifest == corrupt)
        precondition(broken.personalities.isEmpty)
        print("PASS: draft migration, image validation, reference persistence, stale-image detection, multiple guides, restart, duplicate retries, corrupt catalogue preservation")
    }

    static func png(opaque: Bool, blank: Bool) throws -> Data {
        let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        if opaque {
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
        }
        if !blank {
            context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1))
            context.fill(CGRect(x: 200, y: 200, width: 624, height: 624))
        }
        let bytes = NSMutableData()
        let destination = CGImageDestinationCreateWithData(bytes, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
        return bytes as Data
    }
}
