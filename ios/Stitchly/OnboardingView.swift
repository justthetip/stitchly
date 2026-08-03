import SwiftUI

struct OnboardingPage: Identifiable, Equatable {
    let id: Int
    let image: String
    let title: String
    let message: String
    let accessibilityDescription: String

    static let pages = [
        OnboardingPage(
            id: 0,
            image: "OnboardingBringPatterns",
            title: "Bring patterns together",
            message: "Import private knitting and crochet PDFs into one calm, organised library.",
            accessibilityDescription: "A cheerful yarn basket safely organising pattern pages."
        ),
        OnboardingPage(
            id: 1,
            image: "OnboardingClearSteps",
            title: "Turn patterns into clear steps",
            message: "Keep the pattern maker’s sections, rows, rounds, setup and finishing—made easier to follow.",
            accessibilityDescription: "A tangled pattern becoming three clear craft instruction cards."
        ),
        OnboardingPage(
            id: 2,
            image: "OnboardingKeepPlace",
            title: "Make without losing your place",
            message: "Focus on one instruction at a time while Stitchly saves your progress and notes.",
            accessibilityDescription: "The Stitchly yarn basket knitting with a bookmark holding its place."
        )
    ]
}

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var selection = 0

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip", action: onComplete)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .frame(minHeight: 44)
                        .accessibilityHint("Shows sign in and account creation")
                }
                .padding(.horizontal, 24)

                TabView(selection: $selection) {
                    ForEach(OnboardingPage.pages) { page in
                        OnboardingPageView(page: page).tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .accessibilityLabel("Onboarding page (selection + 1) of (OnboardingPage.pages.count)")

                HStack(spacing: 8) {
                    ForEach(OnboardingPage.pages) { item in
                        Capsule()
                            .fill(item.id == selection ? Color.ink : Color.ink.opacity(0.24))
                            .frame(width: item.id == selection ? 28 : 8, height: 8)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.bottom, 18)

                HStack(spacing: 12) {
                    if selection > 0 {
                        Button { move(to: selection - 1) } label: {
                            Text("Back").frame(maxWidth: .infinity)
                        }
                            .buttonStyle(.bordered)
                            .tint(.ink)
                            .controlSize(.large)
                            .frame(maxWidth: .infinity)
                    }
                    Button {
                        if selection == OnboardingPage.pages.count - 1 { onComplete() }
                        else { move(to: selection + 1) }
                    } label: {
                        Text(selection == OnboardingPage.pages.count - 1 ? "Continue" : "Next")
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.ink)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityHint(selection == OnboardingPage.pages.count - 1 ? "Shows sign in and account creation" : "Shows the next introduction page")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .foregroundStyle(Color.ink)
    }

    private func move(to page: Int) {
        selection = page
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(page.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 28))
                    .accessibilityLabel(page.accessibilityDescription)
                    .containerRelativeFrame(.vertical) { height, _ in min(height * 0.56, 470) }

                VStack(spacing: 10) {
                    Text(page.title)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(page.message)
                        .font(.title3)
                        .foregroundStyle(Color.ink.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}
