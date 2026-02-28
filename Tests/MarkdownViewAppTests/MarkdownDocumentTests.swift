import UniformTypeIdentifiers
import XCTest
@testable import MarkdownViewApp

final class MarkdownDocumentTests: XCTestCase {
    func testReadableAndWritableContentTypesAreStable() {
        let expectedMarkdownType = UTType(importedAs: "net.daringfireball.markdown")

        XCTAssertEqual(MarkdownDocument.readableContentTypes.first, expectedMarkdownType)
        XCTAssertEqual(MarkdownDocument.writableContentTypes.first, expectedMarkdownType)

        XCTAssertTrue(MarkdownDocument.readableContentTypes.contains(.plainText))
        XCTAssertTrue(MarkdownDocument.writableContentTypes.contains(.plainText))
    }
}
