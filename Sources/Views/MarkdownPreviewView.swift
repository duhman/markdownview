import SwiftUI

struct MarkdownPreviewView: View {
    let text: String
    let baseURL: URL?

    @StateObject private var previewState = MarkdownPreviewState()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if previewState.isParsing && !previewState.hasCompletedParse {
                statusBanner(text: "Rendering markdown preview...")
                    .padding(.horizontal)
                    .padding(.top, 8)
            } else if previewState.hasCompletedParse,
                      case let .fallbackPlainText(_, diagnostics) = previewState.renderState {
                statusBanner(
                    text: diagnosticsBannerText(
                        diagnostics: diagnostics
                    )
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }

            ScrollView {
                if !previewState.hasCompletedParse {
                    Text(text)
                        .textSelection(.enabled)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    switch previewState.renderState {
                    case let .rendered(attributed, _):
                        Text(attributed)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    case let .fallbackPlainText(rawText, _):
                        Text(rawText)
                            .textSelection(.enabled)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .onAppear {
            previewState.scheduleParse(text: text, baseURL: baseURL)
        }
        .onChange(of: text) { _, _ in
            previewState.scheduleParse(text: text, baseURL: baseURL)
        }
        .onChange(of: baseURL) { _, _ in
            previewState.scheduleParse(text: text, baseURL: baseURL)
        }
        .onDisappear {
            previewState.cancel()
        }
    }

    @ViewBuilder
    private func statusBanner(text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func diagnosticsBannerText(
        diagnostics: ParseDiagnostics?
    ) -> String {
        guard let diagnostics else {
            return "Preview fallback: showing plain text."
        }

        if diagnostics.renderedLineBreaksCollapsed {
            return "Preview fallback: preserving source layout because rendered output collapsed line breaks."
        }

        var parts: [String] = []
        if diagnostics.containsImageSyntax {
            parts.append("images")
        }
        if diagnostics.containsTableSyntax {
            parts.append("tables")
        }

        return parts.isEmpty
            ? "Preview fallback: showing plain text."
            : "Preview fallback: showing plain text (detected \(parts.joined(separator: " + ")))."
    }
}
