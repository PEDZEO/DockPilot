//
//  LanguageSettingsSection.swift
//  DockPilot
//

import SwiftUI

struct LanguageSettingsSection: View {
    @ObservedObject var appSettings: AppSettings

    var body: some View {
        Section {
            Picker("Application Language", selection: $appSettings.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(LocalizedStringKey(language.title))
                        .tag(language)
                }
            }

            Text("The interface language changes immediately. System Default follows your macOS language.")
                .font(.caption)
                .foregroundColor(.secondary)
        } header: {
            Text("Language")
        }
    }
}
