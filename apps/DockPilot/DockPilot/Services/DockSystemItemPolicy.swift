//
//  DockSystemItemPolicy.swift
//  DockPilot
//

import Foundation

/// Items whose Dock records contain private macOS metadata and must never be
/// recreated as ordinary application tiles.
enum DockSystemItemPolicy {
    private static let managedPaths: Set<String> = [
        "/System/Applications/Apps.app",
    ]

    static func isSystemManaged(path: String) -> Bool {
        let standardizedPath = URL(fileURLWithPath: path).standardizedFileURL.path
        return managedPaths.contains(standardizedPath)
    }
}
