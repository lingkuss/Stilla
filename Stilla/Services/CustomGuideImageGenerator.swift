import Foundation
import ImageIO
import CoreGraphics

enum CustomGuideImageError: Error {
    case notConfigured, invalidImage, referenceTooLarge, rateLimited, unavailable, blocked, timedOut, authentication, failed

    var message: String {
        func text(_ en: String, _ sv: String) -> String { GuideCreatorCopy.text(en, sv) }
        switch self {
        case .notConfigured, .unavailable:
            return text("Image creation isn't available right now. Your description and reference have been kept.", "Bildskapandet är inte tillgängligt just nu. Din beskrivning och referens finns kvar.")
        case .invalidImage:
            return text("The image didn't have the transparent background we need. Your previous image has been kept. Try again.", "Bilden fick inte den transparenta bakgrund vi behöver. Din tidigare bild finns kvar. Försök igen.")
        case .referenceTooLarge:
            return text("This reference image is too large. Please choose another image.", "Referensbilden är för stor. Välj en annan bild.")
        case .rateLimited:
            return text("Image creation has reached its limit for now. Please try again later.", "Gränsen för bildskapandet är nådd för stunden. Försök igen senare.")
        case .blocked:
            return text("This image couldn't be created. Try changing the description or reference image.", "Den här bilden kunde inte skapas. Prova att ändra beskrivningen eller referensbilden.")
        case .timedOut:
            return text("The image took too long to arrive. No new attempt was started automatically.", "Bilden tog för lång tid att komma fram. Inget nytt försök startades automatiskt.")
        case .authentication:
            return text("The connection couldn't verify this device. Try again in a moment.", "Anslutningen kunde inte verifiera den här enheten. Försök igen om en stund.")
        case .failed:
            return text("The image couldn't be created. Your description and previous image have been kept.", "Bilden kunde inte skapas. Din beskrivning och tidigare bild finns kvar.")
        }
    }
}

enum CustomGuideImageGenerator {
    private struct Request: Encodable {
        let description: String
        let referenceImage: Data?
    }
    private struct Failure: Decodable { let code: String? }

    @MainActor static func generate(description: String, reference: Data?) async throws -> Data {
        guard let endpoint = Secrets.kaiGuideImageBackendURL else { throw CustomGuideImageError.notConfigured }
        guard (reference?.count ?? 0) <= 1_500_000 else { throw CustomGuideImageError.referenceTooLarge }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 180
        configuration.timeoutIntervalForResource = 210
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("image/png", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(Request(description: description, referenceImage: reference))
        for attempt in 0...1 {
            do { try await AppAttestAuthManager.shared.authorize(&request) }
            catch { throw CustomGuideImageError.authentication }
            let data: Data
            let response: URLResponse
            do { (data, response) = try await session.data(for: request) }
            catch let error as URLError where error.code == .timedOut { throw CustomGuideImageError.timedOut }
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else { throw CustomGuideImageError.failed }
            if http.statusCode == 401, attempt == 0 {
                // Authorization was rejected before generation; this retry cannot create a second image.
                await AppAttestAuthManager.shared.invalidateCachedToken()
                continue
            }
            guard http.statusCode == 200 else {
                let code = (try? JSONDecoder().decode(Failure.self, from: data))?.code
                switch code {
                case "moderation_blocked": throw CustomGuideImageError.blocked
                case "generation_timeout": throw CustomGuideImageError.timedOut
                case "model_unavailable", "service_unavailable": throw CustomGuideImageError.unavailable
                case "invalid_image": throw CustomGuideImageError.invalidImage
                default:
                    if http.statusCode == 401 || http.statusCode == 403 { throw CustomGuideImageError.authentication }
                    if http.statusCode == 429 || http.statusCode == 409 { throw CustomGuideImageError.rateLimited }
                    throw CustomGuideImageError.failed
                }
            }
            guard http.mimeType == "image/png" else { throw CustomGuideImageError.invalidImage }
            try await Task.detached(priority: .userInitiated) { try validateImage(data) }.value
            return data
        }
        throw CustomGuideImageError.authentication
    }

    nonisolated static func validateImage(_ data: Data) throws {
        guard data.count <= 4_000_000, data.starts(with: [137,80,78,71,13,10,26,10]),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width == 1024, image.height == 1024 else { throw CustomGuideImageError.invalidImage }
        // Check actual alpha rather than accepting a painted checkerboard or opaque PNG.
        var pixels = [UInt8](repeating: 0, count: 64 * 64 * 4)
        let valid = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: 64, height: 64, bitsPerComponent: 8,
                bytesPerRow: 64 * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 64))
            let values = bytes.bindMemory(to: UInt8.self)
            let alpha = stride(from: 3, to: values.count, by: 4).map { values[$0] }
            return alpha.contains(where: { $0 < 10 }) && alpha.contains(where: { $0 > 240 })
        }
        guard valid else { throw CustomGuideImageError.invalidImage }
    }
}
