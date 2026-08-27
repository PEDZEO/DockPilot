//
//  ApplicationCatalogScanner.swift
//  DockPilot
//

import Foundation

struct ApplicationCatalogEntry: Sendable {
    let name: String
    let path: String
}

/// Performs filesystem traversal away from the main actor. Icon rendering is
/// deliberately left to the UI layer because AppKit owns that work.
enum ApplicationCatalogScanner {
    static func scan(roots: [String], maxDepth: Int = 4) -> [ApplicationCatalogEntry] {
        var entries: [ApplicationCatalogEntry] = []
        var seenPaths = Set<String>()

        for root in roots {
            let rootURL = URL(fileURLWithPath: root).standardizedFileURL
            guard let enumerator = FileManager.default.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let itemURL as URL in enumerator {
                if Task.isCancelled { return [] }

                let depth = itemURL.pathComponents.count - rootURL.pathComponents.count
                if depth > maxDepth {
                    enumerator.skipDescendants()
                    continue
                }

                guard itemURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
                    continue
                }

                let standardizedPath = itemURL.standardizedFileURL.path
                enumerator.skipDescendants()

                guard !DockSystemItemPolicy.isSystemManaged(path: standardizedPath),
                      seenPaths.insert(standardizedPath).inserted else {
                    continue
                }

                entries.append(
                    ApplicationCatalogEntry(
                        name: itemURL.deletingPathExtension().lastPathComponent,
                        path: standardizedPath
                    )
                )
            }
        }

        return entries.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
