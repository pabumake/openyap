import AppKit
import SwiftUI

struct StatisticsView: View {
    @ObservedObject var store: StatisticsStore
    @Environment(\.openYapTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var period: StatisticsPeriod = .thirtyDays

    private var snapshot: StatisticsSnapshot {
        store.snapshot(for: period)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                if snapshot.sessionCount == 0 {
                    emptyState
                } else {
                    overview
                    corrections
                    activity
                    appUsage
                }
            }
            .frame(maxWidth: 1_060, alignment: .leading)
            .padding(28)
        }
        .scrollContentBackground(.hidden)
        .background(theme.palette.base)
        .navigationTitle("Statistics")
        .animation(reduceMotion ? nil : .snappy(duration: 0.35), value: snapshot.inputWordCount)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Statistics")
                    .font(.largeTitle.bold())
                Text("Your dictation activity stays on this Mac.")
                    .foregroundStyle(theme.palette.subtext)
            }
            Spacer()
            Picker("Period", selection: $period) {
                ForEach(StatisticsPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 260)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(theme.palette.accent)
            Text("No dictation activity in this period")
                .font(.title3.bold())
            Text("Your next completed dictation will add words, speed, corrections, and app usage here.")
                .foregroundStyle(theme.palette.subtext)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 430)
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .statisticsCard(theme: theme)
    }

    private var overview: some View {
        HStack(alignment: .top, spacing: 16) {
            WPMGauge(wordsPerMinute: snapshot.wordsPerMinute)
                .frame(minWidth: 270, maxWidth: 340)
                .statisticsCard(theme: theme)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                MetricCard(
                    title: "Words dictated",
                    value: snapshot.inputWordCount.formatted(),
                    detail: monthComparison,
                    icon: "text.word.spacing"
                )
                MetricCard(
                    title: "Input characters",
                    value: snapshot.inputCharacterCount.formatted(),
                    detail: "Before cleanup",
                    icon: "character.cursor.ibeam"
                )
                MetricCard(
                    title: "Dictation time",
                    value: Self.duration(snapshot.captureDuration),
                    detail: "Across \(snapshot.sessionCount.formatted()) sessions",
                    icon: "mic"
                )
                MetricCard(
                    title: "Estimated time saved",
                    value: Self.duration(snapshot.estimatedTimeSaved),
                    detail: "Compared with typing at 40 WPM",
                    icon: "clock.badge.checkmark"
                )
            }
        }
    }

    private var corrections: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Corrections by OpenYap", subtitle: "A local count of words and replacements changed before delivery.")
            HStack(spacing: 12) {
                CorrectionMetric(
                    value: snapshot.smartCleanupEditCount,
                    title: "Words cleaned",
                    subtitle: "Filler removal and rewrites",
                    color: theme.palette.accent,
                    icon: "wand.and.sparkles"
                )
                CorrectionMetric(
                    value: snapshot.dictionaryFixCount,
                    title: "Word list fixes",
                    subtitle: "Terms and correction rules",
                    color: theme.palette.green,
                    icon: "character.book.closed"
                )
                CorrectionMetric(
                    value: snapshot.snippetExpansionCount,
                    title: "Snippets expanded",
                    subtitle: "Saved text replacements",
                    color: theme.palette.yellow,
                    icon: "text.badge.plus"
                )
            }
        }
        .statisticsCard(theme: theme)
    }

    private var activity: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Usage streak", subtitle: "The last 12 weeks of completed dictations.")
            HStack(alignment: .top, spacing: 24) {
                HeatmapView(days: snapshot.heatmapDays)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 16) {
                    StreakValue(value: snapshot.currentStreak, title: "Current streak")
                    StreakValue(value: snapshot.longestStreak, title: "Longest streak")
                    StreakValue(value: snapshot.activeDayCount, title: "Days used in period")
                }
                .frame(width: 150, alignment: .leading)
            }
        }
        .statisticsCard(theme: theme)
    }

    private var appUsage: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("App usage", subtitle: "Where your dictated words went. App names never leave this Mac.")
            if displayedApps.isEmpty {
                Text("App usage starts with your next dictation.")
                    .foregroundStyle(theme.palette.subtext)
            } else {
                VStack(spacing: 13) {
                    ForEach(displayedApps) { app in
                        AppUsageRow(app: app, maximumWords: displayedApps.map(\.inputWordCount).max() ?? 1)
                    }
                }
            }
        }
        .statisticsCard(theme: theme)
    }

    private var displayedApps: [UsageAppSummary] {
        guard snapshot.apps.count > 6 else { return snapshot.apps }
        let leading = Array(snapshot.apps.prefix(6))
        let remainder = snapshot.apps.dropFirst(6)
        let other = UsageAppSummary(
            bundleIdentifier: "other",
            applicationName: "Other",
            sessionCount: remainder.reduce(0) { $0 + $1.sessionCount },
            inputWordCount: remainder.reduce(0) { $0 + $1.inputWordCount },
            inputCharacterCount: remainder.reduce(0) { $0 + $1.inputCharacterCount },
            captureDuration: remainder.reduce(0) { $0 + $1.captureDuration }
        )
        return leading + [other]
    }

    private var monthComparison: String {
        guard let change = snapshot.monthToDateWordChange else { return "This month" }
        let percentage = abs(change).formatted(.percent.precision(.fractionLength(0)))
        return change >= 0 ? "↑ \(percentage) month to date" : "↓ \(percentage) month to date"
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(theme.palette.subtext)
        }
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3_600
        let minutes = total % 3_600 / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(total)s"
    }
}

