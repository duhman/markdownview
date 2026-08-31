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

    func testReadWriteRoundTripPreservesMarkdownText() throws {
        let source = """
        # Notes

        ![diagram](./assets/diagram.png)

        | Task | Status |
        | ---- | ------ |
        | ship | done   |
        """

        let data = try source.data(using: .utf8).unwrap()
        let readConfig = FileDocument.ReadConfiguration(
            file: .init(regularFileWithContents: data),
            contentType: UTType(importedAs: "net.daringfireball.markdown")
        )

        let document = try MarkdownDocument(configuration: readConfig)
        XCTAssertEqual(document.text, source)

        let wrapper = try document.fileWrapper(configuration: .init(contentType: readConfig.contentType))
        let roundTrip = String(data: wrapper.regularFileContents ?? Data(), encoding: .utf8)
        XCTAssertEqual(roundTrip, source)
    }
}

private extension Optional where Wrapped == Data {
    func unwrap() throws -> Data {
        guard let self else {
            throw NSError(domain: "MarkdownDocumentTests", code: 1)
        }
        return self
    }
}
