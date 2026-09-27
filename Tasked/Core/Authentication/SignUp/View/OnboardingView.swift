//
//  OnboardingView.swift
//  Tasked
//
//  New: a short first-launch tour shown once after sign-up, before the
//  person lands on MainTabView. Presented by ContentView as a
//  fullScreenCover, gated on an @AppStorage flag so it only ever shows once
//  per device.
//
//  DESIGN NOTE: SplashView's dot animation (swoop along a curve + grow to
//  fill the screen) is tightly tuned to one specific full-screen transition
//  — it doesn't generalize well to "move between N arbitrary points,
//  N times, driven by swipes." Rather than force-fit that, this reuses the
//  same accent-blue dot in a simpler, standard pattern: a page indicator
//  row where the filled dot animates (via matchedGeometryEffect) to
//  whichever page you're on, instead of just snapping or being separately
//  colored circles. Still reads as "the blue dot moving around," just a
//  lighter-weight animation than the splash screen's.
//

import SwiftUI

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
}

struct OnboardingView: View {
    /// Called when the person taps "Get Started" on the last page, or "Skip".
    var onFinished: () -> Void = {}

    @State private var currentPage = 0
    @Namespace private var dotSpace

    private let dotColor = Color.appAccent

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "house.fill",
            title: "Your Feed",
            description: "See what your friends are up to and cheer them on as they complete this week's task."
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            title: "A New Task Every Week",
            description: "Each week brings a fresh task. Complete it and share a photo to keep your streak alive."
        ),
        OnboardingPage(
            icon: "magnifyingglass",
            title: "Find Friends",
            description: "Search for people you know and send a friend request to start following along."
        ),
        OnboardingPage(
            icon: "person.fill",
            title: "Your Profile",
            description: "Track your streak, browse your past posts, and manage your account — all in one place."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxHeight: 360)

            // Custom page indicator — a single blue dot that animates to
            // whichever page is selected, rather than static colored dots.
            HStack(spacing: 14) {
                ForEach(pages.indices, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 8, height: 8)

                        if index == currentPage {
                            Circle()
                                .fill(dotColor)
                                .frame(width: 12, height: 12)
                                .matchedGeometryEffect(id: "onboardingDot", in: dotSpace)
                        }
                    }
                    .frame(width: 14, height: 14)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: currentPage)
            .padding(.top, 8)

            Spacer()

            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    onFinished()
                }
            } label: {
                Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                    .inkButton()
            }
            .padding(.horizontal, 24)

            if currentPage < pages.count - 1 {
                Button("Skip") {
                    onFinished()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
            }

            Spacer()
                .frame(height: 24)
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 20) {
            Image(systemName: page.icon)
                .font(.system(size: 64))
                .foregroundStyle(dotColor)

            Text(page.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(page.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    OnboardingView()
}
