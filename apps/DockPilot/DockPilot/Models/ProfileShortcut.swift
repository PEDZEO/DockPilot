//
//  ProfileShortcut.swift
//  DockPilot
//

import Foundation

enum ProfileShortcut: Int, CaseIterable, Identifiable {
    case disabled = 0
    case option1 = 1
    case option2 = 2
    case option3 = 3
    case option4 = 4
    case option5 = 5
    case option6 = 6
    case option7 = 7
    case option8 = 8
    case option9 = 9

    var id: Int { rawValue }

    var label: String {
        rawValue == 0 ? "Off" : "⌥\(rawValue)"
    }
}
