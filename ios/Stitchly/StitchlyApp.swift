import SwiftUI
import AuthenticationServices

@main struct StitchlyApp: App {
    @StateObject private var auth = AuthManager()
    var body: some Scene { WindowGroup { RootView().environmentObject(auth).task { await auth.restore() }.tint(.brandOrange) } }
}

extension Color {
    static let brandOrange = Color(red: 1.0, green: 0.69, blue: 0.17)
    static let brandPink = Color(red: 0.95, green: 0.47, blue: 0.56)
    static let brandBlue = Color(red: 0.35, green: 0.76, blue: 0.92)
    static let ink = Color(red: 0.03, green: 0.18, blue: 0.35)
    static let cream = Color(red: 1.0, green: 0.96, blue: 0.87)
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    var body: some View {
        Group {
            if auth.user == nil { SignInView() }
            else if ProcessInfo.processInfo.arguments.contains("-readerDemo") { NavigationStack { ReaderView(project: DemoData.project) } }
            else { MainTabs() }
        }
            .alert("Something went wrong", isPresented: .init(get: { auth.errorMessage != nil }, set: { if !$0 { auth.errorMessage = nil } })) { Button("OK") {} } message: { Text(auth.errorMessage ?? "Please try again.") }
            .onChange(of: auth.token, initial: true) { _, _ in Telemetry.shared.configure(client: auth.client) }
    }
}

struct SignInView: View {
    @EnvironmentObject private var auth: AuthManager
    var body: some View {
        ZStack {
            LinearGradient(colors: [.cream, .white, .brandPink.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Image("BrandIcon").resizable().scaledToFit().frame(width: 132, height: 132).clipShape(.rect(cornerRadius: 28)).shadow(color: .brandPink.opacity(0.22), radius: 24, y: 12)
                VStack(spacing: 8) { Text("Stitchly").font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(Color.ink); Text("Every pattern, one calm step at a time.").font(.title3).multilineTextAlignment(.center).foregroundStyle(.secondary) }
                Spacer()
                SignInWithAppleButton(.continue) { auth.prepare($0) } onCompletion: { result in Task { await auth.complete(result) } }
                    .signInWithAppleButtonStyle(.black).frame(height: 54).clipShape(.rect(cornerRadius: 14)).disabled(auth.isWorking)
                Text("Your patterns stay private and belong to you.").font(.footnote).foregroundStyle(.secondary)
            }.padding(28)
        }
    }
}

struct MainTabs: View {
    @State private var selection = ProcessInfo.processInfo.arguments.contains("-libraryDemo") ? 1 : 0
    var body: some View {
        TabView(selection: $selection) {
            Tab("Projects", systemImage: "square.stack.3d.up.fill", value: 0) { ProjectsView() }
            Tab("Library", systemImage: "books.vertical.fill", value: 1) { LibraryView() }
            Tab("Account", systemImage: "person.crop.circle.fill", value: 2) { AccountView() }
        }
    }
}

struct EmptyState: View {
    let icon: String; let title: String; let message: String
    var body: some View { ContentUnavailableView(title, systemImage: icon, description: Text(message)) }
}

struct CraftBadge: View {
    let craft: String
    var body: some View { Label(craft.capitalized, systemImage: craft == "knit" ? "lines.measurement.horizontal" : "circle.hexagongrid.fill").font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6).background(Color.brandPink.opacity(0.14), in: .capsule).foregroundStyle(Color.brandPink) }
}
