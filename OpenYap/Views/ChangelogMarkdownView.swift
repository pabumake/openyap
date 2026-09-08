import Markdown
import SwiftUI

enum ChangelogMarkdownBlockKind: Equatable {
    case heading(level: Int)
    case paragraph
    case unorderedList
    case orderedList(start: UInt)
    case blockQuote
    case codeBlock
    case thematicBreak
    case table
    case other
}

struct ChangelogMarkdownDocument {
    let document: Document

    init(markdown: String) {
        document = Document(parsing: markdown)
    }

    var blockKinds: [ChangelogMarkdownBlockKind] {
        document.children.map(Self.blockKind)
    }

    static func safeURL(destination: String?, relativeTo baseURL: URL) -> URL? {
        let directoryBase = baseURL.absoluteString.hasSuffix("/")
            ? baseURL
            : URL(string: baseURL.absoluteString + "/")!
        guard let destination,
              let url = URL(string: destination, relativeTo: directoryBase)?.absoluteURL,
              url.scheme?.lowercased() == "https",
              url.host != nil,
              url.user == nil,
              url.password == nil
        else {
            return nil
        }
        return url
    }

    private static func blockKind(_ block: any Markup) -> ChangelogMarkdownBlockKind {
        switch block {
        case let heading as Heading: .heading(level: heading.level)
        case is Paragraph: .paragraph
        case is UnorderedList: .unorderedList
        case let list as OrderedList: .orderedList(start: list.startIndex)
        case is BlockQuote: .blockQuote
        case is CodeBlock: .codeBlock
        case is ThematicBreak: .thematicBreak
        case is Markdown.Table: .table
        default: .other
        }
    }
}

struct ChangelogMarkdownView: View {
    private let parsed: ChangelogMarkdownDocument
    private let baseURL: URL

    init(markdown: String, baseURL: URL) {
        parsed = ChangelogMarkdownDocument(markdown: markdown)
        self.baseURL = baseURL
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(parsed.document.children.enumerated()), id: \.offset) { _, block in
                ChangelogMarkdownBlockView(block: block, baseURL: baseURL)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChangelogMarkdownBlockView: View {
    let block: any Markup
    let baseURL: URL
    @Environment(\.openYapTheme) private var theme

    var body: some View {
        Group {
            if let heading = block as? Heading {
                inlineText(heading)
                    .font(headingFont(level: heading.level))
                    .padding(.top, heading.level == 1 ? 4 : 8)
            } else if let paragraph = block as? Paragraph {
                inlineText(paragraph)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let list = block as? UnorderedList {
                listView(items: Array(list.children), start: nil)
            } else if let list = block as? OrderedList {
                listView(items: Array(list.children), start: list.startIndex)
            } else if let quote = block as? BlockQuote {
                HStack(alignment: .top, spacing: 12) {
                    Rectangle()
                        .fill(theme.palette.accent.opacity(0.7))
                        .frame(width: 3)
                    childBlocks(of: quote)
                        .foregroundStyle(theme.palette.subtext)
                }
                .padding(.vertical, 4)
            } else if let code = block as? CodeBlock {
                ScrollView(.horizontal) {
                    SwiftUI.Text(code.code)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(12)
                }
                .background(theme.palette.surface0, in: RoundedRectangle(cornerRadius: 9))
            } else if block is ThematicBreak {
                Divider()
            } else if let table = block as? Markdown.Table {
                tableView(table)
            } else if let html = block as? HTMLBlock {
                SwiftUI.Text(html.rawHTML)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(theme.palette.subtext)
            } else {
                childBlocks(of: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func headingFont(level: Int) -> Font {
        switch level {
        case 1: .title.bold()
        case 2: .title2.bold()
        case 3: .title3.bold()
        case 4: .headline
        default: .subheadline.bold()
        }
    }

    private func childBlocks(of markup: any Markup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(markup.children.enumerated()), id: \.offset) { _, child in
                ChangelogMarkdownBlockView(block: child, baseURL: baseURL)
            }
        }
    }

    private func listView(items: [any Markup], start: UInt?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(items.enumerated()), id: \.offset) { offset, item in
                if let item = item as? ListItem {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        SwiftUI.Text(listMarker(for: item, offset: offset, start: start))
                            .font(.body.monospacedDigit())
                            .foregroundStyle(theme.palette.subtext)
                            .frame(minWidth: 18, alignment: .trailing)
                        childBlocks(of: item)
                    }
                }
            }
        }
        .padding(.leading, 8)
    }

    private func listMarker(for item: ListItem, offset: Int, start: UInt?) -> String {
        if let checkbox = item.checkbox {
            switch checkbox {
            case .checked: return "☑"
            case .unchecked: return "☐"
            }
        }
        if let start {
            return "\(start + UInt(offset))."
        }
        return "•"
    }

    private func tableView(_ table: Markdown.Table) -> some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                tableRow(cells: Array(table.head.children), isHeader: true)
                ForEach(Array(table.body.rows.enumerated()), id: \.offset) { _, row in
                    tableRow(cells: Array(row.children), isHeader: false)
                }
            }
            .background(theme.palette.surface0, in: RoundedRectangle(cornerRadius: 9))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }

    private func tableRow(cells: [any Markup], isHeader: Bool) -> some View {
        GridRow {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                if let cell = cell as? Markdown.Table.Cell {
                    inlineText(cell)
                        .font(isHeader ? .callout.bold() : .callout)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minWidth: 90, maxWidth: 280, alignment: .leading)
                        .background(isHeader ? theme.palette.surface1.opacity(0.55) : Color.clear)
                }
            }
        }
    }

    private func inlineText(_ markup: any Markup) -> SwiftUI.Text {
        if let text = markup as? Markdown.Text {
            return SwiftUI.Text(text.string)
        }
        if let code = markup as? InlineCode {
            return SwiftUI.Text(code.code)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(theme.palette.accent)
        }
        if markup is SoftBreak {
            return SwiftUI.Text(" ")
        }
        if markup is LineBreak {
            return SwiftUI.Text("\n")
        }
        if let html = markup as? InlineHTML {
            return SwiftUI.Text(html.rawHTML)
        }
        if let image = markup as? Markdown.Image {
            let label = plainText(image)
            return SwiftUI.Text(label.isEmpty ? "[Image]" : "[Image: \(label)]")
                .foregroundColor(theme.palette.subtext)
        }
        if let link = markup as? Markdown.Link {
            let label = plainText(link)
            guard let url = ChangelogMarkdownDocument.safeURL(destination: link.destination, relativeTo: baseURL) else {
                return SwiftUI.Text(label)
            }
            var attributed = AttributedString(label)
            attributed.link = url
            attributed.underlineStyle = .single
            attributed.foregroundColor = theme.palette.accent
            return SwiftUI.Text(attributed)
        }

        let rendered = markup.children.reduce(SwiftUI.Text("")) { result, child in
            SwiftUI.Text("\(result)\(inlineText(child))")
        }
        if markup is Strong {
            return rendered.bold()
        }
        if markup is Emphasis {
            return rendered.italic()
        }
        if markup is Strikethrough {
            return rendered.strikethrough()
        }
        return rendered
    }

    private func plainText(_ markup: any Markup) -> String {
        if let text = markup as? Markdown.Text { return text.string }
        if let code = markup as? InlineCode { return code.code }
        if markup is SoftBreak { return " " }
        if markup is LineBreak { return "\n" }
        return markup.children.map(plainText).joined()
    }
}
