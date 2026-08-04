import PDFKit
import SwiftUI

struct OriginalPDFView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    let patternID: String
    let title: String
    @State private var document: PDFDocument?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Group {
                if let document {
                    PDFDocumentView(document: document)
                        .accessibilityLabel("Original PDF for \(title)")
                } else if isLoading {
                    LoadingStateView(title: "Opening original PDF", message: "Securely loading the private source pattern for comparison…")
                } else {
                    ContentUnavailableView {
                        Label("PDF couldn’t be opened", systemImage: "doc.badge.ellipsis")
                    } description: {
                        Text(error ?? "The original PDF is not available.")
                    } actions: {
                        Button("Try again") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                            .tint(.ink)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
        .interactiveDismissDisabled(isLoading)
    }

    private func load() async {
        guard !isLoading || document == nil else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        if auth.token == "demo" {
            error = "The demo pattern does not include its source PDF."
            return
        }
        do {
            guard let userID = auth.user?.id else { throw APIError.invalidResponse }
            let path = "/api/patterns/\(patternID)/original"
            let data = try await AppDataCache.shared.pdfData(for: userID, path: path, client: auth.client)
            guard let loaded = PDFDocument(data: data) else { throw APIError.server("The downloaded file was not a readable PDF.") }
            document = loaded
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct PDFDocumentView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .secondarySystemBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document }
    }
}
