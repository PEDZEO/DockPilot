//
//  ProfileSwitchFeedback.swift
//  DockPilot
//

import AppKit
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class ProfileSwitchFeedback {
    static let shared = ProfileSwitchFeedback()

    private let model = ProfileSwitchHUDModel()
    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var presentationGeneration = 0

    private init() {}

    func showSwitching(to profileName: String) {
        present(
            message: AppLocalization.string("Switching to %@…", profileName),
            symbol: "arrow.triangle.2.circlepath",
            tint: .accentColor,
            isProgress: true,
            dismissAfter: nil
        )
    }

    func showSuccess(profileName: String) {
        present(
            message: AppLocalization.string("Profile “%@” activated", profileName),
            symbol: "checkmark.circle.fill",
            tint: .green,
            isProgress: false,
            dismissAfter: 1.15
        )
    }

    func showFailure() {
        present(
            message: AppLocalization.string("Unable to switch profile"),
            symbol: "exclamationmark.triangle.fill",
            tint: .orange,
            isProgress: false,
            dismissAfter: 1.7
        )
    }

    private func present(
        message: String,
        symbol: String,
        tint: Color,
        isProgress: Bool,
        dismissAfter delay: TimeInterval?
    ) {
        dismissTask?.cancel()
        presentationGeneration &+= 1
        let generation = presentationGeneration
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        model.update(
            message: message,
            symbol: symbol,
            tint: tint,
            isProgress: isProgress,
            animated: !reduceMotion
        )

        let panel = panel ?? makePanel()
        panel.setContentSize(NSSize(width: 380, height: 58))
        let targetOrigin = panelOrigin(for: panel)

        if !panel.isVisible {
            panel.alphaValue = 0
            panel.setFrameOrigin(NSPoint(x: targetOrigin.x, y: targetOrigin.y - (reduceMotion ? 0 : 7)))
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0.08 : 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrameOrigin(targetOrigin)
            }
        } else {
            // If a new switch starts during the previous fade-out, restore the
            // panel immediately and invalidate that fade's completion handler.
            panel.alphaValue = 1
            panel.setFrameOrigin(targetOrigin)
        }

        if let delay {
            dismissTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.dismiss(generation: generation)
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
        panel.contentView = NSHostingView(rootView: ProfileSwitchHUDView(model: model))
        self.panel = panel
        return panel
    }

    private func panelOrigin(for panel: NSPanel) -> NSPoint {
        let visibleFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        return NSPoint(
            x: visibleFrame.midX - panel.frame.width / 2,
            y: visibleFrame.minY + 72
        )
    }

    private func dismiss(generation: Int) {
        guard generation == presentationGeneration,
              let panel,
              panel.isVisible else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.08 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self, weak panel] in
            guard let self,
                  let panel,
                  generation == self.presentationGeneration else { return }
            panel.orderOut(nil)
        }
    }
}

@MainActor
private final class ProfileSwitchHUDModel: ObservableObject {
    @Published private(set) var message = ""
    @Published private(set) var symbol = "arrow.triangle.2.circlepath"
    @Published private(set) var tint: Color = .accentColor
    @Published private(set) var isProgress = true

    func update(message: String, symbol: String, tint: Color, isProgress: Bool, animated: Bool) {
        withAnimation(animated ? .easeInOut(duration: 0.16) : nil) {
            self.message = message
            self.symbol = symbol
            self.tint = tint
            self.isProgress = isProgress
        }
    }
}

private struct ProfileSwitchHUDView: View {
    @ObservedObject var model: ProfileSwitchHUDModel

    var body: some View {
        HStack(spacing: 11) {
            Group {
                if model.isProgress {
                    ProgressView()
                        .controlSize(.small)
                        .tint(model.tint)
                } else {
                    Image(systemName: model.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(model.tint)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 22, height: 22)

            Text(model.message)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
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
