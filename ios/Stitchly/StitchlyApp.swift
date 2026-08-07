import SwiftUI
import AuthenticationServices
import FirebaseCore

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main struct StitchlyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
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
            else if arguments.contains("-showAuthForUITests") { SignInView() }
            else if arguments.contains("-projectOverviewDemo") { NavigationStack { ProjectOverviewView(project: DemoData.projectWithLocalProgress) {} } }
            else if ProcessInfo.processInfo.arguments.contains("-patternDemo") { NavigationStack { PatternDetailView(pattern: DemoData.pattern) } }
            else if ProcessInfo.processInfo.arguments.contains("-readerSectionsDemo") { NavigationStack { ReaderView(project: DemoData.projectWithLocalProgress, showSectionsInitially: true) } }
            else if ProcessInfo.processInfo.arguments.contains("-readerRepeatDemo") { NavigationStack { ReaderView(project: DemoData.repeatProject) } }
            else if ProcessInfo.processInfo.arguments.contains("-readerDemo") { NavigationStack { ReaderView(project: DemoData.projectWithLocalProgress) } }
            else { MainTabs() }
        }
            .onAppear {
                if arguments.contains("-resetOnboardingForUITests") { hasCompletedOnboarding = false }
                if arguments.contains("-resetFirstLaunchSplashForUITests") { hasShownFirstLaunchSplash = false }
            }
            .alert("Something went wrong", isPresented: .init(get: { auth.errorMessage != nil }, set: { if !$0 { auth.errorMessage = nil } })) { Button("OK") {} } message: { Text(auth.errorMessage ?? "Please try again.") }
            .sheet(item: $auth.authenticationRequest) { request in
                NavigationStack {
                    SignInView(
                        contextTitle: request.title,
                        contextMessage: request.message,
                        showsCancel: true
                    )
                    .onChange(of: auth.user?.id) { _, userID in
                        if userID != nil { auth.dismissAuthenticationRequest() }
                    }
                }
            }
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
    private enum AuthField: String, Hashable {
        case name
        case email
        case password
    }

    @EnvironmentObject private var auth: AuthManager
    @FocusState private var focusedField: AuthField?
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var createAccount = true
    @State private var emailExpanded = ProcessInfo.processInfo.arguments.contains("-authSubmittingDemo")
    @State private var showPassword = false
    @State private var hasAttemptedSubmit = false
    @State private var isSubmitting = ProcessInfo.processInfo.arguments.contains("-authSubmittingDemo")
    let contextTitle: String?
    let contextMessage: String?
    let showsCancel: Bool

    init(contextTitle: String? = nil, contextMessage: String? = nil, showsCancel: Bool = false) {
        self.contextTitle = contextTitle
        self.contextMessage = contextMessage
        self.showsCancel = showsCancel
    }

    private var nameIsInvalid: Bool { createAccount && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var emailIsInvalid: Bool { !email.contains("@") }
    private var passwordIsInvalid: Bool { password.count < 8 }
    private var canSubmit: Bool { !nameIsInvalid && !emailIsInvalid && !passwordIsInvalid }
    private var isWorking: Bool { auth.isWorking || isSubmitting }
    private var validationMessage: String? {
        guard hasAttemptedSubmit else { return nil }
        var messages: [String] = []
        if nameIsInvalid { messages.append("Enter your name") }
        if emailIsInvalid { messages.append("Enter a valid email address") }
        if passwordIsInvalid { messages.append("Use at least 8 characters for your password") }
        return messages.isEmpty ? nil : messages.joined(separator: ". ") + "."
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.cream, .white, .brandPink.opacity(0.16)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    if !emailExpanded {
                        Image("BrandIcon").resizable().scaledToFit().frame(width: 82, height: 82).clipShape(.rect(cornerRadius: 20)).shadow(color: .brandPink.opacity(0.2), radius: 16, y: 8)
                        Text("Stitchly").font(.system(.largeTitle, design: .rounded, weight: .bold)).foregroundStyle(Color.ink)
                    }
                    if let contextTitle {
                        Label(contextTitle, systemImage: "icloud.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.center)
                            .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.72), in: .rect(cornerRadius: 16))
                        .accessibilityElement(children: .combine)
                        .accessibilityHint(contextMessage ?? "")
                        .accessibilityIdentifier("authentication-context")
                    } else if !emailExpanded {
                        Text("Save your projects and pick up anywhere.")
                            .font(.subheadline)
                            .foregroundStyle(Color.ink)
                    }
                    if emailExpanded {
                        HStack {
                            Button {
                                guard !isWorking else { return }
                                focusedField = nil
                                withAnimation { emailExpanded = false }
                            } label: {
                                Label("Sign-in options", systemImage: "chevron.left")
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 44)
                                    .contentShape(.capsule)
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .background(Color.white.opacity(0.82), in: .capsule)
                            .overlay {
                                Capsule().stroke(Color.ink.opacity(0.12), lineWidth: 1)
                            }
                            .buttonStyle(.plain)
                            .disabled(isWorking)
                            .accessibilityLabel("Back to sign-in options")
                            .accessibilityIdentifier("back-to-sign-in-options")
                            Spacer(minLength: 0)
                        }
                        Button(createAccount ? "Already have an account? Sign in" : "New here? Create an account", action: toggleMode)
                            .font(.subheadline.weight(.semibold))
                            .tint(.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(.rect)
                            .disabled(isWorking)
                        VStack(spacing: 12) {
                            if createAccount {
                                authField("Your name", icon: "person", focus: .name, isInvalid: hasAttemptedSubmit && nameIsInvalid) {
                                    TextField("", text: $name)
                                        .textContentType(.name)
                                        .textInputAutocapitalization(.words)
                                        .submitLabel(.next)
                                        .padding(.vertical, 16)
                                        .focused($focusedField, equals: .name)
                                        .onSubmit { focusedField = .email }
                                        .accessibilityLabel("Your name")
                                        .accessibilityHint(hasAttemptedSubmit && nameIsInvalid ? "Required" : "")
                                        .accessibilityIdentifier("auth-name-field")
                                }
                            }
                            authField("Email address", icon: "envelope", focus: .email, isInvalid: hasAttemptedSubmit && emailIsInvalid) {
                                TextField("", text: $email)
                                    .textContentType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .submitLabel(.next)
                                    .padding(.vertical, 16)
                                    .focused($focusedField, equals: .email)
                                    .onSubmit { focusedField = .password }
                                    .accessibilityLabel("Email address")
                                    .accessibilityHint(hasAttemptedSubmit && emailIsInvalid ? "Enter a valid email address" : "")
                                    .accessibilityIdentifier("auth-email-field")
                            }
                            authField("Password", icon: "lock", focus: .password, isInvalid: hasAttemptedSubmit && passwordIsInvalid) {
                                HStack(spacing: 4) {
                                    Group {
                                        if showPassword { TextField("", text: $password) }
                                        else { SecureField("", text: $password) }
                                    }
                                    .textContentType(createAccount ? .newPassword : .password)
                                    .submitLabel(.go)
                                    .padding(.vertical, 16)
                                    .focused($focusedField, equals: .password)
                                    .onSubmit(submit)
                                    .accessibilityLabel("Password")
                                    .accessibilityHint(hasAttemptedSubmit && passwordIsInvalid ? "Use at least 8 characters" : "")
                                    .accessibilityIdentifier("auth-password-field")
                                    Button {
                                        showPassword.toggle()
                                        Task { await Task.yield(); focusedField = .password }
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .font(.system(size: 20, weight: .semibold))
                                            .frame(width: 48, height: 48)
                                            .contentShape(.rect)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(Color.ink)
                                    .accessibilityLabel(showPassword ? "Hide password" : "Show password")
                                    .accessibilityIdentifier("toggle-password-visibility")
                                }
                            }
                            if let validationMessage {
                                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .accessibilityIdentifier("auth-validation-message")
                            }
                        }
                        Button(action: submit) {
                            AuthSubmitButtonLabel(
                                idleText: createAccount ? "Create account" : "Sign in",
                                loadingText: createAccount ? "Creating your account…" : "Signing you in…",
                                isLoading: isWorking
                            )
                        }
                        .buttonStyle(.borderedProminent).tint(.ink).controlSize(.large)
                        .allowsHitTesting(!isWorking)
                        .accessibilityIdentifier("auth-submit-button")
                    } else {
                        SignInWithAppleButton(.continue) { auth.prepare($0) } onCompletion: { result in Task { await auth.complete(result) } }
                            .signInWithAppleButtonStyle(.black).frame(height: 54).clipShape(.rect(cornerRadius: 14)).disabled(isWorking)
                        Button {
                            withAnimation { emailExpanded = true }
                        } label: {
                            Label("Continue with email", systemImage: "envelope.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.ink)
                        .controlSize(.large)
                        .disabled(isWorking)
                        .accessibilityIdentifier("continue-with-email")
                    }
                    Text("Your patterns stay private and belong to you.").font(.footnote).foregroundStyle(Color.ink)
                }.padding(28).padding(.top, 12)
            }
            .accessibilityIdentifier("auth-scroll-view")
            .scrollDismissesKeyboard(.immediately)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if focusedField != nil {
                    HStack {
                        Text("Keyboard")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    Spacer()
                    Button("Done") { focusedField = nil }
                        .accessibilityIdentifier("auth-keyboard-done")
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(.bar)
                }
            }
            .toolbar {
                if showsCancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { auth.dismissAuthenticationRequest() }
                            .disabled(isWorking)
                    }
                }
            }
        }
    }

    private func authField<Field: View>(_ label: String, icon: String, focus: AuthField, isInvalid: Bool, @ViewBuilder field: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Color.ink)
            HStack(spacing: 12) {
                Image(systemName: isInvalid ? "exclamationmark.circle.fill" : icon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 22)
                    .foregroundStyle(isInvalid ? .red : Color.ink)
                    .accessibilityHidden(true)
                field()
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
            .padding(.horizontal, 14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isInvalid ? Color.red : (focusedField == focus ? Color.brandPink : Color.ink.opacity(0.18)), lineWidth: isInvalid || focusedField == focus ? 2 : 1)
            }
            .contentShape(.rect)
            .onTapGesture { focusedField = focus }
        }
    }

    private func toggleMode() {
        guard !isWorking else { return }
        let willCreateAccount = !createAccount
        withAnimation {
            createAccount = willCreateAccount
            hasAttemptedSubmit = false
        }
        focusedField = willCreateAccount ? .name : .email
    }

    private func submit() {
        guard !isWorking else { return }
        hasAttemptedSubmit = true
        guard canSubmit else {
            focusedField = nameIsInvalid ? .name : (emailIsInvalid ? .email : .password)
            return
        }
        focusedField = nil
        isSubmitting = true
        Task {
            await auth.authenticateWithEmail(email: email, password: password, name: createAccount ? name : nil, createAccount: createAccount)
            isSubmitting = false
        }
    }
}

