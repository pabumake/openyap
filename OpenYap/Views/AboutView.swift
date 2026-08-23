import SwiftUI

struct AboutView: View {
    @ObservedObject var changelog: ChangelogStore
    @Environment(\.openYapTheme) private var theme

    private let version = AppVersionInfo.current

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                changelogCard
            }
            .frame(maxWidth: 820, alignment: .leading)
            .padding(28)
        }
        .scrollContentBackground(.hidden)
        .background(theme.palette.base)
        .navigationTitle("About OpenYap")
        .task { await changelog.refresh() }
    }

    private var header: some View {
        HStack(spacing: 18) {
            Image("OpenYapLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 74, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("OpenYap")
                    .font(.largeTitle.bold())
                Text(version.displayName)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(theme.palette.subtext)
                Text("Private, on-device dictation for macOS.")
                    .foregroundStyle(theme.palette.subtext)
            }
            Spacer()
            Link(destination: changelog.links.repositoryURL) {
                Label("Open GitHub", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
        .background(theme.palette.mantle, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var changelogCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Changelog").font(.title2.bold())
                    HStack(spacing: 6) {
                        if changelog.isLoading {
                            ProgressView().controlSize(.small)
                            Text("Checking GitHub")
                        } else {
                            Image(systemName: changelog.source == .github ? "checkmark.icloud" : "doc")
                            Text(changelog.source.title)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(theme.palette.subtext)
                }
                Spacer()
                Button {
                    Task { await changelog.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(changelog.isLoading)
            }

            if changelog.githubUnavailable {
                Label("GitHub is unavailable. OpenYap is showing the changelog included with this build.", systemImage: "wifi.exclamationmark")
                    .font(.callout)
                    .foregroundStyle(theme.palette.yellow)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.palette.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            }

            Divider()
            Text(renderedChangelog)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .background(theme.palette.mantle, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.palette.surface1.opacity(0.7), lineWidth: 1)
        }
    }

    private var renderedChangelog: AttributedString {
        (try? AttributedString(markdown: changelog.markdown)) ?? AttributedString(changelog.markdown)
    }
}
