//
//  DockUtilService.swift
//  DockPilot
//

import Foundation

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

final class DockUtilService {
    static let shared = DockUtilService()

    private let runner = DockCommandRunner()
    private let parser = DockOutputParser()
    private var dockutilPath: String?

    private init() {}

    func readCurrentDock() async throws -> [DockItemInfo] {
        try await prepareDockutil()
        let output = try await runDockutil(["--list"])
        return parser.parse(output, includeIcons: true)
            .filter { !DockSystemItemPolicy.isSystemManaged(path: $0.path) }
    }

    func applyProfile(items: [DockItem]) async throws {
        try await prepareDockutil()

        let validItems = items
            .filter(isValidManagedItem)
            .sorted { $0.position < $1.position }

        let currentItems = try await readCurrentDockForVerification()
        let initialDifferences = DockProfileVerifier.differences(
            expected: validItems,
            actual: currentItems
        )
        if initialDifferences.isEmpty {
            return
        }
#if DEBUG
        print("Dock profile differs before apply: \(initialDifferences.joined(separator: "; "))")
#endif

        for attempt in 1...2 {
            try await clearManagedDockItems()
            for item in validItems {
                try await addItemToDock(item)
            }

            try await restartDock()

            if try await profileMatchesAfterSettling(validItems) {
                return
            }

            if attempt == 1 {
                try? await Task.sleep(for: .milliseconds(180))
            }
        }

        throw DockUtilError.commandFailed(
            AppLocalization.string("Dock did not retain the selected profile")
        )
    }

    private func profileMatchesAfterSettling(_ expected: [DockItem]) async throws -> Bool {
        let firstRead = try await readCurrentDockForVerification()
        if DockProfileVerifier.matches(expected: expected, actual: firstRead) {
            return true
        }

        try? await Task.sleep(for: .milliseconds(220))
        let settledRead = try await readCurrentDockForVerification()
        return DockProfileVerifier.matches(expected: expected, actual: settledRead)
    }

    private func isValidManagedItem(_ item: DockItem) -> Bool {
        guard !DockSystemItemPolicy.isSystemManaged(path: item.path) else {
            return false
        }

        switch item.type {
        case .app, .folder:
            return FileManager.default.fileExists(atPath: item.path)
        case .url, .spacer:
            return true
        }
    }

    private func readCurrentDockForVerification() async throws -> [DockItemInfo] {
        let output = try await runDockutil(["--list"])
        return parser.parse(output, includeRecentApps: true, includeIcons: false)
            .filter { !DockSystemItemPolicy.isSystemManaged(path: $0.path) }
    }

    private func clearManagedDockItems() async throws {
        let output = try await runDockutil(["--list"])
        let currentItems = parser.parse(output, includeIcons: false)

        for item in currentItems where item.type != .spacer && !DockSystemItemPolicy.isSystemManaged(path: item.path) {
            do {
                _ = try await runDockutil(["--remove", item.path, "--no-restart"])
            } catch {
                _ = try await runDockutil(["--remove", item.name, "--no-restart"])
            }
        }

        _ = try await runDockutil(["--remove", "spacer-tiles", "--no-restart"])
    }

    private func addItemToDock(_ item: DockItem) async throws {
        var arguments: [String]
        switch item.type {
        case .app:
            arguments = ["--add", item.path, "--section", item.section]
        case .folder:
            arguments = [
                "--add", item.path,
                "--view", "auto",
                "--display", "folder",
                "--section", item.section,
            ]
        case .url:
            arguments = ["--add", item.path, "--label", item.name, "--section", item.section]
        case .spacer:
            arguments = ["--add", "", "--type", "spacer", "--section", item.section]
        }
        arguments.append("--no-restart")
        _ = try await runDockutil(arguments)
    }

    func restartDock() async throws {
        _ = try await runner.run("/usr/bin/killall", arguments: ["Dock"])
        try await waitForDockReady()
    }

    private func waitForDockReady(timeout: Duration = .seconds(8)) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        var lastError: Error?

        while clock.now < deadline {
            do {
                _ = try await runDockutil(["--list"])
                return
            } catch {
                lastError = error
                try? await Task.sleep(for: .milliseconds(120))
            }
        }

        throw lastError ?? DockUtilError.commandFailed("Dock did not restart in time")
    }

    private func prepareDockutil() async throws {
        if let dockutilPath, FileManager.default.isExecutableFile(atPath: dockutilPath) {
            return
        }

        let possiblePaths = [
            "/opt/homebrew/bin/dockutil",
            "/usr/local/bin/dockutil",
            "/usr/bin/dockutil",
        ]
        if let path = possiblePaths.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            dockutilPath = path
            return
        }

        let output = try? await runner.run("/usr/bin/which", arguments: ["dockutil"])
        let resolvedPath = output?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard FileManager.default.isExecutableFile(atPath: resolvedPath) else {
            throw DockUtilError.dockutilNotFound
        }
        dockutilPath = resolvedPath
    }

    private func runDockutil(_ arguments: [String]) async throws -> String {
        guard let dockutilPath else { throw DockUtilError.dockutilNotFound }
        return try await runner.run(dockutilPath, arguments: arguments)
    }
}
