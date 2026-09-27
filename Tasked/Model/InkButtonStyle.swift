//
//  InkButtonStyle.swift
//  Tasked
//
//  New: shared "ink block" button chrome — bold, flat, black/white with a
//  small offset hard shadow. Mirrors IGTextFieldModifier's pattern: apply as
//  a plain modifier to whatever Text/ProgressView sits inside a Button or
//  NavigationLink's label, rather than restyling every CTA by hand.
//  Replaces the old per-screen `.frame(width: 360, height: 44).background
//  (Color(.systemBlue)).cornerRadius(8)` pattern used across onboarding,
//  login, post upload, and friend actions.
//  Updated (Brand color pass): primary fill switched from black to a warm
//  orange/red (matches the app's new "START FREE TRIAL"-style CTA color).
//  Updated (Poster-block pass): squared off corners (no rounding), a heavy
//  black outline on BOTH primary and secondary now (previously only
//  secondary had one), and the drop shadow is now solid black and larger/
//  more offset — reads as a bolder, more poster-like block overall.
//  Updated (Disabled-opacity fix): `.opacity(isDisabled ? 0.5 : 1)` was
//  applied AFTER stacking the fill/outline on top of the black shadow
//  layer — but SwiftUI doesn't automatically flatten that stack into one
//  image before dimming it, so each layer's opacity was reduced
//  independently, letting the fully-opaque black shadow show through the
//  now-translucent fill wherever the two overlapped (e.g. "Next" on
//  AddEmailView while disabled). Added `.compositingGroup()` right before
//  `.opacity(...)`, which forces the fill+outline+shadow to render as one
//  flattened image FIRST, so the opacity dims the whole button as a single
//  unit instead of bleeding the shadow color into it.
//  Updated (Liquid Glass pass): retired the squared, hard-shadowed "ink
//  block" look entirely — replaced with a rounded, translucent Liquid Glass
//  treatment (real `.glassEffect` on iOS 26+, a tinted frosted-material
//  approximation on earlier versions). No more black outline or hard offset
//  shadow anywhere `inkButton()` is used. Also extracted `glassCard
//  (cornerRadius:tint:)` as a shared View extension so other surfaces that
//  used to hand-roll the same squared chrome — WeeklyTaskBannerView and
//  UploadPostView's matching "THIS WEEK'S TASK" card — can share this exact
//  look instead of drifting out of sync with it.
//

import SwiftUI

enum InkButtonStyleKind {
    case primary
    case secondary
}

struct InkButtonModifier: ViewModifier {
    var style: InkButtonStyleKind = .primary
    var isDisabled: Bool = false

    /// The app's primary CTA color.
    private static let primaryFillColor = Color(red: 191.0 / 255.0, green: 53.0 / 255.0, blue: 44.0 / 255.0)

    private let cornerRadius: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .fontWeight(.bold)
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .glassCard(cornerRadius: cornerRadius, tint: fill)
            .compositingGroup()
            .opacity(isDisabled ? 0.5 : 1)
    }

    private var fill: Color {
        style == .primary ? Self.primaryFillColor : Color.white
    }

    private var foreground: Color {
        style == .primary ? .white : .black
    }
}

extension View {
    /// Full-width Liquid Glass CTA chrome. `.primary` (warm red/orange
    /// tint) is the default for the main action on a screen; `.secondary`
    /// (light tint) is for a lesser action sitting next to it (e.g.
    /// "Decline" beside "Accept"). `isDisabled` dims it without needing a
    /// separate disabled-state copy of the view — most call sites in this
    /// app swap between a real NavigationLink/Button and a plain inert Text
    /// depending on form validity, and both branches can share this same
    /// modifier.
    func inkButton(_ style: InkButtonStyleKind = .primary, isDisabled: Bool = false) -> some View {
        modifier(InkButtonModifier(style: style, isDisabled: isDisabled))
    }

    /// Shared rounded, translucent Liquid Glass card background — real
    /// `.glassEffect` on iOS 26+, a tinted `.ultraThinMaterial` + soft
    /// shadow approximation on earlier versions. Backs `inkButton()` above,
    /// WeeklyTaskBannerView, and UploadPostView's matching "THIS WEEK'S
    /// TASK" card — every surface that used to independently copy the old
    /// squared ink-block chrome now shares this one implementation instead.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat, tint: Color) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.tint(tint), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.85))
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 6)
        }
    }
}
