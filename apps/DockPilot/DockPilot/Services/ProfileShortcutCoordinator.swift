//
//  ProfileShortcutCoordinator.swift
//  DockPilot
//

import AppKit
import SwiftData

@MainActor
final class ProfileShortcutCoordinator {
    static let shared = ProfileShortcutCoordinator()

    private let preferences = ShortcutPreferences.shared
    private let dockStateManager = DockStateManager()
    private var modelContext: ModelContext?

    private init() {}

    func start(context: ModelContext) {
        modelContext = context
        dockStateManager.attach(context: context)

        do {
            preferences.ensureDefaultAssignments(for: try fetchProfiles(context: context))
        } catch {
            print("Failed to initialize shortcut assignments: \(error.localizedDescription)")
        }

        GlobalHotKeyManager.shared.registerProfileShortcuts { [weak self] slot in
            Task { @MainActor in
                await self?.applyProfile(assignedTo: slot)
            }
        }
    }

    private func applyProfile(assignedTo slot: Int) async {
        guard let modelContext,
              let profileID = preferences.profileID(for: slot) else {
            NSSound.beep()
            return
        }

        do {
            let profiles = try fetchProfiles(context: modelContext)
            guard let profile = profiles.first(where: { $0.id == profileID }) else {
                preferences.removeAssignment(for: profileID)
                NSSound.beep()
                return
            }

            try await dockStateManager.applyProfile(profile)
            print("✅ Applied profile '\(profile.name)' with ⌥\(slot)")
        } catch {
            print("❌ Failed to apply profile from shortcut: \(error.localizedDescription)")
            NSSound.beep()
        }
    }

    private func fetchProfiles(context: ModelContext) throws -> [Profile] {
        let descriptor = FetchDescriptor<Profile>(
            sortBy: [
                SortDescriptor(\Profile.sortOrder),
                SortDescriptor(\Profile.creationDate),
            ]
        )
        return try context.fetch(descriptor)
    }
}
