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
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var createAccount = false
    private var canSubmit: Bool { email.contains("@") && password.count >= 8 && (!createAccount || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
    var body: some View {
        ZStack {
            LinearGradient(colors: [.cream, .white, .brandPink.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    Image("BrandIcon").resizable().scaledToFit().frame(width: 108, height: 108).clipShape(.rect(cornerRadius: 24)).shadow(color: .brandPink.opacity(0.22), radius: 20, y: 10)
                    VStack(spacing: 6) { Text("Stitchly").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundStyle(Color.ink); Text(createAccount ? "Create your maker space." : "Welcome back, maker.").font(.title3).foregroundStyle(.secondary) }
                    VStack(spacing: 12) {
                        if createAccount { TextField("Your name", text: $name).textContentType(.name).textInputAutocapitalization(.words) }
                        TextField("Email address", text: $email).textContentType(.emailAddress).textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                        SecureField("Password", text: $password).textContentType(createAccount ? .newPassword : .password)
                    }.padding(16).background(.regularMaterial, in: .rect(cornerRadius: 18))
                    Button { Task { await auth.authenticateWithEmail(email: email, password: password, name: createAccount ? name : nil, createAccount: createAccount) } } label: {
                        Group { if auth.isWorking { ProgressView() } else { Text(createAccount ? "Create account" : "Sign in") } }.frame(maxWidth: .infinity)
                    }.buttonStyle(.borderedProminent).controlSize(.large).disabled(!canSubmit || auth.isWorking)
                    Button(createAccount ? "Already have an account? Sign in" : "New here? Create an account") { withAnimation { createAccount.toggle() } }.font(.subheadline.weight(.semibold)).disabled(auth.isWorking)
                    HStack { Rectangle().frame(height: 1); Text("or").font(.footnote); Rectangle().frame(height: 1) }.foregroundStyle(.tertiary)
                    SignInWithAppleButton(.continue) { auth.prepare($0) } onCompletion: { result in Task { await auth.complete(result) } }
                        .signInWithAppleButtonStyle(.black).frame(height: 54).clipShape(.rect(cornerRadius: 14)).disabled(auth.isWorking)
                    Text("Your patterns stay private and belong to you.").font(.footnote).foregroundStyle(.secondary)
                }.padding(28).padding(.top, 24)
            }.scrollDismissesKeyboard(.interactively)
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