private struct WPMGauge: View {
    let wordsPerMinute: Double
    @Environment(\.openYapTheme) private var theme

    private var progress: Double { min(max(wordsPerMinute / 200, 0), 1) }

    var body: some View {
        VStack(spacing: 12) {
            Text("Speaking speed")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
            ZStack {
                Circle()
                    .trim(from: 0.5, to: 1)
                    .stroke(theme.palette.surface1, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                Circle()
                    .trim(from: 0.5, to: 0.5 + progress * 0.5)
                    .stroke(theme.palette.accent.gradient, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                VStack(spacing: 0) {
                    Text(wordsPerMinute.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("WPM")
                        .font(.caption.bold())
                        .foregroundStyle(theme.palette.subtext)
                }
                .offset(y: 22)
            }
            .frame(width: 210, height: 120)
            Text("40 WPM typical typing speed")
                .font(.caption)
                .foregroundStyle(theme.palette.subtext)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let icon: String
    @Environment(\.openYapTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(theme.palette.accent)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.palette.subtext)
            }
            Text(value)
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(detail)
                .font(.caption)
                .foregroundStyle(theme.palette.subtext)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(16)
        .background(theme.palette.surface0.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CorrectionMetric: View {
    let value: Int
    let title: String
    let subtitle: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(value.formatted())
                    .font(.title2.bold())
                    .contentTransition(.numericText())
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeatmapView: View {
    let days: [UsageHeatmapDay]
    @Environment(\.openYapTheme) private var theme

    private var maximumWords: Int { max(days.map(\.inputWordCount).max() ?? 0, 1) }
    private let rows = Array(repeating: GridItem(.fixed(15), spacing: 5), count: 7)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: rows, spacing: 5) {
                ForEach(days) { day in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(color(for: day.inputWordCount))
                        .frame(width: 15, height: 15)
                        .help("\(day.date.formatted(date: .abbreviated, time: .omitted)): \(day.inputWordCount.formatted()) words in \(day.sessionCount.formatted()) sessions")
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func color(for words: Int) -> Color {
        guard words > 0 else { return theme.palette.surface0 }
        let ratio = Double(words) / Double(maximumWords)
        let opacity: Double = switch ratio {
        case ..<0.25: 0.3
        case ..<0.5: 0.48
        case ..<0.75: 0.68
        default: 0.95
        }
        return theme.palette.accent.opacity(opacity)
    }
}

private struct StreakValue: View {
    let value: Int
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value.formatted())
                .font(.title2.bold())
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AppUsageRow: View {
    let app: UsageAppSummary
    let maximumWords: Int
    @Environment(\.openYapTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            appIcon
                .frame(width: 28, height: 28)
            Text(app.applicationName)
                .font(.subheadline.weight(.medium))
                .frame(width: 120, alignment: .leading)
                .lineLimit(1)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.palette.surface0)
                    Capsule()
                        .fill(theme.palette.accent.gradient)
                        .frame(width: proxy.size.width * max(0.025, Double(app.inputWordCount) / Double(max(maximumWords, 1))))
                }
            }
            .frame(height: 9)
            Text("\(app.inputWordCount.formatted()) words")
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.palette.subtext)
                .frame(width: 88, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if app.bundleIdentifier == "other" {
            Image(systemName: "square.grid.2x2.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(theme.palette.accent)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(theme.palette.subtext)
        }
    }
}

private extension View {
    func statisticsCard(theme: AppTheme) -> some View {
        padding(20)
            .background(theme.palette.mantle.opacity(0.8), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.palette.surface1.opacity(0.7), lineWidth: 1)
            }
    }
}
