import SwiftUI

struct AccountView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var sync: OfflineSyncCoordinator
    @EnvironmentObject private var connectivity: ConnectivityObserver
    @State private var confirmDelete = false
    @State private var confirmDiscardingPendingChanges = false
    @State private var isPreparingSignOut = false
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
                    Section { Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right") { Task { await prepareToSignOut() } }.disabled(auth.isWorking || isPreparingSignOut); Button("Delete account", systemImage: "trash", role: .destructive) { confirmDelete = true }.disabled(auth.isWorking || isPreparingSignOut) }
                }
                Section { LabeledContent("Version", value: "1.0.0"); Link("Privacy policy", destination: APIClient.baseURL.appending(path: "/privacy")); Link("Support", destination: APIClient.baseURL.appending(path: "/support")) }
            }.navigationTitle("Account")
                .disabled(auth.isWorking)
                .overlay(alignment: .top) { if auth.isWorking { LoadingBanner(message: operationMessage).padding(.top, 8) } }
                .fullScreenCover(isPresented: $isPreparingSignOut) {
                    LoadingStateView(title: "Syncing before sign out", message: "Saving your latest project progress and notes to your account.")
                        .interactiveDismissDisabled()
                        .accessibilityIdentifier("sign-out-sync-takeover")
                }
                .confirmationDialog("Some changes haven’t synced", isPresented: $confirmDiscardingPendingChanges, titleVisibility: .visible) {
                    Button("Keep me signed in", role: .cancel) {}
                    Button("Sign out and discard local changes", role: .destructive) {
                        operationMessage = "Signing out and removing private data from this device…"
                        Task { await auth.signOut() }
                    }
                } message: {
                    Text(connectivity.isOnline ? "Stitchly couldn’t finish syncing. Stay signed in to retry, or sign out and remove these device-only changes." : "Connect to the internet to sync first, or sign out and remove these device-only changes.")
                }
                .confirmationDialog("Delete your Stitchly account?", isPresented: $confirmDelete, titleVisibility: .visible) { Button("Delete account and data", role: .destructive) { operationMessage = "Deleting your patterns, projects, notes, and account…"; Task { do { try await auth.deleteAccount() } catch { deletionError = error.localizedDescription } } } } message: { Text("This permanently deletes your patterns, projects, notes, and sign-in connection.") }
                .alert("Account wasn’t deleted", isPresented: .init(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) { Button("OK") {} } message: { Text(deletionError ?? "") }
        }
    }

    private func prepareToSignOut() async {
        guard !isPreparingSignOut else { return }
        if sync.pendingCount > 0 {
            guard connectivity.isOnline else { confirmDiscardingPendingChanges = true; return }
            isPreparingSignOut = true
            await sync.syncNow()
            isPreparingSignOut = false
            guard sync.pendingCount == 0 else { confirmDiscardingPendingChanges = true; return }
        }
        operationMessage = "Signing out and removing private data from this device…"
        await auth.signOut()
    }
}
