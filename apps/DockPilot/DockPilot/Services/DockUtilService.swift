//
//  DockUtilService.swift
//  DockPilot
//
//

import Foundation
import AppKit

enum DockUtilError: Error, LocalizedError {
    case dockutilNotFound
    case commandFailed(String)
    case parsingFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .dockutilNotFound:
            return AppLocalization.string("dockutil is not installed. Please install it with: brew install dockutil")
        case .commandFailed(let message):
            return AppLocalization.string("Dock command failed: %@", message)
        case .parsingFailed:
            return AppLocalization.string("Failed to read Dock configuration")
        case .permissionDenied:
            return AppLocalization.string("Permission denied. Please grant necessary permissions in System Settings.")
        }
    }
}

struct DockItemInfo {
    let type: DockItemType
    let name: String
    let path: String
    let iconData: Data?
    let section: String // "apps" or "others"
}

class DockUtilService {
    static let shared = DockUtilService()

    /// Apps.app is not a normal application tile on macOS 26. Its Dock entry
    /// contains private launcher metadata which dockutil cannot recreate.
    private static let systemManagedPaths: Set<String> = [
        "/System/Applications/Apps.app",
    ]
    
    private var dockutilPath: String?
    
    private init() {}
    
    // MARK: - Read Dock State
    
    /// Reads the current Dock configuration and returns an array of DockItemInfo
    func readCurrentDock() async throws -> [DockItemInfo] {
        print("🔍 Checking for dockutil...")
        
        // Check if dockutil is available
        guard await isDockutilAvailable() else {
            print("❌ dockutil not found!")
            throw DockUtilError.dockutilNotFound
        }
        
        print("✅ dockutil found, reading Dock...")
        let output = try await runDockutilCommand(["--list"])
        let items = try parseDockutilOutput(output).filter { !isSystemManaged($0.path) }
        print("📊 Read \(items.count) items from Dock")
        return items
    }
    
    // MARK: - Apply Profile to Dock
    
    /// Applies a profile to the Dock by clearing current items and adding profile items
    func applyProfile(items: [DockItem]) async throws {
        // Ensure dockutil is available before attempting to apply
        guard await isDockutilAvailable() else {
            print("❌ dockutil not found when trying to apply profile!")
            throw DockUtilError.dockutilNotFound
        }
        
        let validItems = items.filter { item in
            guard !isSystemManaged(item.path) else {
                print("🛡️ Preserving system-managed Dock item: \(item.path)")
                return false
            }

            switch item.type {
            case .app, .folder:
                let ok = FileManager.default.fileExists(atPath: item.path)
                if !ok { print("🚫 Skipping missing \(item.type) '\(item.name)' at \(item.path)") }
                return ok
            case .url, .spacer:
                return true
            }
        }
        
        if validItems.count != items.count {
            print("⚠️ Some items were skipped due to invalid paths. Proceeding with \(validItems.count) valid items…")
        }
        
        // Sort items by position
        let sortedItems = validItems.sorted(by: { $0.position < $1.position })

        // macOS can occasionally retain a stale Dock preferences snapshot. Verify the
        // exact result and retry the complete atomic batch once when that happens.
        for attempt in 1...2 {
            try await clearDock()

            for (index, item) in sortedItems.enumerated() {
                print("  [\(index + 1)/\(validItems.count)] Adding \(item.name)...")
                try await addItemToDock(item, noRestart: true)
            }

            print("🔄 Restarting Dock to commit batch (attempt \(attempt))...")
            try await restartDock()
            try await Task.sleep(nanoseconds: 650_000_000)

            let currentItems = try await readCurrentDock()
            if profileMatches(expected: sortedItems, actual: currentItems) {
                print("✅ Profile applied and verified on attempt \(attempt)")
                return
            }

            print("⚠️ Dock contents did not match the profile after attempt \(attempt)")
        }

        throw DockUtilError.commandFailed(
            AppLocalization.string("Dock did not retain the selected profile")
        )
    }

