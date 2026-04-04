import Foundation

struct ShareSessionPayload: Codable {
    let version: Int
    let script: MeditationScript

    init(version: Int = 1, script: MeditationScript) {
        self.version = version
        self.script = script
    }
}

enum ShareSessionCodec {
    static func encode(_ payload: ShareSessionPayload) -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(payload) else { return nil }
        return base64URLEncode(data)
    }

    static func decode(_ encoded: String) -> ShareSessionPayload? {
        guard let data = base64URLDecode(encoded) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(ShareSessionPayload.self, from: data)
    }

    private static func base64URLEncode(_ data: Data) -> String {
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - (base64.count % 4)
        if padding < 4 {
            base64 += String(repeating: "=", count: padding)
        }
        return Data(base64Encoded: base64)
    }
}
