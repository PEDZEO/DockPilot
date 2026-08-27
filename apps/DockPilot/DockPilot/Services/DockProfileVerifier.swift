//
//  DockProfileVerifier.swift
//  DockPilot
//

import Foundation

enum DockProfileVerifier {
    static func matches(expected: [DockItem], actual: [DockItemInfo]) -> Bool {
        let expectedItems = expected.filter { $0.type != .spacer }

        let allExpectedItemsExist = expectedItems.allSatisfy { expectedItem in
            actual.contains { itemMatches(expected: expectedItem, actual: $0) }
        }

        let persistentActualItems = actual.filter { !$0.isRecent }
        let noUnexpectedPersistentItems = persistentActualItems.allSatisfy { actualItem in
            expectedItems.contains { itemMatches(expected: $0, actual: actualItem) }
        }

        let persistentOrderMatches = ["apps", "others"].allSatisfy { section in
            let actualSection = persistentActualItems.filter { $0.section == section }
            let expectedSection = expectedItems.filter { expectedItem in
                expectedItem.section == section && actualSection.contains {
                    itemMatches(expected: expectedItem, actual: $0)
                }
            }
            guard expectedSection.count == actualSection.count else { return false }
            return zip(expectedSection, actualSection).allSatisfy {
                itemMatches(expected: $0.0, actual: $0.1)
            }
        }

        return allExpectedItemsExist && noUnexpectedPersistentItems && persistentOrderMatches
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
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
