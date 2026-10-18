import Foundation

/// UI language. `system` follows the Mac's language order; anything Ticker has no translation
/// for falls back to English (the development language, used as the localization keys).
///
/// Translations live in `Resources/Localization/<code>.lproj/Localizable.strings`.
/// SwiftUI looks strings up with the `locale` environment value, so switching is live.
enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case system, en, de, fr, es, it, ja, zhHans = "zh-Hans"

    var id: String { rawValue }

    static let supportedCodes = ["en", "de", "fr", "es", "it", "ja", "zh-Hans"]

    /// Name of the language in that language (not translated on purpose).
    var nativeName: String {
        switch self {
        case .system: AppLanguage(rawValue: Self.systemCode)?.nativeName ?? "English"
        case .en: "English"
        case .de: "Deutsch"
        case .fr: "Français"
        case .es: "Español"
        case .it: "Italiano"
        case .ja: "日本語"
        case .zhHans: "简体中文"
        }
    }

    /// The language code actually used for the UI.
    var resolvedCode: String { self == .system ? Self.systemCode : rawValue }

    var locale: Locale { Locale(identifier: resolvedCode) }

    /// Best supported match for the user's *global* language list. Read from the global domain
    /// because the app's own `AppleLanguages` may be overridden by the in-app choice.
    static var systemCode: String {
        let global = CFPreferencesCopyValue("AppleLanguages" as CFString, kCFPreferencesAnyApplication,
                                            kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String]
        let preferred = global ?? Locale.preferredLanguages
        return Bundle.preferredLocalizations(from: supportedCodes, forPreferences: preferred).first ?? "en"
    }

    /// Also pin `AppleLanguages` for the app, so strings resolved outside SwiftUI (window titles,
    /// `String(localized:)`) match after the next launch.
    func persistForBundle() {
        if self == .system {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        }
    }
}
