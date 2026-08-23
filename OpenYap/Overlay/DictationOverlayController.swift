import AppKit
import SwiftUI

@MainActor
final class OverlayPresentationModel: ObservableObject {
    @Published var state: DictationState = .idle
    @Published var transcript = ""
    @Published var issue: String?
    @Published var theme: AppTheme = .system
}

@MainActor
final class DictationOverlayController {
    private let model = OverlayPresentationModel()
    private var panel: NSPanel?
    private var hideTask: Task<Void, Never>?

    func update(state: DictationState, transcript: String, issue: String?) {
        model.state = state
        model.transcript = transcript
        model.issue = issue
        hideTask?.cancel()

        guard state != .idle else {
            hide(animated: true)
            return
        }

        show()
        if [.delivered, .awaitingDelivery, .failed].contains(state) {
            hideTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(state == .failed ? 4 : 2.5))
                guard !Task.isCancelled else { return }
                self?.hide(animated: true)
            }
        }
    }

    func updateTheme(_ theme: AppTheme) {
        model.theme = theme
    }

    private func makePanel() -> NSPanel {
        let size = NSSize(width: 410, height: 92)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: DictationOverlayView(model: model))
        return panel
    }

    private func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        let target = targetFrame(for: panel.frame.size)

        if !panel.isVisible {
            var start = target
            start.origin.y -= 14
            panel.setFrame(start, display: false)
            panel.alphaValue = 0
            panel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().alphaValue = 1
                panel.animator().setFrame(target, display: true)
            }
        } else if panel.frame.origin != target.origin {
            panel.setFrame(target, display: true, animate: true)
        }
    }

    private func hide(animated: Bool) {
        guard let panel, panel.isVisible else { return }
        guard animated else {
            panel.orderOut(nil)
            return
        }
        var target = panel.frame
        target.origin.y -= 10
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(target, display: true)
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
    }

    private func targetFrame(for size: NSSize) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? .zero
        return NSRect(
            x: visible.midX - size.width / 2,
            y: visible.minY + 34,
            width: size.width,
            height: size.height
        )
    }
}

private struct DictationOverlayView: View {
    @ObservedObject var model: OverlayPresentationModel

    private var palette: AppPalette { model.theme.palette }

    var body: some View {
        HStack(spacing: 15) {
            statusVisual
                .frame(width: 54, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(model.state.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(detailText)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(width: 400, height: 78)
        .background(palette.base.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(palette.surface1.opacity(0.9), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 22, y: 9)
        .openYapTheme(model.theme)
        .animation(.snappy(duration: 0.24), value: model.state)
        .animation(.easeOut(duration: 0.16), value: model.transcript)
    }

    @ViewBuilder
    private var statusVisual: some View {
        switch model.state {
        case .capturing:
            WaveformView()
        case .delivered:
            Image(systemName: "checkmark")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(palette.green, in: Circle())
                .transition(.scale.combined(with: .opacity))
        case .awaitingDelivery:
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(palette.yellow)
        case .failed:
            Image(systemName: "exclamationmark")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(palette.red, in: Circle())
        default:
            ProgressView()
                .controlSize(.small)
        }
    }

    private var detailText: String {
        if let issue = model.issue, !issue.isEmpty { return issue }
        if !model.transcript.isEmpty { return model.transcript }
        return switch model.state {
        case .preparing: "Loading the local speech model"
        case .capturing: "Speak naturally"
        case .finalizing: "Keeping the final words"
        case .preparingText: "Removing fillers and cleaning punctuation"
        case .delivering: "Sending text to the active app"
        case .delivered: "Text inserted"
        case .awaitingDelivery: "Text copied to the clipboard"
        case .failed: "Open OpenYap for details"
        case .idle: ""
        }
    }
}

private struct WaveformView: View {
    @Environment(\.openYapTheme) private var theme

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<7, id: \.self) { index in
                    let wave = abs(sin(time * 5.4 + Double(index) * 0.72))
                    Capsule()
                        .fill(theme.palette.accent.gradient)
                        .frame(width: 4, height: 8 + wave * 26)
                }
            }
        }
    }
}
