import Foundation

enum AppLocalization {
    enum LanguageOption: String, CaseIterable, Identifiable {
        case system
        case english
        case swedish

        var id: String { rawValue }

        var localeIdentifier: String? {
            switch self {
            case .system:
                return nil
            case .english:
                return "en"
            case .swedish:
                return "sv"
            }
        }
    }

    private static let languageOverrideKey = "app.language.override"

    static var selectedLanguageOption: LanguageOption {
        let raw = UserDefaults.standard.string(forKey: languageOverrideKey) ?? LanguageOption.system.rawValue
        return LanguageOption(rawValue: raw) ?? .system
    }

    static var selectedLanguageRawValue: String {
        selectedLanguageOption.rawValue
    }

    static var currentLocale: Locale {
        Locale(identifier: currentLocaleIdentifier)
    }

    static var currentLocaleIdentifier: String {
        if let overrideLocale = selectedLanguageOption.localeIdentifier {
            return overrideLocale
        }
        if let preferred = Locale.preferredLanguages.first, !preferred.isEmpty {
            return preferred
        }
        return Locale.current.identifier
    }

    static var preferredLanguageCodes: [String] {
        var codes: [String] = []

        if let overrideLocale = selectedLanguageOption.localeIdentifier {
            let code = Locale(identifier: overrideLocale).language.languageCode?.identifier.lowercased()
            if let code, !code.isEmpty {
                codes.append(code)
            }
        } else {
            let preferredCodes = Locale.preferredLanguages.compactMap {
                Locale(identifier: $0).language.languageCode?.identifier.lowercased()
            }
            codes.append(contentsOf: preferredCodes)
        }

        if !codes.contains("en") {
            codes.append("en")
        }

        return Array(Set(codes))
    }

    static func applyLanguageOverride(rawValue: String) {
        let option = LanguageOption(rawValue: rawValue) ?? .system
        UserDefaults.standard.set(option.rawValue, forKey: languageOverrideKey)
        applyAppleLanguages(option)
    }

    static func applyLanguageOverrideOnLaunch() {
        applyAppleLanguages(selectedLanguageOption)
    }

    static func locale(forRawValue rawValue: String) -> Locale {
        let option = LanguageOption(rawValue: rawValue) ?? .system
        if let localeIdentifier = option.localeIdentifier {
            return Locale(identifier: localeIdentifier)
        }
        return Locale(identifier: currentLocaleIdentifier)
    }

    private static func applyAppleLanguages(_ option: LanguageOption) {
        if let localeIdentifier = option.localeIdentifier {
            UserDefaults.standard.set([localeIdentifier], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
}
