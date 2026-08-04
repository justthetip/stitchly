import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var confirmDelete = false
    @State private var deletionError: String?
    @State private var operationMessage = ""
    var body: some View {
        NavigationStack {
            List {
                Section { HStack(spacing: 14) { Image(systemName: "person.crop.circle.fill").font(.system(size: 48)).foregroundStyle(Color.brandPink); VStack(alignment: .leading) { Text(auth.user?.name ?? "Exploring as a guest").font(.headline); if let email = auth.user?.email { Text(email).font(.subheadline).foregroundStyle(.secondary) } else { Text("Browse the demo, then create an account when you want to save.").font(.subheadline).foregroundStyle(.secondary) } } }.padding(.vertical, 8) }
                if auth.isGuest {
                    Section {
                        Button("Sign in or create account", systemImage: "person.crop.circle.badge.plus") {
                            auth.requireAuthentication(title: "Keep your making together", message: "Create an account or sign in to upload private patterns, save progress, and keep notes in sync.")
                        }
                        .accessibilityIdentifier("guest-account-action")
                    }
                } else {
                    Section { Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right") { operationMessage = "Signing out and closing your secure session…"; Task { await auth.signOut() } }.disabled(auth.isWorking); Button("Delete account", systemImage: "trash", role: .destructive) { confirmDelete = true }.disabled(auth.isWorking) }
                }
                Section { LabeledContent("Version", value: "1.0.0"); Link("Privacy policy", destination: APIClient.baseURL.appending(path: "/privacy")); Link("Support", destination: APIClient.baseURL.appending(path: "/support")) }
            }.navigationTitle("Account")
                .disabled(auth.isWorking)
                .overlay(alignment: .top) { if auth.isWorking { LoadingBanner(message: operationMessage).padding(.top, 8) } }
                .confirmationDialog("Delete your Stitchly account?", isPresented: $confirmDelete, titleVisibility: .visible) { Button("Delete account and data", role: .destructive) { operationMessage = "Deleting your patterns, projects, notes, and account…"; Task { do { try await auth.deleteAccount() } catch { deletionError = error.localizedDescription } } } } message: { Text("This permanently deletes your patterns, projects, notes, and sign-in connection.") }
                .alert("Account wasn’t deleted", isPresented: .init(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) { Button("OK") {} } message: { Text(deletionError ?? "") }
        }
    }
}
