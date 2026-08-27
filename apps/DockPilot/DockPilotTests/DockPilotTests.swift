//
//  DockPilotTests.swift
//  DockPilotTests
//
//

import Testing
import Foundation
@testable import DockPilot

struct DockPilotTests {

    @Test @MainActor
    func assigningAnOccupiedShortcutMovesItToTheNewProfile() {
        let suiteName = "DockPilotTests.Shortcuts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preferences = ShortcutPreferences(defaults: defaults)
        let firstProfileID = UUID()
        let secondProfileID = UUID()

        preferences.assign(.option1, to: firstProfileID)
        preferences.assign(.option1, to: secondProfileID)

        #expect(preferences.shortcut(for: firstProfileID) == .disabled)
        #expect(preferences.shortcut(for: secondProfileID) == .option1)
        #expect(preferences.profileID(for: 1) == secondProfileID)
    }

}
