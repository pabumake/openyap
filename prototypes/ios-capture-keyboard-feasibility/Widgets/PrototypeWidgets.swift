import ActivityKit
import SwiftUI
import WidgetKit

@main
struct PrototypeWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrototypeLiveActivityWidget()
    }
}
struct PrototypeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrototypeActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 8) {
                Label("OpenYap prototype", systemImage: "waveform")
                    .font(.headline)
                activityStatus(context.state)
                    .font(.caption.monospacedDigit())
                Button(intent: StopPrototypeCaptureIntent(sessionID: context.attributes.sessionID)) {
                    Label("Stop capture", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .activityBackgroundTint(.indigo.opacity(0.2))
            .activitySystemActionForegroundColor(.indigo)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "waveform")
                }
                DynamicIslandExpandedRegion(.center) {
                    activityStatus(context.state)
                        .font(.caption.monospacedDigit())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Button(intent: StopPrototypeCaptureIntent(sessionID: context.attributes.sessionID)) {
                        Image(systemName: "stop.fill")
                    }
                }
            } compactLeading: {
                Image(systemName: "waveform")
            } compactTrailing: {
                if let startedAt = context.state.startedAt,
                   context.state.state == PrototypeSessionState.capturing.rawValue {
                    Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
                        .monospacedDigit()
                } else {
                    Text("\(context.state.elapsedSeconds)s")
                        .monospacedDigit()
                }
            } minimal: {
                Image(systemName: "waveform")
            }
            .widgetURL(URL(string: "openyap-prototype://capture"))
            .keylineTint(.indigo)
        }
    }

    @ViewBuilder
    private func activityStatus(_ state: PrototypeActivityAttributes.ContentState) -> some View {
        HStack(spacing: 4) {
            Text(state.state)
            if let startedAt = state.startedAt,
               state.state == PrototypeSessionState.capturing.rawValue {
                Text(timerInterval: startedAt...Date.distantFuture, countsDown: false)
            } else {
                Text("\(state.elapsedSeconds)s")
            }
        }
    }
}
