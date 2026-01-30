import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    @State private var showPreview = false
    @State private var editorFrame: CGRect = .zero
    
    var body: some View {
        GeometryReader { geometry in
            HSplitView {
                // Editor pane
                MarkdownEditorView(text: $document.text)
                    .frame(minWidth: 300)
                    .background(Color(NSColor.textBackgroundColor))
                
                // Preview pane (conditional)
                if showPreview {
                    MarkdownPreviewView(text: document.text)
                        .frame(minWidth: 300)
                        .background(Color(NSColor.textBackgroundColor))
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showPreview.toggle() }) {
                    Image(systemName: showPreview ? "eye.slash" : "eye")
                }
                .help(showPreview ? "Hide Preview" : "Show Preview")
                
                Button(action: saveDocument) {
                    Image(systemName: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .help("Save Document")
            }
        }
    }
    
    private func saveDocument() {
        NSDocumentController.shared.currentDocument?.save(nil)
    }
}
