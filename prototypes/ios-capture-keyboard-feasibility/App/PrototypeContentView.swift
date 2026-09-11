import SwiftUI
import UIKit

struct PrototypeContentView: View {
    @ObservedObject var controller: PrototypeController
    @State private var hostText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    question
                    statePanel
                    controls
                    hostField
                    eventLog
                }
                .padding()
            }
            .navigationTitle("Capture prototype")
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Throwaway prototype")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Can the containing app keep capture and a Live Activity alive while the keyboard exchanges session-scoped commands and returns delivery text?")
                .font(.headline)
        }
    }

    private var statePanel: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            row("Session", controller.snapshot.sessionID?.uuidString ?? "none")
            row("State", controller.snapshot.state.rawValue)
            row("Elapsed", String(format: "%.1f seconds", controller.snapshot.elapsedSeconds))
            row("Audio buffers", "\(controller.snapshot.audioBufferCount)")
            row("Live Activity", controller.snapshot.liveActivityIsActive ? "active" : "inactive")
            row("Keyboard", controller.keyboardHeartbeatIsFresh ? "heartbeat fresh" : "absent or stale")
            row("Stale rejections", "\(controller.snapshot.staleRejectionCount)")
            row("Recovery copy", controller.snapshot.recoveryCopyWasCreated ? "created" : "not created")
            row("Scene phase", controller.scenePhase)
        }
        .font(.footnote.monospaced())
        .padding()
        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Button("Start capture in app") {
                controller.startFromApp()
            }
            .buttonStyle(.borderedProminent)
            .disabled([.preparing, .capturing, .finalizing].contains(controller.snapshot.state))

            HStack {
                Button("Stop") {
                    controller.stopFromApp()
                }
                .disabled(controller.snapshot.state != .capturing)

                Button("Cancel", role: .destructive) {
                    controller.cancelFromApp()
                }
                .disabled(![.preparing, .capturing, .finalizing].contains(controller.snapshot.state))

                Button("Copy recovery text") {
                    controller.copyRecoveryText()
                }
                .disabled(controller.snapshot.deliveryText == nil)
            }
            .buttonStyle(.bordered)

            ShareLink(item: controller.evidenceText) {
                Label("Share evidence", systemImage: "square.and.arrow.up")
            }

            Button("Reset prototype state", role: .destructive) {
                controller.resetPrototype()
            }
            .font(.footnote)
        }
        .frame(maxWidth: .infinity)
    }

    private var hostField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Local insertion target")
                .font(.headline)
            TextField("Select OpenYap Prototype and insert here", text: $hostText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            if let text = controller.snapshot.deliveryText {
                Text("Delivery text: \(text)")
                    .font(.footnote)
                    .textSelection(.enabled)
            }
        }
    }

    private var eventLog: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event log")
                .font(.headline)
            ForEach(Array(controller.eventLog.enumerated()), id: \.offset) { _, event in
                Text(event)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func row(_ name: String, _ value: String) -> some View {
        GridRow {
            Text(name).foregroundStyle(.secondary)
            Text(value).textSelection(.enabled)
        }
    }
}
