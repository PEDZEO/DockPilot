//
//  DockPilotApp.swift
//  DockPilot
//
//

import SwiftUI
import SwiftData
import AppKit

@main
struct DockPilotApp: App {
    // Use @State to avoid unintended reinitialization and to keep a single stable instance
    @State private var container: ModelContainer

    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var updateChecker = UpdateChecker.shared
    @State private var isInitialized = false
    @State private var showUpdateWindow = false

    init() {
        // Build schema & local-only configuration
        let schema = Schema([
            Profile.self,
            DockItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let c = try ModelContainer(for: schema, configurations: [modelConfiguration])
            _container = State(initialValue: c)
            print("✅ ModelContainer initialized successfully")
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            if isInitialized {
                ContentView()
                    .environmentObject(appSettings)
                    .environmentObject(updateChecker)
                    .sheet(isPresented: $showUpdateWindow) {
                        UpdateNotificationView(updateChecker: updateChecker)
                    }
                    .onChange(of: updateChecker.isUpdateAvailable) { _, isAvailable in
                        if isAvailable {
                            showUpdateWindow = true
                        }
                    }
            } else {
                ProgressView("Initializing DockPilot...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        await initializeApp()
                    }
            }
        }
        // Attach the container ONCE at the scene level
        .modelContainer(container)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }

        Settings {
            SettingsView(appSettings: appSettings)
        }
        .modelContainer(container)

        MenuBarExtra("DockPilot", systemImage: "dock.rectangle") {
            if isInitialized {
                MenuBarView()
                    .environmentObject(appSettings)
                    .environmentObject(updateChecker)
            } else {
                Text("Initializing...")
                    .foregroundColor(.secondary)
            }
        }
        // Attach the SAME container to the menu bar scene
        .modelContainer(container)
        .menuBarExtraStyle(.menu)
    }

    // MARK: - First Launch Initialization

    @MainActor
    private func initializeApp() async {
        let context = container.mainContext
        let stateManager = DockStateManager()
        stateManager.attach(context: context)

        // Safer first-launch flow: only create defaults if the store is truly empty
        do {
            try await stateManager.ensureInitialData()
        } catch {
            print("Error during ensureInitialData(): \(error)")
            // Continue anyway - user can create profiles manually
        }

        isInitialized = true

        GlobalHotKeyManager.shared.registerProfileShortcuts { slot in
            Task { @MainActor in
                await applyProfileFromHotKey(slot: slot, context: context)
            }
        }

        // Check for updates on app launch (silent check)
        Task {
            await updateChecker.checkForUpdates(silent: true)
        }
    }

    @MainActor
    private func applyProfileFromHotKey(slot: Int, context: ModelContext) async {
        do {
            let descriptor = FetchDescriptor<Profile>(
                sortBy: [
                    SortDescriptor(\Profile.sortOrder),
                    SortDescriptor(\Profile.creationDate),
                ]
            )
            let profiles = try context.fetch(descriptor).filter { !$0.isDefault }

            guard profiles.indices.contains(slot - 1) else {
                NSSound.beep()
                return
            }

            let profile = profiles[slot - 1]
            let stateManager = DockStateManager(context: context)
            try await stateManager.applyProfile(profile)
            print("✅ Applied profile '\(profile.name)' with ⌥\(slot)")
        } catch {
            print("❌ Failed to apply profile from hot key: \(error.localizedDescription)")
            NSSound.beep()
        }
    }
}
