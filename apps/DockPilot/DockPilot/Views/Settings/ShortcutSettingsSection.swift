//
//  ShortcutSettingsSection.swift
//  DockPilot
//

import SwiftUI

struct ShortcutSettingsSection: View {
    let profiles: [Profile]
    @ObservedObject var preferences: ShortcutPreferences

    private var eligibleProfiles: [Profile] {
        profiles.filter { !$0.isDefault }
    }

    var body: some View {
        Section {
            if eligibleProfiles.isEmpty {
                Text("Create a non-default profile to enable a shortcut.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(eligibleProfiles) { profile in
                    HStack {
                        Text(profile.name)
                        Spacer()
                        Picker("Shortcut", selection: binding(for: profile)) {
                            ForEach(ProfileShortcut.allCases) { shortcut in
                                Text(LocalizedStringKey(shortcut.label))
                                    .tag(shortcut)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 100)
                    }
                }
            }

            Text("Assign a unique shortcut to each profile. Reusing a shortcut moves it to the selected profile.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        } header: {
            Text("Global Shortcuts")
        }
    }

    private func binding(for profile: Profile) -> Binding<ProfileShortcut> {
        Binding(
            get: { preferences.shortcut(for: profile.id) },
            set: { preferences.assign($0, to: profile.id) }
        )
    }
}
