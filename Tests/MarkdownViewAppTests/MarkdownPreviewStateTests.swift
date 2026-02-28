import Foundation
import XCTest
@testable import MarkdownViewApp

final class MarkdownPreviewStateTests: XCTestCase {
    @MainActor
    func testParsesMarkdownWithAppleRendererBehavior() async throws {
        let markdown = """
        # Heading

        - Item 1
        - Item 2

        | A | B |
        | - | - |
        | 1 | 2 |

        ```swift
        let x = 1
        ```

        [Example](https://example.com)
        """

        let state = MarkdownPreviewState(debounceNanoseconds: 0)
        state.scheduleParse(text: markdown, baseURL: nil)

        let finalState = await waitForState(in: state) {
            if case .rendered = $0 {
                return true
            }
            return false
        }

        guard case let .rendered(attributed, diagnostics) = finalState else {
            return XCTFail("Expected rendered markdown state.")
        }

        XCTAssertTrue(diagnostics.containsTableSyntax)
        XCTAssertFalse(diagnostics.containsImageSyntax)

        let visibleText = String(attributed.characters)
        XCTAssertTrue(visibleText.contains("Heading"))
        XCTAssertFalse(visibleText.contains("# Heading"))
        XCTAssertTrue(visibleText.contains("Item 1"))
        XCTAssertTrue(visibleText.contains("• Item 1"))
        XCTAssertTrue(visibleText.contains("let x = 1"))
        XCTAssertTrue(visibleText.contains("Example"))

        let nsAttributed = NSAttributedString(attributed)
        var foundLink = false
        nsAttributed.enumerateAttribute(
            NSAttributedString.Key("NSLink"),
            in: NSRange(location: 0, length: nsAttributed.length),
            options: []
        ) { value, _, stop in
            guard let value else { return }
            if String(describing: value).contains("https://example.com") {
                foundLink = true
                stop.pointee = true
            }
        }
        XCTAssertTrue(foundLink)
    }

    @MainActor
    func testResolvesRelativeURLsWhenBaseURLProvided() async throws {
        let markdown = "[Doc](./README.md)\n![Img](./preview.png)"

        let withoutBaseURL = MarkdownPreviewState(debounceNanoseconds: 0)
        withoutBaseURL.scheduleParse(text: markdown, baseURL: nil)
        let withoutState = await waitForState(in: withoutBaseURL) {
            if case .rendered = $0 {
                return true
            }
            return false
        }

        let withBaseURL = MarkdownPreviewState(debounceNanoseconds: 0)
        let baseURL = URL(fileURLWithPath: "/tmp/markdown-preview-tests")
        withBaseURL.scheduleParse(text: markdown, baseURL: baseURL)
        let withState = await waitForState(in: withBaseURL) {
            if case .rendered = $0 {
                return true
            }
            return false
        }

        guard case let .rendered(withoutAttributed, _) = withoutState else {
            return XCTFail("Expected rendered state without baseURL.")
        }
        guard case let .rendered(withAttributed, _) = withState else {
            return XCTFail("Expected rendered state with baseURL.")
        }

        let withoutValues = collectedMarkdownURLValues(withoutAttributed)
        let withValues = collectedMarkdownURLValues(withAttributed)

        XCTAssertTrue(withoutValues.contains { $0.contains("./README.md") })
        XCTAssertTrue(withoutValues.contains { $0.contains("./preview.png") })

        XCTAssertTrue(withValues.contains { $0.contains("file:///tmp/markdown-preview-tests") })
    }

