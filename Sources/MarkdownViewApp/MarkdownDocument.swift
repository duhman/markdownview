import SwiftUI
import UniformTypeIdentifiers

struct MarkdownDocument: FileDocument {
    var text: String
    
    private static let markdownExtensions = ["md", "markdown", "mdown"]
    private static let markdownTypes: [UTType] = markdownExtensions.compactMap {
        UTType(filenameExtension: $0, conformingTo: .plainText)
    }
    
    static var readableContentTypes: [UTType] {
        markdownTypes + [.plainText]
    }
    
    static var writableContentTypes: [UTType] {
        markdownTypes + [.plainText]
    }
    
    init(text: String = "") {
        self.text = text
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        if let string = String(data: data, encoding: .utf8) {
            self.text = string
        } else {
            // Lossy fallback avoids hard-failing on invalid UTF-8.
            self.text = String(decoding: data, as: UTF8.self)
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
