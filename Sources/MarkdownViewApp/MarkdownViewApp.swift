import SwiftUI
import UniformTypeIdentifiers

@main
struct MarkdownViewApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
        }
        .defaultSize(width: 1200, height: 800)
        .windowStyle(.titleBar)
    }
}
