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

    @Test
    func parserExcludesRecentAppsByDefault() {
        let output = """
        Safari\tfile:///System/Applications/Safari.app/\tpersistentApps\t/test.plist\tcom.apple.Safari
        Spotify\tfile:///Applications/Spotify.app/\trecentApps\t/test.plist\tcom.spotify.client
        Downloads\tfile:///Users/test/Downloads/\tpersistentOthers\t/test.plist\t
        """

        let items = DockOutputParser().parse(output)

        #expect(items.map(\.name) == ["Safari", "Downloads"])
        #expect(items.allSatisfy { !$0.isRecent })
        #expect(items[1].path == "/Users/test/Downloads")
    }

    @Test
    func parserCanIncludeRecentAppsWithoutLoadingIcons() {
        let output = """
        Spotify\tfile:///Applications/Spotify.app/\trecentApps\t/test.plist\tcom.spotify.client
        """

        let items = DockOutputParser().parse(output, includeRecentApps: true)

        #expect(items.count == 1)
        #expect(items[0].isRecent)
        #expect(items[0].section == "apps")
        #expect(items[0].iconData == nil)
    }

    @Test @MainActor
    func verifierAcceptsRunningAppAndIndependentDockSections() {
        let chat = DockItem(type: .app, name: "Chat", path: "/Applications/Chat.app", position: 0)
        let downloads = DockItem(
            type: .folder,
            name: "Downloads",
            path: "/Users/test/Downloads",
            position: 1,
            section: "others"
        )
        let music = DockItem(type: .app, name: "Music", path: "/Applications/Music.app", position: 2)

        let actual = [
            DockItemInfo(
                type: .app,
                name: "Chat",
                path: "/Applications/Chat.app",
                iconData: nil,
                section: "apps",
                isRecent: false
            ),
            DockItemInfo(
                type: .app,
                name: "Music",
                path: "/Applications/Music.app",
                iconData: nil,
                section: "apps",
                isRecent: true
            ),
            DockItemInfo(
                type: .folder,
                name: "Downloads",
                path: "/Users/test/Downloads",
                iconData: nil,
                section: "others",
                isRecent: false
            ),
        ]

        #expect(DockProfileVerifier.matches(expected: [chat, downloads, music], actual: actual))
    }

    @Test @MainActor
    func verifierRejectsUnexpectedPersistentItem() {
        let chat = DockItem(type: .app, name: "Chat", path: "/Applications/Chat.app", position: 0)
        let actual = [
            DockItemInfo(
                type: .app,
                name: "Chat",
                path: "/Applications/Chat.app",
                iconData: nil,
                section: "apps",
                isRecent: false
            ),
            DockItemInfo(
                type: .app,
                name: "Unexpected",
                path: "/Applications/Unexpected.app",
                iconData: nil,
                section: "apps",
                isRecent: false
            ),
        ]

        #expect(!DockProfileVerifier.matches(expected: [chat], actual: actual))
    }

    @Test
    func systemAppsLauncherIsAlwaysProtected() {
        #expect(DockSystemItemPolicy.isSystemManaged(path: "/System/Applications/Apps.app"))
        #expect(DockSystemItemPolicy.isSystemManaged(path: "/System/Applications/Apps.app/"))
        #expect(!DockSystemItemPolicy.isSystemManaged(path: "/System/Applications/Mail.app"))
    }

}
