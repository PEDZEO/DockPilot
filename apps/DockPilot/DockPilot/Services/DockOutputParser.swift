//
//  DockOutputParser.swift
//  DockPilot
//

import AppKit
import Foundation

struct DockOutputParser {
    func parse(
        _ output: String,
        includeRecentApps: Bool = false,
        includeIcons: Bool = false
    ) -> [DockItemInfo] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                parseLine(
                    String(line),
                    includeRecentApps: includeRecentApps,
                    includeIcons: includeIcons
                )
            }
    }

    private func parseLine(
        _ line: String,
        includeRecentApps: Bool,
        includeIcons: Bool
    ) -> DockItemInfo? {
        let components = line.components(separatedBy: "\t")
        guard components.count >= 3 else { return nil }

        let name = components[0]
        let rawPath = components[1]
        let dockSection = components[2]
        let isRecent = dockSection == "recentApps"

        let section: String
        switch dockSection {
        case "persistentApps":
            section = "apps"
        case "recentApps" where includeRecentApps:
            section = "apps"
        case "persistentOthers":
            section = "others"
        default:
            return nil
        }

        let path = normalizedPath(rawPath)
        let type = itemType(name: name, path: path)
        let iconData = includeIcons ? extractIconData(for: path, type: type) : nil

        return DockItemInfo(
            type: type,
            name: name,
            path: path,
            iconData: iconData,
            section: section,
            isRecent: isRecent
        )
    }

    private func normalizedPath(_ rawPath: String) -> String {
        var path = rawPath
        if path.hasPrefix("file://") {
            path.removeFirst("file://".count)
        }
        while path.hasSuffix("/") && path.count > 1 {
            path.removeLast()
        }
        return path.removingPercentEncoding ?? path
    }

    private func itemType(name: String, path: String) -> DockItemType {
        // dockutil represents spacer tiles as an empty name and empty path.
        if name.isEmpty && path.isEmpty { return .spacer }
        if path.hasSuffix(".app") { return .app }
        if path.hasPrefix("http://") || path.hasPrefix("https://") { return .url }
        if path.contains("spacer") { return .spacer }
        return .folder
    }

    private func extractIconData(for path: String, type: DockItemType) -> Data? {
        guard type == .app || type == .folder,
              FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        let icon = NSWorkspace.shared.icon(forFile: path)
        let targetSize = NSSize(width: 64, height: 64)
        let resizedIcon = NSImage(size: targetSize)
        resizedIcon.lockFocus()
        icon.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: icon.size),
            operation: .copy,
            fraction: 1
        )
        resizedIcon.unlockFocus()

        guard let tiffData = resizedIcon.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
