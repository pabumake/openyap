import UIKit

final class KeyboardViewController: UIInputViewController {
    private let stateLabel = UILabel()
    private let statusLabel = UILabel()
    private var pollTimer: Timer?
    private var currentSnapshot: PrototypeSnapshot?
    private var requestedSessionID: UUID?

    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        writePresence(isVisible: true)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        writePresence(isVisible: false)
        pollTimer?.invalidate()
        pollTimer = nil
        super.viewDidDisappear(animated)
    }

    private func buildInterface() {
        view.backgroundColor = .secondarySystemBackground

        let title = UILabel()
        title.text = "OpenYap Prototype"
        title.font = .preferredFont(forTextStyle: .headline)

        stateLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        stateLabel.numberOfLines = 0
        stateLabel.textColor = .label

        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.numberOfLines = 0
        statusLabel.textColor = .secondaryLabel

        let start = makeButton("Open app and start", action: #selector(startCapture))
        start.configuration = .filled()
        let stop = makeButton("Stop", action: #selector(stopCapture))
        let insert = makeButton("Insert delivery text", action: #selector(insertDeliveryText))
        let stale = makeButton("Send stale stop", action: #selector(sendStaleStop))
        let next = makeButton("Next keyboard", action: #selector(nextKeyboard))

        let firstRow = UIStackView(arrangedSubviews: [start, stop])
        firstRow.axis = .horizontal
        firstRow.spacing = 8
        firstRow.distribution = .fillEqually

        let secondRow = UIStackView(arrangedSubviews: [insert, stale, next])
        secondRow.axis = .horizontal
        secondRow.spacing = 8
        secondRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [title, stateLabel, firstRow, secondRow, statusLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 8
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            view.heightAnchor.constraint(greaterThanOrEqualToConstant: 250),
        ])
    }

    private func makeButton(_ title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = .bordered()
        button.configuration?.title = title
        button.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc private func startCapture() {
        let sessionID = UUID()
        requestedSessionID = sessionID
        guard send(action: .start, sessionID: sessionID, source: "Keyboard") else { return }

        guard let url = URL(string: "openyap-prototype://capture?session=\(sessionID.uuidString)") else {
            statusLabel.text = "Could not create the containing-app URL."
            return
        }

        extensionContext?.open(url) { [weak self] succeeded in
            DispatchQueue.main.async {
                self?.statusLabel.text = succeeded
                    ? "Containing app opened. Return to this text field after capture starts."
                    : "iOS rejected opening the containing app from this keyboard."
            }
        }
    }

    @objc private func stopCapture() {
        guard let sessionID = currentSnapshot?.sessionID ?? requestedSessionID else {
            statusLabel.text = "No matching session is visible."
            return
        }
        guard send(action: .stop, sessionID: sessionID, source: "Keyboard") else { return }
        statusLabel.text = "Verified the matching Stop command in the keyboard container."
    }

    @objc private func insertDeliveryText() {
        guard let snapshot = currentSnapshot,
              snapshot.state == .awaitingDelivery,
              let text = snapshot.deliveryText else {
            statusLabel.text = "No delivery text is awaiting this keyboard."
            return
        }
        textDocumentProxy.insertText(text)
        if send(action: .markDelivered, sessionID: snapshot.sessionID!, source: "Keyboard") {
            statusLabel.text = "Insertion requested; delivery command verified in the keyboard container."
        }
    }

    @objc private func sendStaleStop() {
        guard send(
            action: .stop,
            sessionID: UUID(),
            source: "Keyboard stale-command check"
        ) else { return }
        statusLabel.text = "Verified a mismatched Stop command in the keyboard container."
    }

    @objc private func nextKeyboard() {
        advanceToNextInputMode()
    }

    @discardableResult
    private func send(action: PrototypeCommandAction, sessionID: UUID, source: String) -> Bool {
        let command = PrototypeCommand(
            commandID: UUID(),
            sessionID: sessionID,
            action: action,
            requestedAt: Date(),
            source: source
        )
        do {
            try PrototypeBridge.writeCommand(command)
            guard try PrototypeBridge.readCommand()?.commandID == command.commandID else {
                statusLabel.text = "Command write completed, but immediate readback did not match."
                return false
            }
            return true
        } catch {
            statusLabel.text = "Command write failed: \(error)"
            return false
        }
    }

    private func refresh() {
        do {
            currentSnapshot = try PrototypeBridge.readSnapshot()
            let snapshot = currentSnapshot ?? .idle
            stateLabel.text = [
                "full access: \(hasFullAccess)",
                "session: \(snapshot.sessionID?.uuidString ?? "none")",
                "state: \(snapshot.state.rawValue)",
                String(format: "elapsed: %.1fs", snapshot.elapsedSeconds),
                "buffers: \(snapshot.audioBufferCount)",
                "live activity: \(snapshot.liveActivityIsActive)",
                "stale rejections: \(snapshot.staleRejectionCount)",
                "recovery copy: \(snapshot.recoveryCopyWasCreated)",
                "last: \(snapshot.lastEvent)",
            ].joined(separator: "\n")
            writePresence(isVisible: true)
        } catch {
            stateLabel.text = "App Group unavailable"
            statusLabel.text = "Enable Full Access and confirm that every target uses group.dev.pabu.openyap."
        }
    }

    private func writePresence(isVisible: Bool) {
        try? PrototypeBridge.writeKeyboardPresence(
            PrototypeKeyboardPresence(
                sessionID: currentSnapshot?.sessionID ?? requestedSessionID,
                updatedAt: Date(),
                isVisible: isVisible
            )
        )
    }
}
