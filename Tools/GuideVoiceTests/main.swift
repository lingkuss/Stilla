import Foundation

@main struct GuideCatalogChecks {
    static func main() throws {
        precondition(KaiPersonality.builtIn.map(\.id) == ["zen_minimalist", "serene_guide", "shadow_guide", "ra"])
        precondition(Array(KaiPersonality.all.prefix(4)) == KaiPersonality.builtIn)
        precondition(Set(KaiPersonality.all.map(\.id)).count == KaiPersonality.all.count)
        // Retired identities remain readable in saved sessions, without reappearing in selection.
        for guide in [KaiPersonality.cosmicSage, .warmGuardian, .modernRealist, .reflectiveAnalyst, .philosopher] {
            precondition(!KaiPersonality.all.contains(guide))
            let restored = try JSONDecoder().decode(KaiPersonality.self, from: JSONEncoder().encode(guide))
            precondition(KaiPersonality.personality(for: restored.id) == guide)
        }
        precondition(KaiPersonality.personality(for: "unknown") == .default)
        print("PASS: four ordered built-in guides, appended custom guides, unique identities, archived identities and unknown-ID fallback")
    }
}
