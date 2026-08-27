//
//  ProfileShortcutCoordinator.swift
//  DockPilot
//

import AppKit
import Combine
import SwiftData

@MainActor
final class ProfileShortcutCoordinator {
    static let shared = ProfileShortcutCoordinator()

    private let preferences = ShortcutPreferences.shared
    private let dockStateManager = DockStateManager.shared
    private var modelContext: ModelContext?
    private var activeSlot: Int?
    private var pendingSlot: Int?
    private var cancellables = Set<AnyCancellable>()

    private init() {}

    func start(context: ModelContext) {
        modelContext = context
        dockStateManager.attach(context: context)

        do {
            preferences.ensureDefaultAssignments(for: try fetchProfiles(context: context))
        } catch {
            print("Failed to initialize shortcut assignments: \(error.localizedDescription)")
        }

        preferences.$assignments
            .map { Set($0.values.map(\.rawValue)) }
            .removeDuplicates()
            .sink { [weak self] slots in
                self?.registerShortcuts(slots: slots)
            }
            .store(in: &cancellables)
    }

    private func registerShortcuts(slots: Set<Int>) {
        GlobalHotKeyManager.shared.registerProfileShortcuts(slots: slots) { [weak self] slot in
            Task { @MainActor in
                await self?.applyProfile(assignedTo: slot)
            }
        }
    }

    private func applyProfile(assignedTo slot: Int) async {
        if activeSlot != nil {
            if slot != activeSlot {
                pendingSlot = slot
            }
            return
        }

        activeSlot = slot
        defer {
            activeSlot = nil
            if let pendingSlot {
                self.pendingSlot = nil
                Task { @MainActor [weak self] in
                    await self?.applyProfile(assignedTo: pendingSlot)
                }
            }
        }

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
