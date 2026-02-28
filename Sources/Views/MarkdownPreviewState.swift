import Foundation
import SwiftUI

enum PreviewRenderState {
    case rendered(AttributedString, ParseDiagnostics)
    case fallbackPlainText(String, ParseDiagnostics?)
}

struct ParseDiagnostics: Equatable {
    var containsImageSyntax: Bool
    var containsTableSyntax: Bool
    var renderedLineBreaksCollapsed: Bool

    static let none = ParseDiagnostics(
        containsImageSyntax: false,
        containsTableSyntax: false,
        renderedLineBreaksCollapsed: false
    )
}

@MainActor
final class MarkdownPreviewState: ObservableObject {
    private static let defaultDebounceNanoseconds: UInt64 = 250_000_000

    typealias Parser = @Sendable (_ text: String, _ baseURL: URL?) -> PreviewRenderState

    @Published private(set) var renderState: PreviewRenderState = .fallbackPlainText("", nil)
    @Published private(set) var hasCompletedParse = false
    @Published private(set) var isParsing = false

    private let debounceNanoseconds: UInt64
    private let parser: Parser
    private var revision: UInt64 = 0
    private var parseTask: Task<Void, Never>?

    init(
        debounceNanoseconds: UInt64 = defaultDebounceNanoseconds,
        parser: @escaping Parser = MarkdownPreviewState.defaultParser
    ) {
        self.debounceNanoseconds = debounceNanoseconds
        self.parser = parser
    }

    func scheduleParse(text: String, baseURL: URL?) {
        revision += 1
        let currentRevision = revision
        parseTask?.cancel()
        isParsing = true

        // Keep preview visible while first parse is still in-flight (especially for large files).
        if !hasCompletedParse {
            renderState = .fallbackPlainText(text, nil)
        }

        parseTask = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }
            guard !Task.isCancelled else { return }

            let result = await MarkdownPreviewState.parseOffMain(
                text: text,
                baseURL: baseURL,
                parser: parser
            )

