import SwiftUI
import AuthenticationServices

@main struct StitchlyApp: App {
    @StateObject private var auth = AuthManager()
    var body: some Scene { WindowGroup { RootView().environmentObject(auth).task { await auth.restore() }.tint(.brandOrange) } }
}

extension Color {
    static let brandOrange = Color(red: 1.0, green: 0.69, blue: 0.17)
    static let brandPink = Color(red: 0.76, green: 0.20, blue: 0.34)
    static let brandBlue = Color(red: 0.35, green: 0.76, blue: 0.92)
    static let ink = Color(red: 0.03, green: 0.18, blue: 0.35)
    static let cream = Color(red: 1.0, green: 0.96, blue: 0.87)
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasShownFirstLaunchSplash") private var hasShownFirstLaunchSplash = false
    private var arguments: [String] { ProcessInfo.processInfo.arguments }
    private var shouldShowOnboarding: Bool {
        if arguments.contains("-skipOnboardingForUITests") { return false }
        if arguments.contains("-onboardingDemo") { return !hasCompletedOnboarding }
        return !hasCompletedOnboarding && auth.user == nil
    }
    var body: some View {
        Group {
            if shouldShowFirstLaunchSplash { BrandedSplashView().task { await finishFirstLaunchSplash() } }
            else if auth.isRestoring { LoadingStateView(title: "Opening Stitchly", message: "Restoring your secure session and syncing your account.") }
            else if shouldShowOnboarding { OnboardingView { hasCompletedOnboarding = true } }
            else if auth.user == nil { SignInView() }
            else if ProcessInfo.processInfo.arguments.contains("-patternDemo") { NavigationStack { PatternDetailView(pattern: DemoData.pattern) } }
            else if ProcessInfo.processInfo.arguments.contains("-readerSectionsDemo") { NavigationStack { ReaderView(project: DemoData.project, showSectionsInitially: true) } }
            else if ProcessInfo.processInfo.arguments.contains("-readerDemo") { NavigationStack { ReaderView(project: DemoData.project) } }
            else { MainTabs() }
        }
            .onAppear {
                if arguments.contains("-resetOnboardingForUITests") { hasCompletedOnboarding = false }
                if arguments.contains("-resetFirstLaunchSplashForUITests") { hasShownFirstLaunchSplash = false }
            }
            .alert("Something went wrong", isPresented: .init(get: { auth.errorMessage != nil }, set: { if !$0 { auth.errorMessage = nil } })) { Button("OK") {} } message: { Text(auth.errorMessage ?? "Please try again.") }
            .onChange(of: auth.token, initial: true) { _, _ in Telemetry.shared.configure(client: auth.client) }
    }

    private var shouldShowFirstLaunchSplash: Bool {
        !hasShownFirstLaunchSplash && !arguments.contains("-skipFirstLaunchSplashForUITests")
    }

    private func finishFirstLaunchSplash() async {
        try? await Task.sleep(for: BrandedSplashView.minimumDuration)
        hasShownFirstLaunchSplash = true
    }
}

