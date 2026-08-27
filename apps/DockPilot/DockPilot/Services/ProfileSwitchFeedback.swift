//
//  ProfileSwitchFeedback.swift
//  DockPilot
//

import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class ProfileSwitchFeedback {
    static let shared = ProfileSwitchFeedback()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    private init() {}

    func showSwitching(to profileName: String) {
        present(
            message: AppLocalization.string("Switching to %@…", profileName),
            symbol: "arrow.triangle.2.circlepath",
            tint: .accentColor,
            dismissAfter: nil
        )
    }

    func showSuccess(profileName: String) {
        present(
            message: AppLocalization.string("Profile “%@” activated", profileName),
            symbol: "checkmark.circle.fill",
            tint: .green,
            dismissAfter: 1.35
        )
    }

    func showFailure() {
        present(
            message: AppLocalization.string("Unable to switch profile"),
            symbol: "exclamationmark.triangle.fill",
            tint: .orange,
            dismissAfter: 1.8
        )
    }

    private func present(
        message: String,
        symbol: String,
        tint: Color,
        dismissAfter delay: TimeInterval?
    ) {
        dismissTask?.cancel()

        let panel = panel ?? makePanel()
        let content = ProfileSwitchHUDView(message: message, symbol: symbol, tint: tint)
        panel.contentView = NSHostingView(rootView: content)
        panel.setContentSize(NSSize(width: 300, height: 58))
        position(panel)

        if !panel.isVisible {
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
            }
        }

        if let delay {
            dismissTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.dismiss()
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visibleFrame = screen?.visibleFrame else { return }
        let frame = panel.frame
        panel.setFrameOrigin(NSPoint(
            x: visibleFrame.midX - frame.width / 2,
            y: visibleFrame.minY + 72
        ))
    }

    private func dismiss() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }
}

private struct ProfileSwitchHUDView: View {
    let message: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))

            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .padding(3)
    }
}