            guard !Task.isCancelled else { return }
            guard currentRevision == revision else { return }
            renderState = result
            hasCompletedParse = true
            isParsing = false
        }
    }

    func cancel() {
        parseTask?.cancel()
        parseTask = nil
        isParsing = false
    }

    nonisolated
    private static func parseOffMain(
        text: String,
        baseURL: URL?,
        parser: @escaping Parser
    ) async -> PreviewRenderState {
        await Task.detached(priority: .utility) {
            parser(text, baseURL)
        }.value
    }

    nonisolated
    private static func defaultParser(text: String, baseURL: URL?) -> PreviewRenderState {
        do {
            let attributed = try renderMarkdownWithBlockAwareLayout(
                text: text,
                baseURL: baseURL
            )
            var diagnostics = detectDiagnostics(text: text, attributed: attributed)
            if shouldFallbackForCollapsedLayout(
                sourceLineBreakCount: lineBreakCount(in: text),
                renderedLineBreakCount: lineBreakCount(in: String(attributed.characters))
            ) {
                diagnostics.renderedLineBreaksCollapsed = true
                return .fallbackPlainText(text, diagnostics)
            }
            return .rendered(attributed, diagnostics)
        } catch {
            let diagnostics = detectDiagnostics(text: text, attributed: nil)
            return .fallbackPlainText(text, diagnostics)
        }
    }

    nonisolated
    private static func renderMarkdownWithBlockAwareLayout(
        text: String,
        baseURL: URL?
    ) throws -> AttributedString {
        // Avoid expensive per-line markdown parsing for very large documents.
        if text.utf8.count > 1_000_000 {
            return try parseInlineMarkdown(text, baseURL: baseURL)
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var result = AttributedString()
        var inCodeFence = false

        for index in lines.indices {
            let line = String(lines[index])
            var renderedLine = AttributedString(line)

            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inCodeFence.toggle()
                renderedLine = AttributedString(line)
                applyMonospacedStyle(to: &renderedLine)
            } else if inCodeFence {
                renderedLine = AttributedString(line)
                applyMonospacedStyle(to: &renderedLine)
            } else if let heading = parseHeading(from: line) {
                renderedLine = try parseInlineMarkdown(heading.text, baseURL: baseURL)
                applyHeadingStyle(level: heading.level, to: &renderedLine)
            } else if let listLine = parseUnorderedList(from: line) {
                renderedLine = try parseInlineMarkdown(
                    "\(listLine.indent)• \(listLine.text)",
                    baseURL: baseURL
                )
            } else if let listLine = parseOrderedList(from: line) {
                renderedLine = try parseInlineMarkdown(
                    "\(listLine.indent)\(listLine.number). \(listLine.text)",
                    baseURL: baseURL
                )
            } else if let quoteLine = parseBlockquote(from: line) {
                renderedLine = try parseInlineMarkdown(
                    "▎ \(quoteLine)",
                    baseURL: baseURL
                )
            } else if looksLikeTableRow(line) {
                renderedLine = AttributedString(line)
                applyMonospacedStyle(to: &renderedLine)
            } else if lineContainsInlineMarkdown(line) {
                renderedLine = try parseInlineMarkdown(line, baseURL: baseURL)
            }

            result += renderedLine
            if index != lines.index(before: lines.endIndex) {
                result += AttributedString("\n")
            }
        }

        return result
    }

    nonisolated
    private static func parseInlineMarkdown(
        _ text: String,
        baseURL: URL?
    ) throws -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        options.failurePolicy = .returnPartiallyParsedIfPossible
        return try AttributedString(
            markdown: text,
            options: options,
            baseURL: baseURL
        )
    }

    nonisolated
    private static func lineContainsInlineMarkdown(_ line: String) -> Bool {
        line.contains { character in
            switch character {
            case "*", "_", "`", "[", "]", "(", ")", "!", "<", ">", "~":
                return true
            default:
                return false
            }
        }
    }

    nonisolated
    private static func parseHeading(from line: String) -> (level: Int, text: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        let hashes = trimmed.prefix { $0 == "#" }
        let level = min(hashes.count, 6)
        guard level > 0 else { return nil }

        let remainder = trimmed.dropFirst(level)
        guard remainder.first == " " else { return nil }
        return (level, String(remainder.dropFirst()))
    }

    nonisolated
    private static func parseUnorderedList(from line: String) -> (indent: String, text: String)? {
        let indent = String(line.prefix { $0 == " " || $0 == "\t" })
        let trimmed = line.dropFirst(indent.count)
        guard let marker = trimmed.first, marker == "-" || marker == "*" || marker == "+" else {
            return nil
        }
        let afterMarker = trimmed.dropFirst()
        guard afterMarker.first == " " else { return nil }
        return (indent, String(afterMarker.dropFirst()))
    }

    nonisolated
    private static func parseOrderedList(from line: String) -> (indent: String, number: String, text: String)? {
        let indent = String(line.prefix { $0 == " " || $0 == "\t" })
        let trimmed = line.dropFirst(indent.count)

        let digits = trimmed.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let afterDigits = trimmed.dropFirst(digits.count)
        guard afterDigits.first == "." else { return nil }
        let afterDot = afterDigits.dropFirst()
        guard afterDot.first == " " else { return nil }

        return (indent, String(digits), String(afterDot.dropFirst()))
    }

    nonisolated
    private static func parseBlockquote(from line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(">") else { return nil }
        let text = trimmed.dropFirst().drop(while: { $0 == " " })
        return String(text)
    }

    nonisolated
    private static func looksLikeTableRow(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return false }

        if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
            return true
        }
        if trimmed.contains("|---") || trimmed.contains("---|") {
            return true
        }
        return false
    }

    nonisolated
    private static func applyMonospacedStyle(to text: inout AttributedString) {
        var container = AttributeContainer()
        container.font = .system(.body, design: .monospaced)
        text.mergeAttributes(container)
    }

    nonisolated
    private static func applyHeadingStyle(level: Int, to text: inout AttributedString) {
        let size: CGFloat
        switch level {
        case 1: size = 26
        case 2: size = 22
        case 3: size = 19
        case 4: size = 17
        case 5: size = 15
        default: size = 14
        }

        var container = AttributeContainer()
        container.font = .system(size: size, weight: .semibold)
        text.mergeAttributes(container)
    }

    nonisolated
    static func shouldFallbackForCollapsedLayout(
        sourceLineBreakCount: Int,
        renderedLineBreakCount: Int
    ) -> Bool {
        // Ignore tiny documents where line break differences are inconsequential.
        guard sourceLineBreakCount >= 3 else { return false }

        // Hard failure mode: parser/renderer collapsed all line breaks.
        if renderedLineBreakCount == 0 {
            return true
        }

        // Soft failure mode: rendered output lost most structure.
        return renderedLineBreakCount * 4 < sourceLineBreakCount
    }

    nonisolated
    private static func lineBreakCount(in text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { partialResult, scalar in
            if scalar == "\n" {
                partialResult += 1
            }
        }
    }

    nonisolated
    private static func detectDiagnostics(
        text: String,
        attributed: AttributedString?
    ) -> ParseDiagnostics {
        var containsImageSyntax = text.contains("![")
        var containsTableSyntax = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .contains { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("|") && trimmed.hasSuffix("|")
            }

        guard let attributed else {
            return ParseDiagnostics(
                containsImageSyntax: containsImageSyntax,
                containsTableSyntax: containsTableSyntax,
                renderedLineBreaksCollapsed: false
            )
        }

        let nsAttributed = NSAttributedString(attributed)
        nsAttributed.enumerateAttributes(
            in: NSRange(location: 0, length: nsAttributed.length),
            options: []
        ) { attributes, _, stop in
            if attributes[NSAttributedString.Key("NSImageURL")] != nil {
                containsImageSyntax = true
            }

            if let presentationIntent = attributes[NSAttributedString.Key("NSPresentationIntent")] {
                let intentText = String(describing: presentationIntent)
                if intentText.contains("Table") {
                    containsTableSyntax = true
                }
            }

            if containsImageSyntax && containsTableSyntax {
                stop.pointee = true
            }
        }

        return ParseDiagnostics(
            containsImageSyntax: containsImageSyntax,
            containsTableSyntax: containsTableSyntax,
            renderedLineBreaksCollapsed: false
        )
    }
}
