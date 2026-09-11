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
                Text("\(context.state.state), \(context.state.elapsedSeconds)s")
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
                    Text("\(context.state.state), \(context.state.elapsedSeconds)s")
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
                Text("\(context.state.elapsedSeconds)s")
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "waveform")
            }
            .widgetURL(URL(string: "openyap-prototype://capture"))
            .keylineTint(.indigo)
        }
    }
}