struct MainTabs: View {
    @State private var selection = ProcessInfo.processInfo.arguments.contains("-libraryDemo") ? 1 : 0
    var body: some View {
        TabView(selection: $selection) {
            Tab("Projects", systemImage: "square.stack.3d.up.fill", value: 0) { ProjectsView { selection = 1 } }
            Tab("Library", systemImage: "books.vertical.fill", value: 1) { LibraryView() }
            Tab("Account", systemImage: "person.crop.circle.fill", value: 2) { AccountView() }
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isPresented = false
    @State private var isAnimating = false

    private var artworkCanvasSize: CGFloat { dynamicTypeSize.isAccessibilitySize ? 164 : 196 }
    private var spinnerSize: CGFloat { dynamicTypeSize.isAccessibilitySize ? 152 : 180 }
    private var spinnerRadius: CGFloat { spinnerSize / 2 - 8 }
    private let stitchColors: [Color] = [.brandPink, .brandBlue, .ink, .brandOrange]

    var body: some View {
        VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 10 : 14) {
            ZStack {
                ZStack {
                    ForEach(0..<10, id: \.self) { index in
                        Capsule()
                            .fill(stitchColors[index % stitchColors.count])
                            .frame(width: index.isMultiple(of: 2) ? 15 : 9, height: 5)
                            .offset(y: -spinnerRadius)
                            .rotationEffect(.degrees(Double(index) * 36))
                    }
                }
                .frame(width: spinnerSize, height: spinnerSize)
                .rotationEffect(.degrees(reduceMotion ? 0 : (isAnimating ? 360 : 0)))
                .animation(reduceMotion ? nil : .linear(duration: 1.8).repeatForever(autoreverses: false), value: isAnimating)
                .accessibilityHidden(true)

                Image("LoadingStitch")
                    .resizable()
                    .scaledToFit()
                    .frame(width: artworkCanvasSize, height: artworkCanvasSize)
                    .shadow(color: .white.opacity(0.9), radius: 3)
                    .shadow(color: Color.ink.opacity(0.14), radius: 8, y: 5)
                    .scaleEffect(reduceMotion ? 1 : (isAnimating ? 1.02 : 0.99))
                    .offset(y: reduceMotion ? 5 : (isAnimating ? 2 : 8))
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
                    .accessibilityHidden(true)
            }
            .frame(width: spinnerSize, height: spinnerSize)

            Text(title)
                .font(.headline)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .shadow(color: Color(.systemBackground), radius: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
        .opacity(isPresented ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityIdentifier("branded-loading-state")
        .accessibilityHidden(!isPresented)
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            if reduceMotion {
                isPresented = true
            } else {
                withAnimation(.easeOut(duration: 0.2)) { isPresented = true }
                isAnimating = true
            }
        }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in
            isAnimating = !shouldReduceMotion && isPresented
        }
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

struct AuthSubmitButtonLabel: View {
    let idleText: String
    let loadingText: String
    let isLoading: Bool

    var body: some View {
        ZStack {
            Text(idleText)
                .opacity(isLoading ? 0 : 1)
            HStack(spacing: 10) {
                InlineStitchSpinner()
                Text(loadingText)
            }
            .opacity(isLoading ? 1 : 0)
        }
        .font(.headline)
        .frame(maxWidth: .infinity, minHeight: 24)
        .animation(.easeInOut(duration: 0.18), value: isLoading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLoading ? loadingText : idleText)
    }
}

private struct InlineStitchSpinner: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false
    private let colors: [Color] = [.white, .brandOrange, .brandPink, .brandBlue]

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(colors[index % colors.count])
                    .frame(width: 6, height: 2.5)
                    .offset(y: -8)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
        }
        .frame(width: 24, height: 24)
        .rotationEffect(.degrees(reduceMotion ? 0 : (isAnimating ? 360 : 0)))
        .animation(reduceMotion ? nil : .linear(duration: 1.25).repeatForever(autoreverses: false), value: isAnimating)
        .onAppear { isAnimating = !reduceMotion }
        .onChange(of: reduceMotion) { _, shouldReduceMotion in isAnimating = !shouldReduceMotion }
        .accessibilityHidden(true)
    }
}

struct CraftBadge: View {
    let craft: String
    var body: some View { Label(craft.capitalized, systemImage: craft == "knit" ? "lines.measurement.horizontal" : "circle.hexagongrid.fill").font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 6).background(Color.brandPink.opacity(0.14), in: .capsule).foregroundStyle(Color.brandPink) }
}
