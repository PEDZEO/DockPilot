//
//  AppLocalization.swift
//  DockPilot
//

import Foundation

enum AppLocalization {
    static var selectedLocale: Locale {
        let stored = UserDefaults.standard.string(forKey: "DockPilot_Language")
        return (AppLanguage(rawValue: stored ?? "") ?? .system).locale
    }

    static func string(
        _ key: String,
        locale: Locale = selectedLocale,
        _ arguments: CVarArg...
    ) -> String {
        let languageCode = locale.identifier.lowercased().hasPrefix("ru") ? "ru" : "en"
        let localizedBundle: Bundle

        if let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            localizedBundle = bundle
        } else {
            localizedBundle = .main
        }

        let format = localizedBundle.localizedString(forKey: key, value: key, table: nil)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }
}
