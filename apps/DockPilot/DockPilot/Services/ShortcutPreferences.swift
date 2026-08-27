//
//  ShortcutPreferences.swift
//  DockPilot
//

import Foundation
import Combine

@MainActor
final class ShortcutPreferences: ObservableObject {
    static let shared = ShortcutPreferences()

    private let assignmentsKey = "DockPilot_ProfileShortcuts"
    private let didCreateDefaultsKey = "DockPilot_DidCreateDefaultShortcuts"
    private let defaults: UserDefaults

    @Published private(set) var assignments: [UUID: ProfileShortcut]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.dictionary(forKey: assignmentsKey) as? [String: Int] ?? [:]
        assignments = stored.reduce(into: [:]) { result, entry in
            guard let profileID = UUID(uuidString: entry.key),
                  let shortcut = ProfileShortcut(rawValue: entry.value),
                  shortcut != .disabled else {
                return
            }
            result[profileID] = shortcut
        }
    }

    func shortcut(for profileID: UUID) -> ProfileShortcut {
        assignments[profileID] ?? .disabled
    }

    func profileID(for slot: Int) -> UUID? {
        guard let shortcut = ProfileShortcut(rawValue: slot) else { return nil }
        return assignments.first(where: { $0.value == shortcut })?.key
    }

    func assign(_ shortcut: ProfileShortcut, to profileID: UUID) {
        assignments = assignments.filter { existingProfileID, existingShortcut in
            existingProfileID != profileID && existingShortcut != shortcut
        }

        if shortcut != .disabled {
            assignments[profileID] = shortcut
        }
        persist()
    }

    func ensureDefaultAssignments(for profiles: [Profile]) {
        guard !defaults.bool(forKey: didCreateDefaultsKey) else {
            removeOrphanedAssignments(validProfileIDs: Set(profiles.map(\.id)))
            return
        }

        let eligibleProfiles = profiles.filter { !$0.isDefault }.prefix(9)
        for (index, profile) in eligibleProfiles.enumerated() {
            guard let shortcut = ProfileShortcut(rawValue: index + 1) else { continue }
            assignments[profile.id] = shortcut
        }

        defaults.set(true, forKey: didCreateDefaultsKey)
        persist()
    }

    func removeAssignment(for profileID: UUID) {
        assignments.removeValue(forKey: profileID)
        persist()
    }

    private func removeOrphanedAssignments(validProfileIDs: Set<UUID>) {
        let filtered = assignments.filter { validProfileIDs.contains($0.key) }
        guard filtered != assignments else { return }
        assignments = filtered
        persist()
    }

    private func persist() {
        let stored = Dictionary(uniqueKeysWithValues: assignments.map { profileID, shortcut in
            (profileID.uuidString, shortcut.rawValue)
        })
        defaults.set(stored, forKey: assignmentsKey)
    }
}
