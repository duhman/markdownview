import SwiftUI

struct MarkdownPreviewView: View {
    let text: String
    @State private var attributedContent: AttributedString?
    
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
    }
    
    private func parseMarkdown() {
        do {
            var options = AttributedString.MarkdownParsingOptions()
            options.interpretedSyntax = .inlineOnlyPreservingWhitespace
            
            let attributed = try AttributedString(
                markdown: text,
                options: options
            )
            attributedContent = attributed
        } catch {
            attributedContent = nil
        }
    }
}
