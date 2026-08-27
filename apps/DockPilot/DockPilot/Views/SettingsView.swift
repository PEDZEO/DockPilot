//
//  SettingsView.swift
//  DockPilot
//
//  Settings window for app preferences
//

import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var appSettings: AppSettings
    @StateObject private var updateChecker = UpdateChecker.shared
    @StateObject private var shortcutPreferences = ShortcutPreferences.shared
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Query(sort: [
        SortDescriptor(\Profile.sortOrder),
        SortDescriptor(\Profile.creationDate),
    ]) private var profiles: [Profile]
    
    @State private var showingUpdateResult = false
    @State private var updateMessage = ""
    @State private var localUpdateAvailable = false
    
    @State private var isProcessingBackup = false
    @State private var showingBackupResult = false
    @State private var backupResultTitle = "Backup"
    @State private var backupResultMessage = ""
    @State private var pendingImportURL: URL?
    @State private var showingImportConfirmation = false
    
    var body: some View {
        Form {
            LanguageSettingsSection(appSettings: appSettings)

            Section {
                Toggle("Launch at Login", isOn: $appSettings.launchAtLogin)
                
                Text("Automatically start DockPilot when you log in to your Mac.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } header: {
                Text("General")
            }
            
            Section {
                Toggle("Show in Dock", isOn: $appSettings.showInDock)
                
                Text("When disabled, DockPilot will only appear in the menu bar. You can still access the main window from the menu bar icon.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } header: {
                Text("Appearance")
            }

            ShortcutSettingsSection(
                profiles: profiles,
                preferences: shortcutPreferences
            )
            
            Section {
                HStack {
                    Text("Current Version:")
                        .foregroundColor(.secondary)
                    Text(updateChecker.currentVersion)
                        .fontWeight(.medium)
                }
                
                if let lastCheck = updateChecker.lastCheckDate {
                    HStack {
                        Text("Last Check:")
                            .foregroundColor(.secondary)
                        Text(lastCheck, style: .relative)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button(action: {
                    Task {
                        await checkForUpdates()
                    }
                }) {
                    HStack {
                        Text("Check for Updates")
                        if updateChecker.isChecking {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
                .disabled(updateChecker.isChecking)
                
                Text("DockPilot will automatically check for updates when launched.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } header: {
                Text("Updates")
            }
            
            Section {
                Button(action: exportBackup) {
                    HStack {
                        Text("Export Backup…")
                        if isProcessingBackup {
                            Spacer()
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                }
                .disabled(isProcessingBackup)
                
                Button(action: startImportFlow) {
                    Text("Import Backup…")
                }
                .disabled(isProcessingBackup)
                
                Text("Create a JSON backup of all profiles or restore from a previous backup. Importing replaces your existing profiles.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            } header: {
                Text("Backup & Restore")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 620)
        .navigationTitle("Settings")
        .alert("Import Backup", isPresented: $showingImportConfirmation, presenting: pendingImportURL) { url in
            Button("Cancel", role: .cancel) {
                pendingImportURL = nil
            }
            Button("Import", role: .destructive) {
                pendingImportURL = nil
                Task {
                    await importBackup(from: url)
                }
            }
        } message: { _ in
            Text("This will delete your current profiles and replace them with the contents of the backup.")
        }
        .alert(backupResultTitle, isPresented: $showingBackupResult) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(backupResultMessage)
        }
        .alert("Update Check", isPresented: $showingUpdateResult) {
            if localUpdateAvailable {
                Button("Download") {
                    updateChecker.openReleasePage()
                }
                Button("Later", role: .cancel) { }
            } else {
                Button("OK", role: .cancel) { }
            }
        } message: {
            Text(updateMessage)
        }
    }
    
    private func checkForUpdates() async {
        // Check without triggering the global notification sheet
        await updateChecker.checkForUpdates(silent: false, notify: false)
        
        await MainActor.run {
            let hasUpdate = updateChecker.compareVersions(
                current: updateChecker.currentVersion, 
                latest: updateChecker.latestVersion
            )
            
            localUpdateAvailable = hasUpdate
            
            if hasUpdate {
                updateMessage = AppLocalization.string(
                    "Version %@ is available!",
                    locale: locale,
                    updateChecker.latestVersion
                )
            } else {
                updateMessage = AppLocalization.string("You're running the latest version.", locale: locale)
            }
            showingUpdateResult = true
        }
    }
    
    private func exportBackup() {
        guard let url = presentSavePanel() else { return }
        Task { await performExport(to: url) }
    }
    
    private func startImportFlow() {
        guard let url = presentOpenPanel() else { return }
        pendingImportURL = url
        showingImportConfirmation = true
    }
    
    @MainActor
    private func performExport(to url: URL) async {
        isProcessingBackup = true
        defer { isProcessingBackup = false }
        
        do {
            try BackupService.shared.exportBackup(to: url, using: modelContext)
            backupResultTitle = AppLocalization.string("Backup Saved", locale: locale)
            backupResultMessage = AppLocalization.string(
                "Profiles were saved to %@.",
                locale: locale,
                url.lastPathComponent
            )
        } catch {
            backupResultTitle = AppLocalization.string("Backup Failed", locale: locale)
            backupResultMessage = error.localizedDescription
        }
        
        showingBackupResult = true
    }
    
    @MainActor
    private func importBackup(from url: URL) async {
        isProcessingBackup = true
        defer { isProcessingBackup = false }
        
        do {
            let restored = try BackupService.shared.importBackup(from: url, using: modelContext)
            backupResultTitle = AppLocalization.string("Backup Restored", locale: locale)
            backupResultMessage = AppLocalization.string("Imported %d profiles.", locale: locale, restored)
        } catch {
            backupResultTitle = AppLocalization.string("Import Failed", locale: locale)
            backupResultMessage = error.localizedDescription
        }
        
        showingBackupResult = true
    }
    
    private func presentSavePanel() -> URL? {
        let panel = NSSavePanel()
        panel.title = AppLocalization.string("Export DockPilot Backup", locale: locale)
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = defaultBackupFileName()
        return panel.runModal() == .OK ? panel.url : nil
    }
    
    private func presentOpenPanel() -> URL? {
        let panel = NSOpenPanel()
        panel.title = AppLocalization.string("Import DockPilot Backup", locale: locale)
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }
    
    private func defaultBackupFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return AppLocalization.string(
            "DockPilot Backup %@.json",
            locale: locale,
            formatter.string(from: Date())
        )
    }
}

#Preview {
    SettingsView(appSettings: AppSettings.shared)
}