struct BrandedSplashView: View {
    static let minimumDuration = Duration.seconds(3)
    var body: some View {
        ZStack {
            Color("LaunchBackground").ignoresSafeArea()
            Image("LaunchIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 240)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Opening Stitchly")
        .accessibilityIdentifier("branded-splash")
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
                    VStack(spacing: 6) { Text("Stitchly").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Color.ink); Text(createAccount ? "Create your maker space." : "Welcome back, maker.").font(.title3).foregroundStyle(.secondary) }
                    VStack(spacing: 12) {
                        if createAccount { authField("Your name") { TextField("", text: $name).textContentType(.name).textInputAutocapitalization(.words).accessibilityLabel("Your name") } }
                        authField("Email address") { TextField("", text: $email).textContentType(.emailAddress).textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled().accessibilityLabel("Email address") }
                        authField("Password") { SecureField("", text: $password).textContentType(createAccount ? .newPassword : .password).accessibilityLabel("Password") }
                    }
                    Button {
                        if canSubmit { Task { await auth.authenticateWithEmail(email: email, password: password, name: createAccount ? name : nil, createAccount: createAccount) } }
                        else { auth.errorMessage = createAccount ? "Enter your name, a valid email address, and a password of at least 8 characters." : "Enter a valid email address and a password of at least 8 characters." }
                    } label: {
                        if auth.isWorking { LoadingButtonLabel(createAccount ? "Creating your account…" : "Signing you in…") }
                        else { Text(createAccount ? "Create account" : "Sign in").frame(maxWidth: .infinity) }
                    }.buttonStyle(.borderedProminent).tint(.ink).controlSize(.large).disabled(auth.isWorking)
                    Button(createAccount ? "Already have an account? Sign in" : "New here? Create an account") { withAnimation { createAccount.toggle() } }
                        .font(.subheadline.weight(.semibold)).tint(.ink).frame(minHeight: 44).contentShape(.rect).disabled(auth.isWorking)
                    HStack { Rectangle().frame(height: 1); Text("or").font(.footnote.weight(.semibold)); Rectangle().frame(height: 1) }.foregroundStyle(Color.ink.opacity(0.72))
                    SignInWithAppleButton(.continue) { auth.prepare($0) } onCompletion: { result in Task { await auth.complete(result) } }
                        .signInWithAppleButtonStyle(.black).frame(height: 54).clipShape(.rect(cornerRadius: 14)).disabled(auth.isWorking)
                    Text("Your patterns stay private and belong to you.").font(.footnote).foregroundStyle(Color.ink)
                }.padding(28).padding(.top, 24)
            }.scrollDismissesKeyboard(.interactively)
        }
    }
    private func authField<Field: View>(_ label: String, @ViewBuilder field: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Color.ink)
            field().textFieldStyle(.roundedBorder).controlSize(.large)
        }
    }
}

struct MainTabs: View {
    @State private var selection = ProcessInfo.processInfo.arguments.contains("-libraryDemo") ? 2 : (ProcessInfo.processInfo.arguments.contains("-projectsDemo") ? 1 : 0)
    var body: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house.fill", value: 0) { HomeView { selection = 1 } }
            Tab("Projects", systemImage: "square.stack.3d.up.fill", value: 1) { ProjectsView() }
            Tab("Library", systemImage: "books.vertical.fill", value: 2) { LibraryView() }
            Tab("Account", systemImage: "person.crop.circle.fill", value: 3) { AccountView() }
        }
    }
}

struct EmptyState: View {
    let icon: String; let title: String; let message: String
    var body: some View { ContentUnavailableView(title, systemImage: icon, description: Text(message)) }
}

struct ActionableEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String
    let actionIcon: String
    let isDisabled: Bool
    let action: () -> Void
    var secondaryActionTitle: String? = nil
    var secondaryActionIcon: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        } actions: {
            Button(action: action) {
                Label(actionTitle, systemImage: actionIcon)
                    .font(.headline)
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .tint(.ink)
            .controlSize(.large)
            .disabled(isDisabled)
            .accessibilityIdentifier("empty-state-primary-action")
            if let secondaryActionTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Label(secondaryActionTitle, systemImage: secondaryActionIcon ?? "doc.badge.plus")
                        .font(.headline)
                        .frame(minWidth: 180)
                }
                .buttonStyle(.bordered)
                .tint(.ink)
                .controlSize(.large)
                .disabled(isDisabled)
                .accessibilityIdentifier("empty-state-secondary-action")
            }
        }
    }
}

struct LoadingStateView: View {
    let title: String
    let message: String
    var body: some View {
        ContentUnavailableView {
            ProgressView().controlSize(.large).tint(.ink).accessibilityHidden(true)
            Text(title)
        } description: {
            Text(message)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

struct LoadingBanner: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().tint(.ink).accessibilityHidden(true)
            Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.regularMaterial, in: .capsule)
        .shadow(color: .black.opacity(0.10), radius: 12, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

struct LoadingButtonLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        HStack { ProgressView().accessibilityHidden(true); Text(text) }.frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(text)
    }
}

struct CraftBadge: View {
    let craft: String
    var body: some View { Label(craft.capitalized, systemImage: craft == "knit" ? "lines.measurement.horizontal" : "circle.hexagongrid.fill").font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6).background(Color.brandPink.opacity(0.14), in: .capsule).foregroundStyle(Color.brandPink) }
}
