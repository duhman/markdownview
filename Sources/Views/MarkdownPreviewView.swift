import SwiftUI

struct MarkdownPreviewView: View {
    let text: String
    @State private var attributedContent: AttributedString?
    @State private var parseTask: Task<Void, Never>?
    
    var body: some View {
        ScrollView {
            if let attributed = attributedContent {
                Text(attributed)
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(text)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .onAppear {
            parseMarkdown()
        }
        .onChange(of: text) { _, _ in
            parseMarkdown()
        }
        .onDisappear {
            parseTask?.cancel()
            parseTask = nil
        }
    }
    
    private func parseMarkdown() {
        let currentText = text
        parseTask?.cancel()
        parseTask = Task.detached(priority: .userInitiated) {
            let attributed: AttributedString?
            do {
                var options = AttributedString.MarkdownParsingOptions()
                options.interpretedSyntax = .full
                options.failurePolicy = .returnPartiallyParsedIfPossible
                attributed = try AttributedString(
                    markdown: currentText,
                    options: options
                )
            } catch {
                attributed = nil
            }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                attributedContent = attributed
            }
        }
    }
}