    private func profileMatches(expected: [DockItem], actual: [DockItemInfo]) -> Bool {
        let expectedItems = expected.filter { $0.type != .spacer }
        guard expectedItems.count == actual.count else { return false }

        // Dock stores the apps and others sections independently. A folder may
        // have a lower global position than a later app in an imported profile,
        // but dockutil always lists every app before every folder. Compare order
        // inside each section instead of treating both sections as one list.
        return ["apps", "others"].allSatisfy { section in
            let expectedSection = expectedItems.filter { $0.section == section }
            let actualSection = actual.filter { $0.section == section }
            guard expectedSection.count == actualSection.count else { return false }

            return zip(expectedSection, actualSection).allSatisfy { expectedItem, actualItem in
                itemsMatch(expected: expectedItem, actual: actualItem)
            }
        }
    }

    private func itemsMatch(expected expectedItem: DockItem, actual actualItem: DockItemInfo) -> Bool {
        guard expectedItem.type == actualItem.type else { return false }

        switch expectedItem.type {
        case .app, .folder:
            return URL(fileURLWithPath: expectedItem.path).standardizedFileURL.path
                == URL(fileURLWithPath: actualItem.path).standardizedFileURL.path
        case .url:
            return expectedItem.name == actualItem.name && expectedItem.path == actualItem.path
        case .spacer:
            return true
        }
    }
    
    /// Clears all items from the Dock
    private func clearDock() async throws {
        print("🧹 Clearing managed Dock items while preserving system launchers...")
        let output = try await runDockutilCommand(["--list"])
        let currentItems = try parseDockutilOutput(output)

        for item in currentItems where !isSystemManaged(item.path) {
            do {
                _ = try await runDockutilCommand(["--remove", item.path, "--no-restart"])
            } catch {
                // Some URL and localized items can only be addressed by label.
                _ = try await runDockutilCommand(["--remove", item.name, "--no-restart"])
            }
        }

        // Spacers are not included in dockutil --list.
        _ = try? await runDockutilCommand(["--remove", "spacer-tiles", "--no-restart"])
        print("✅ Managed Dock items cleared; system launchers preserved")
    }

    private func isSystemManaged(_ path: String) -> Bool {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return Self.systemManagedPaths.contains(standardizedPath)
    }
    
    /// Wait until Dock responds to dockutil (avoids "connection interrupted" races)
    private func waitForDockReady(timeoutSeconds: Int = 10) async {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        while Date() < deadline {
            do {
                _ = try await runDockutilCommand(["--list"]) // succeeds when Dock is ready
                return
            } catch {
                // Keep waiting
            }
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        }
    }
    
    /// Adds a single item to the Dock
    private func addItemToDock(_ item: DockItem, noRestart: Bool = true) async throws {
        // Validate target exists for app/folder to avoid silent dockutil no-ops
        if item.type == .app || item.type == .folder {
            if !FileManager.default.fileExists(atPath: item.path) {
                print("❌ Path does not exist: \(item.path). Skipping \(item.name)")
                throw DockUtilError.commandFailed("Target path not found: \(item.path)")
            }
        }
        
        var args: [String] = []
        
        switch item.type {
        case .app:
            args = ["--add", item.path, "--section", item.section]
        case .folder:
            args = ["--add", item.path, "--view", "auto", "--display", "folder", "--section", item.section]
        case .url:
            args = ["--add", item.path, "--label", item.name, "--section", item.section]
        case .spacer:
            args = ["--add", "", "--type", "spacer", "--section", item.section]
        }
        
        // Add --no-restart flag if requested
        if noRestart {
            args.append("--no-restart")
        }
        
        _ = try await runDockutilCommand(args)
    }
    
