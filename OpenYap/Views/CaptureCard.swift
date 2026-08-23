import SwiftUI

struct CaptureCard: View {
    @ObservedObject var model: AppModel
    @Environment(\.openYapTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(model.state.title, systemImage: stateIcon)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(model.state == .capturing ? theme.palette.red : theme.palette.text)
                Spacer()
                Text(model.shortcut.displayName)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Text(model.transcript.isEmpty ? emptyMessage : model.transcript)
                .font(.system(size: 16, design: .rounded))
                .foregroundStyle(model.transcript.isEmpty ? .secondary : .primary)
                .textSelection(.enabled)
                .lineLimit(4)
                .frame(maxWidth: .infinity, minHeight: 48, alignment: .topLeading)

            if let issue = model.session?.issue {
                Label(issue, systemImage: "exclamationmark.circle")
                    .font(.callout)
                    .foregroundStyle(theme.palette.yellow)
            }

            HStack(spacing: 10) {
                Button(action: model.toggleCapture) {
                    Label(primaryButtonTitle, systemImage: primaryButtonIcon)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.state == .finalizing || model.state == .preparingText || model.state == .delivering)

                if model.state == .capturing || model.state == .preparing {
                    Button("Cancel", action: model.cancel)
                }
                if model.state == .awaitingDelivery {
                    Button("Copy", action: model.copyAgain)
                    Button("Paste again", action: model.retryDelivery)
                }
            }
        }
        .padding(16)
        .background(theme.palette.surface0, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyMessage: String {
        switch model.state {
        case .preparing: "Checking the speech model and microphone..."
        case .capturing: "Speak now."
        case .finalizing: "Waiting for the last speech result..."
        case .preparingText: "Cleaning up the transcript..."
        default: "Press \(model.shortcut.displayName) or click Start dictation."
        }
    }

    private var primaryButtonTitle: String {
        switch model.state {
        case .preparing, .capturing: "Stop dictation"
        case .finalizing: "Finalizing"
        case .preparingText: "Cleaning up"
        case .delivering: "Pasting"
        default: "Start dictation"
        }
    }

    private var primaryButtonIcon: String {
        switch model.state {
        case .preparing, .capturing: "stop.fill"
        default: "mic.fill"
        }
    }

    private var stateIcon: String {
        switch model.state {
        case .idle: "circle"
        case .preparing, .finalizing, .preparingText, .delivering: "ellipsis"
        case .capturing: "waveform"
        case .awaitingDelivery: "doc.on.clipboard"
        case .delivered: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        }
    }
}
