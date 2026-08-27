//
//  MenuBarView.swift
//  DockPilot
//
//

import SwiftUI
import SwiftData
import AppKit

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.locale) private var locale
    @EnvironmentObject private var updateChecker: UpdateChecker
    @StateObject private var shortcutPreferences = ShortcutPreferences.shared
    @Query(sort: [
        SortDescriptor(\Profile.sortOrder),
        SortDescriptor(\Profile.creationDate),
    ]) private var profiles: [Profile]
    
    @StateObject private var dockStateManager: DockStateManager
    @State private var isApplying = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    init() {
        _dockStateManager = StateObject(wrappedValue: DockStateManager())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Profile list
            if profiles.isEmpty {
                Text("No profiles")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(profiles.enumerated()), id: \.element.id) { _, profile in
                    Button(action: {
                        Task {
                            await applyProfile(profile)
                        }
                    }) {
                        HStack {
                            Text(profile.name)
                            
                            if profile.isDefault {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                            
                            Spacer()

                            let shortcut = shortcutPreferences.shortcut(for: profile.id)
                            if shortcut != .disabled {
                                Text(shortcut.label)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            
                            if profile.id == dockStateManager.currentProfileID {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                            }
                            
                            if isApplying && profile.id == dockStateManager.currentProfileID {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .disabled(isApplying)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Open window button
            Button("Open DockPilot") {
                activateApp()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Settings link
            SettingsLink {
                Text("Settings...")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Check for updates
            Button(action: {
                Task {
                    await checkForUpdates()
                }
            }) {
                HStack {
                    Text("Check for Updates")
                    if updateChecker.isChecking {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .disabled(updateChecker.isChecking)
            
            Divider()
                .padding(.vertical, 4)
            
            // Quit button
            Button("Quit DockPilot") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .padding(.vertical, 4)
        .onAppear {
            dockStateManager.attach(context: modelContext)
        }
        .alert("Error", isPresented: $showingError, presenting: errorMessage) { _ in
            Button("OK") {
                errorMessage = nil
            }
        } message: { message in
            Text(message)
        }
    }
    
    private func checkForUpdates() async {
        // This will trigger the main sheet if update is available
        await updateChecker.checkForUpdates(silent: false, notify: true)
        
        // If no update is available after a manual check, show confirmation
        if !updateChecker.isUpdateAvailable {
            await MainActor.run {
                errorMessage = AppLocalization.string(
                    "You're running the latest version (%@)",
                    locale: locale,
                    updateChecker.currentVersion
                )
                showingError = true
            }
        }
    }
    
    private func applyProfile(_ profile: Profile) async {
        await MainActor.run {
            isApplying = true
        }
        
        do {
            try await dockStateManager.applyProfile(profile)
            print("✅ Applied profile '\(profile.name)' from menu bar")
        } catch {
            await MainActor.run {
                errorMessage = AppLocalization.string(
                    "Failed to apply profile: %@",
                    locale: locale,
                    error.localizedDescription
                )
                showingError = true
            }
        }
        
        await MainActor.run {
            isApplying = false
        }
    }
    
    private func activateApp() {
        // Find the main window
        let mainWindow = NSApplication.shared.windows.first { window in
            window.canBecomeMain
        }
        
        if let window = mainWindow {
            // Window exists (visible or hidden) - bring it to front
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            // No window exists at all - create one
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

}
