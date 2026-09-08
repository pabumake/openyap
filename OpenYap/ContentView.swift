import SwiftUI

private enum AppSection: String, CaseIterable, Identifiable {
    case history
    case statistics
    case wordList
    case snippets
    case settings
    case about

    var id: String { rawValue }
    var title: String {
        switch self {
        case .history: "History"
        case .statistics: "Statistics"
        case .wordList: "Word List"
        case .snippets: "Snippets"
        case .settings: "Settings"
        case .about: "About"
        }
    }
    var icon: String {
        switch self {
        case .history: "clock.arrow.circlepath"
        case .statistics: "chart.bar.xaxis"
        case .wordList: "character.book.closed"
        case .snippets: "text.badge.plus"
        case .settings: "gearshape"
        case .about: "info.circle"
        }
    }
}

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updates: AppUpdateController
    @Environment(\.openYapTheme) private var theme
    @State private var selectedSection: AppSection? = .history

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image("OpenYapLogo")
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    Text("OpenYap")
                        .font(.headline)
                    Spacer()
                }
                .padding(14)

                List(AppSection.allCases, selection: $selectedSection) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)

                Divider()
                Button {
                    selectedSection = .about
                } label: {
                    HStack {
                        Text(AppVersionInfo.current.compactDisplayName)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.palette.subtext)
                        Spacer()
                        Image(systemName: "info.circle")
                            .foregroundStyle(theme.palette.subtext)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .background(theme.palette.mantle)
            .navigationSplitViewColumnWidth(min: 180, ideal: 210)
        } detail: {
            switch selectedSection ?? .history {
            case .history:
                HistoryView(model: model, history: model.historyStore)
            case .statistics:
                StatisticsView(store: model.statisticsStore)
            case .wordList:
                WordListView(store: model.lexiconStore)
            case .snippets:
                SnippetsView(store: model.snippetStore)
            case .settings:
                AppSettingsView(
                    model: model,
                    history: model.historyStore,
                    statistics: model.statisticsStore,
                    updates: updates
                )
            case .about:
                AboutView(changelog: model.changelogStore, updates: updates)
            }
        }
        .background(theme.palette.base)
        .alert("Start OpenYap when you log in?", isPresented: Binding(
            get: { model.shouldAskLaunchAtLogin },
            set: { if !$0 { model.answerLaunchAtLoginPrompt(enable: false) } }
        )) {
            Button("Enable") { model.answerLaunchAtLoginPrompt(enable: true) }
            Button("Not now", role: .cancel) { model.answerLaunchAtLoginPrompt(enable: false) }
        } message: {
            Text("OpenYap can stay ready in the menu bar after you sign in. macOS will show it under Login Items.")
        }
    }
}