    /// Restarts the Dock to apply changes
    func restartDock() async throws {
        _ = try await runShellCommand("/usr/bin/killall", arguments: ["Dock"])
        // Wait for Dock process to come back online and accept commands
        await waitForDockReady(timeoutSeconds: 12)
    }
    
    /// Check if a Dock item is present (by exact path for apps/folders, by label for URLs)
    private func dockContains(_ item: DockItem) async -> Bool {
        do {
            let output = try await runDockutilCommand(["--list"])        
            let infos = try parseDockutilOutput(output)
            switch item.type {
            case .app, .folder:
                return infos.contains { $0.path == item.path }
            case .url:
                // dockutil --list shows the label in the first column
                return infos.contains { $0.name == item.name }
            case .spacer:
                // spacers are not listed by --list; assume success after add
                return true
            }
        } catch {
            return false
        }
    }
    
    /// Verifies that the Dock plist was recently modified (useful for debugging)
    private func verifyDockPlistModified() {
        let dockPlistPath = "\(NSHomeDirectory())/Library/Preferences/com.apple.dock.plist"
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: dockPlistPath)
            if let modDate = attributes[.modificationDate] as? Date {
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                print("🧾 Dock plist last modified: \(formatter.string(from: modDate))")
                
                // Warn if plist hasn't been modified in the last 5 seconds
                if Date().timeIntervalSince(modDate) > 5 {
                    print("⚠️ Warning: Dock plist modification is stale (>5 seconds ago)")
                }
            }
        } catch {
            print("⚠️ Could not verify Dock plist modification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Icon Extraction
    
    /// Extracts icon data from an app or folder
    private func extractIconData(for path: String, type: DockItemType) -> Data? {
        guard type == .app || type == .folder else {
            return nil
        }
        
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        
        let icon = NSWorkspace.shared.icon(forFile: path)
        
        // Resize icon to a reasonable size (e.g., 64x64 for storage efficiency)
        let targetSize = NSSize(width: 64, height: 64)
        let resizedIcon = NSImage(size: targetSize)
        resizedIcon.lockFocus()
        icon.draw(in: NSRect(origin: .zero, size: targetSize),
                  from: NSRect(origin: .zero, size: icon.size),
                  operation: .copy,
                  fraction: 1.0)
        resizedIcon.unlockFocus()
        
        // Convert to PNG data
        guard let tiffData = resizedIcon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        return pngData
    }
    
    // MARK: - Helper Methods
    
    /// Checks if dockutil is available on the system and caches its path
    private func isDockutilAvailable() async -> Bool {
        // Check common installation paths
        let possiblePaths = [
            "/opt/homebrew/bin/dockutil",  // Apple Silicon Homebrew
            "/usr/local/bin/dockutil",     // Intel Homebrew
            "/usr/bin/dockutil"            // System install
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("✅ Found dockutil at: \(path)")
                dockutilPath = path
                return true
            }
        }
        
        // Fallback: try using 'which'
        do {
            let output = try await runShellCommand("/usr/bin/which", arguments: ["dockutil"])
            let trimmedPath = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPath.isEmpty && FileManager.default.fileExists(atPath: trimmedPath) {
                print("✅ Found dockutil via which: \(trimmedPath)")
                dockutilPath = trimmedPath
                return true
            }
        } catch {
            print("❌ dockutil not found in PATH")
        }
        
        return false
    }
    
    /// Runs a dockutil command and returns output
    private func runDockutilCommand(_ arguments: [String]) async throws -> String {
        guard let dockutilPath else {
            throw DockUtilError.dockutilNotFound
        }
        return try await runShellCommand(dockutilPath, arguments: arguments)
    }
    
    /// Runs a shell command and returns output
    /// Uses /bin/sh as a wrapper to properly handle environment and paths
    private func runShellCommand(_ command: String, arguments: [String]) async throws -> String {
        print("🔧 Executing: \(command) \(arguments.joined(separator: " "))")
        
        // Verify the command file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: command) else {
            print("❌ File does not exist at path: \(command)")
            throw DockUtilError.commandFailed("File does not exist: \(command)")
        }
        
        // Build the full command string for shell execution
        // Escape arguments properly
        let escapedArgs = arguments.map { arg in
            // Escape special shell characters
            let escaped = arg.replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "\"", with: "\\\"")
                            .replacingOccurrences(of: "$", with: "\\$")
                            .replacingOccurrences(of: "`", with: "\\`")
            return "\"\(escaped)\""
        }
        
        let fullCommand = "\(command) \(escapedArgs.joined(separator: " "))"
        print("📝 Shell command: \(fullCommand)")
        
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        // Use /bin/sh to execute the command
        // This handles PATH, environment, and dynamic libraries correctly
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", fullCommand]
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            // Check for errors in stderr even if exit status is 0
            // dockutil sometimes reports "Dock connection error" but still exits successfully
            let hasConnectionError = errorOutput.lowercased().contains("dock connection error") ||
                                    errorOutput.lowercased().contains("connection interrupted")
            
            if process.terminationStatus != 0 {
                print("❌ Process failed with status \(process.terminationStatus): \(errorOutput)")
                throw DockUtilError.commandFailed(errorOutput)
            } else if hasConnectionError {
                print("⚠️ Warning: Dock connection issue detected: \(errorOutput)")
                // Don't throw - these are often transient warnings that don't prevent success
            }
            
            if !errorOutput.isEmpty && !hasConnectionError {
                print("⚠️ Process stderr: \(errorOutput)")
            }
            
            print("✅ Process completed successfully")
            return output
        } catch let error as NSError {
            print("❌ Failed to run process: \(error.localizedDescription) (code: \(error.code))")
            throw DockUtilError.commandFailed("Failed to execute via shell: \(error.localizedDescription)")
        }
    }
    
    /// Parses dockutil --list output into DockItemInfo array
    private func parseDockutilOutput(_ output: String) throws -> [DockItemInfo] {
        var items: [DockItemInfo] = []
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        for line in lines {
            // dockutil --list output format: "Name\tfile://path/\tpersistentApps\tplist\tbundle_id"
            let components = line.components(separatedBy: "\t")
            guard components.count >= 3 else { continue }
            
            let name = components[0]
            let path = components[1]
            let dockSection = components[2] // "persistentApps" or "persistentOthers"
            
            // Map dockutil section names to our section names
            let section: String
            if dockSection == "persistentApps" {
                section = "apps"
            } else if dockSection == "persistentOthers" {
                section = "others"
            } else {
                // Skip unknown sections (e.g., recent items)
                print("  ⏭️  Skipping unknown section: \(name) (\(dockSection))")
                continue
            }
            
            // Clean up the path (remove file:// prefix and trailing slash, but keep leading /)
            var cleanPath = path.replacingOccurrences(of: "file://", with: "")
            
            // Remove trailing slashes but preserve leading slash
            while cleanPath.hasSuffix("/") && cleanPath.count > 1 {
                cleanPath.removeLast()
            }
            
            // Decode URL encoding (e.g., %20 -> space)
            if let decodedPath = cleanPath.removingPercentEncoding {
                cleanPath = decodedPath
            }
            
            // Determine type based on path
            let type: DockItemType
            if cleanPath.hasSuffix(".app") {
                type = .app
            } else if cleanPath.starts(with: "http://") || cleanPath.starts(with: "https://") {
                type = .url
            } else if cleanPath.contains("spacer") {
                type = .spacer
            } else {
                type = .folder
            }
            
            // Extract icon data for apps and folders
            let iconData = extractIconData(for: cleanPath, type: type)
            
            items.append(DockItemInfo(type: type, name: name, path: cleanPath, iconData: iconData, section: section))
        }
        
        print("✅ Parsed \(items.count) items from Dock (apps and others sections)")
        return items
    }
}