    @MainActor
    func testDebounceAndCancellationApplyOnlyLatestResult() async throws {
        let state = MarkdownPreviewState(
            debounceNanoseconds: 20_000_000,
            parser: { text, _ in
                Thread.sleep(forTimeInterval: 0.01)
                return .rendered(AttributedString(text), .none)
            }
        )

        state.scheduleParse(text: "one", baseURL: nil)
        try await Task.sleep(nanoseconds: 5_000_000)
        state.scheduleParse(text: "two", baseURL: nil)
        try await Task.sleep(nanoseconds: 5_000_000)
        state.scheduleParse(text: "three", baseURL: nil)

        let finalState = await waitForState(in: state) {
            guard case let .rendered(attributed, _) = $0 else {
                return false
            }
            return String(attributed.characters) == "three"
        }

        guard case let .rendered(attributed, _) = finalState else {
            return XCTFail("Expected rendered state.")
        }
        XCTAssertEqual(String(attributed.characters), "three")
    }

    @MainActor
    func testStaleParseResultCannotOverwriteNewerRevision() async throws {
        let state = MarkdownPreviewState(
            debounceNanoseconds: 0,
            parser: { text, _ in
                if text == "slow" {
                    Thread.sleep(forTimeInterval: 0.08)
                } else {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                return .rendered(AttributedString(text), .none)
            }
        )

        state.scheduleParse(text: "slow", baseURL: nil)
        try await Task.sleep(nanoseconds: 1_000_000)
        state.scheduleParse(text: "fast", baseURL: nil)

        let finalState = await waitForState(in: state) {
            guard case let .rendered(attributed, _) = $0 else {
                return false
            }
            return String(attributed.characters) == "fast"
        }

        guard case let .rendered(attributed, _) = finalState else {
            return XCTFail("Expected rendered state.")
        }
        XCTAssertEqual(String(attributed.characters), "fast")
    }

    @MainActor
    func testLargeMarkdownParseCompletes() async throws {
        let paragraph = """
        # Header

        This is **bold** text with `code` and a [link](https://example.com).

        - Item A
        - Item B

        """

        var markdown = ""
        while markdown.utf8.count < 400_000 {
            markdown += paragraph
        }

        let state = MarkdownPreviewState(debounceNanoseconds: 0)
        let start = Date()
        state.scheduleParse(text: markdown, baseURL: nil)

        _ = await waitForState(in: state) {
            if case .rendered = $0 {
                return true
            }
            return false
        }

        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 20.0)
    }

    func testCollapsedLayoutGuardDetectsSevereLineBreakLoss() {
        XCTAssertTrue(
            MarkdownPreviewState.shouldFallbackForCollapsedLayout(
                sourceLineBreakCount: 20,
                renderedLineBreakCount: 0
            )
        )
        XCTAssertTrue(
            MarkdownPreviewState.shouldFallbackForCollapsedLayout(
                sourceLineBreakCount: 20,
                renderedLineBreakCount: 4
            )
        )
    }

    func testCollapsedLayoutGuardAllowsSmallOrPreservedDocuments() {
        XCTAssertFalse(
            MarkdownPreviewState.shouldFallbackForCollapsedLayout(
                sourceLineBreakCount: 2,
                renderedLineBreakCount: 0
            )
        )
        XCTAssertFalse(
            MarkdownPreviewState.shouldFallbackForCollapsedLayout(
                sourceLineBreakCount: 20,
                renderedLineBreakCount: 20
            )
        )
    }

    @MainActor
    private func waitForState(
        in state: MarkdownPreviewState,
        timeout: TimeInterval = 5.0,
        predicate: @escaping (PreviewRenderState) -> Bool
    ) async -> PreviewRenderState {
        let timeoutAt = Date().addingTimeInterval(timeout)
        while Date() < timeoutAt {
            let snapshot = state.renderState
            if predicate(snapshot) {
                return snapshot
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return state.renderState
    }

    private func collectedMarkdownURLValues(_ attributed: AttributedString) -> [String] {
        let nsAttributed = NSAttributedString(attributed)
        var collected: [String] = []

        let keys = [NSAttributedString.Key("NSLink"), NSAttributedString.Key("NSImageURL")]
        for key in keys {
            nsAttributed.enumerateAttribute(
                key,
                in: NSRange(location: 0, length: nsAttributed.length),
                options: []
            ) { value, _, _ in
                guard let value else { return }
                collected.append(String(describing: value))
            }
        }

        return collected
    }
}
