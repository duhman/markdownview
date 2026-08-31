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
    private static let largeDocumentUTF8Threshold = 1_000_000

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
            let attributed = try renderMarkdown(text: text, baseURL: baseURL)
            let diagnostics = detectDiagnostics(text: text, attributed: attributed)
            return .rendered(attributed, diagnostics)
        } catch {
            let diagnostics = detectDiagnostics(text: text, attributed: nil)
            return .fallbackPlainText(text, diagnostics)
        }
    }

    nonisolated
    private static func renderMarkdown(text: String, baseURL: URL?) throws -> AttributedString {
        var options = AttributedString.MarkdownParsingOptions()
        options.failurePolicy = .returnPartiallyParsedIfPossible

        if text.utf8.count > largeDocumentUTF8Threshold {
            // Very large documents: inline-only keeps parsing bounded.
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
        }

        return try AttributedString(
            markdown: text,
            options: options,
            baseURL: baseURL
        )
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
