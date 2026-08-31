import SwiftUI

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    @SceneStorage("showEditor") private var showEditor = false

    var body: some View {
        HSplitView {
            MarkdownPreviewView(
                text: document.text,
                baseURL: fileURL?.deletingLastPathComponent()
            )
            .frame(minWidth: 300)
            .background(Color(NSColor.textBackgroundColor))

            if showEditor {
                MarkdownEditorView(text: $document.text)
                    .frame(minWidth: 300)
                    .background(Color(NSColor.textBackgroundColor))
            }
        }
        .frame(minWidth: showEditor ? 600 : 400, minHeight: 400)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showEditor.toggle() }) {
                    Image(systemName: showEditor ? "doc.plaintext.fill" : "doc.plaintext")
                }
                .help(showEditor ? "Hide Editor" : "Show Editor")
            }
        }
    }
}
