//
//  DockProfileVerifier.swift
//  DockPilot
//

import Foundation

enum DockProfileVerifier {
    static func matches(expected: [DockItem], actual: [DockItemInfo]) -> Bool {
        differences(expected: expected, actual: actual).isEmpty
    }

    /// Returns compact, deterministic diagnostics for a failed comparison.
    /// Keeping this separate from the Dock mutation code makes matching easy to
    /// regression-test and lets us explain a retry without doing extra I/O.
    static func differences(expected: [DockItem], actual: [DockItemInfo]) -> [String] {
        let expectedItems = expected
        var differences: [String] = []

        let missingItems = expectedItems.filter { expectedItem in
            !actual.contains { itemMatches(expected: expectedItem, actual: $0) }
        }
        if !missingItems.isEmpty {
            differences.append("missing: \(missingItems.map(\.path).joined(separator: ", "))")
        }

        let persistentActualItems = actual.filter { !$0.isRecent }
        let unexpectedItems = persistentActualItems.filter { actualItem in
            !expectedItems.contains { itemMatches(expected: $0, actual: actualItem) }
        }
        if !unexpectedItems.isEmpty {
            differences.append("unexpected: \(unexpectedItems.map(\.path).joined(separator: ", "))")
        }

        for section in ["apps", "others"] {
            let actualSection = persistentActualItems.filter { $0.section == section }
            let expectedSection = expectedItems.filter { expectedItem in
                expectedItem.section == section && actualSection.contains {
                    itemMatches(expected: expectedItem, actual: $0)
                }
            }
            let orderMatches = expectedSection.count == actualSection.count && zip(expectedSection, actualSection).allSatisfy {
                itemMatches(expected: $0.0, actual: $0.1)
            }
            if !orderMatches {
                differences.append(
                    "\(section) order expected: \(expectedSection.map(\.path).joined(separator: " | ")); " +
                    "actual: \(actualSection.map(\.path).joined(separator: " | "))"
                )
            }
        }

        return differences
    }

    static func itemMatches(expected: DockItem, actual: DockItemInfo) -> Bool {
        guard expected.type == actual.type else { return false }

        switch expected.type {
        case .app, .folder:
            return normalizedFilePath(expected.path) == normalizedFilePath(actual.path)
        case .url:
            return expected.name == actual.name && expected.path == actual.path
        case .spacer:
            return true
        }
    }

    private static func normalizedFilePath(_ path: String) -> String {
        URL(fileURLWithPath: path)
            .standardizedFileURL
            .path
            .precomposedStringWithCanonicalMapping
    }
}
