//
//  GlobalHotKeyManager.swift
//  DockPilot
//
//  Global profile shortcuts implemented with the public Carbon Hot Key API.
//

import Carbon
import Foundation

@MainActor
final class GlobalHotKeyManager {
    static let shared = GlobalHotKeyManager()

    private static let signature: OSType = 0x44464E59 // "DFNY"
    private static let numberKeyCodes: [UInt32] = [
        UInt32(kVK_ANSI_1),
        UInt32(kVK_ANSI_2),
        UInt32(kVK_ANSI_3),
        UInt32(kVK_ANSI_4),
        UInt32(kVK_ANSI_5),
        UInt32(kVK_ANSI_6),
        UInt32(kVK_ANSI_7),
        UInt32(kVK_ANSI_8),
        UInt32(kVK_ANSI_9),
    ]

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var action: ((Int) -> Void)?

    private init() {}

    func registerProfileShortcuts(slots: Set<Int>, action: @escaping (Int) -> Void) {
        unregisterProfileShortcuts()
        self.action = action

        guard !slots.isEmpty else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                guard let event else { return noErr }

                var hotKeyID = EventHotKeyID()
                let result = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard result == noErr,
                      hotKeyID.signature == GlobalHotKeyManager.signature else {
                    return result
                }

                let slot = Int(hotKeyID.id)
                Task { @MainActor in
                    GlobalHotKeyManager.shared.invoke(slot: slot)
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        guard status == noErr else {
            print("Failed to install global hot key handler: \(status)")
            return
        }

        for slot in slots.sorted() where (1...Self.numberKeyCodes.count).contains(slot) {
            let keyCode = Self.numberKeyCodes[slot - 1]
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(
                signature: Self.signature,
                id: UInt32(slot)
            )
            let result = RegisterEventHotKey(
                keyCode,
                UInt32(optionKey),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            if result == noErr, let hotKeyRef {
                hotKeyRefs.append(hotKeyRef)
            } else {
                print("Failed to register ⌥\(slot): \(result)")
            }
        }
    }

    func unregisterProfileShortcuts() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        action = nil
    }

    private func invoke(slot: Int) {
        action?(slot)
    }
}
