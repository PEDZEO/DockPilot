//
//  DockItemInfo.swift
//  DockPilot
//

import Foundation

struct DockItemInfo {
    let type: DockItemType
    let name: String
    let path: String
    let iconData: Data?
    let section: String
    let isRecent: Bool
}
