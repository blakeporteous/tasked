import SwiftUI

import Kingfisher

struct PostGridView: View {

    @StateObject var viewModel: PostGridViewModel

    @State private var selectedMonth: MonthGroup?

    private let user: User

    init(user: User) {

        self.user = user

        self._viewModel = StateObject(wrappedValue: PostGridViewModel(user: user))

    }

    var body: some View {

        Group {

            if viewModel.isLoading && viewModel.posts.isEmpty {

                ProgressView()

                    .padding(.top, 60)

            } else if viewModel.posts.isEmpty {

                emptyState

            } else {

                monthList

            }

        }

        .fullScreenCover(item: $selectedMonth) { month in

            MonthPostsView(month: month)

        }

    }

    private var monthList: some View {

        let groups = viewModel.monthGroups

        return LazyVStack(alignment: .leading, spacing: 20) {

            ForEach(Array(groups.enumerated()), id: \.element.id) { index, month in

                if index == 0 || groups[index - 1].year != month.year {

                    yearHeader(month.year)

                        .padding(.top, index == 0 ? 0 : 4)

                }

                MonthCard(month: month)

                    .onTapGesture { selectedMonth = month }

            }

        }

        .padding(.horizontal, 16)

        .padding(.top, 8)

        .padding(.bottom, 24)

    }

    /// "2026 ⌄" — the year label with a trailing dropdown chevron, matching

    /// the reference screenshot's year picker. Not wired to anything yet

    /// (there's only ever one year's worth of data shown at a time), but the

    /// affordance reads correctly as a switcher.

    private func yearHeader(_ year: Int) -> some View {

        HStack {

            HStack(spacing: 6) {

                Text(String(year))

                    .font(.title2)

                    .fontWeight(.bold)

                Image(systemName: "chevron.down")

                    .font(.subheadline)

                    .fontWeight(.bold)

                    .foregroundStyle(.secondary)

            }

            Spacer()

            // Sits directly across from the year label — not wired up to
            // anything yet (no calendar/date-picker screen exists), just the
            // affordance for now.
            Image(systemName: "calendar")

                .font(.title3)

                .foregroundStyle(.secondary)

        }

        .padding(.leading, 4)

        .padding(.trailing, 4)

    }

    private var emptyState: some View {

        VStack(spacing: 6) {

            Image(systemName: "camera")

                .font(.system(size: 32))

                .foregroundStyle(.secondary)

            Text("No posts yet")

                .font(.headline)

            Text(user.isCurrentUser ? "Your posts will show up here." : "\(user.username) hasn't posted yet.")

                .font(.footnote)

                .foregroundStyle(.secondary)

                .multilineTextAlignment(.center)

        }

        .frame(maxWidth: .infinity)

        .padding(.top, 60)

        .padding(.horizontal, 24)

    }

}

/// One "report card" for a single calendar month: a cover photo from that

/// month, a see-through glass post-count badge (top-left) + a see-through

/// glass "..." button (top-right, both static — no shimmer), and the month

/// name spanning the card's FULL WIDTH edge-to-edge, pinned flush to the

/// card's BOTTOM edge, in see-through glass lettering.

/// Updated (Bottom-anchor pass): GlassText was previously nudged down by a

/// flat 14pt offset, which — combined with its own internal vertical

/// scaleEffect anchor — left it floating mid-card instead of actually

/// resting on the bottom edge. It's now placed inside its own

/// bottom-aligned frame that fills the full card height, so the text's

/// baseline sits right at the card's bottom regardless of font metrics,

/// with only a small deliberate bleed past that edge (cropped by the

/// card's own clipShape) for the "resting on / cut into the photo" look.

private struct MonthCard: View {

    let month: MonthGroup

    private let cardHeight: CGFloat = 240

    private let cornerRadius: CGFloat = 28

    var body: some View {

        GeometryReader { geo in

            ZStack(alignment: .bottom) {

                KFImage(URL(string: month.coverImageUrl))

                    .resizable()

                    .scaledToFill()

                    .frame(width: geo.size.width, height: cardHeight)

                    .clipped()

                LinearGradient(

                    colors: [.clear, .black.opacity(0.1), .black.opacity(0.6)],

                    startPoint: .center,

                    endPoint: .bottom

                )

                topControls

                    .frame(maxHeight: .infinity, alignment: .top)

                // Full card width, no side padding, pinned to the very

                // bottom of the card — the small `bleed` pushes it just

                // past the edge so it reads as resting on/cut into the

                // photo rather than floating safely above the bottom.

                GlassText(text: month.monthName, availableWidth: geo.size.width)

                    .frame(maxHeight: .infinity, alignment: .bottom)

                    .offset(y: bleed)

            }

            .frame(width: geo.size.width, height: cardHeight)

            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))

        }

        .frame(height: cardHeight) // gives the GeometryReader itself a fixed height

        .contentShape(Rectangle())

    }

    /// How far PAST the card's bottom edge the glass text bleeds before

    /// being clipped off by the card's own clipShape. Bumped up from 16 —

    /// at 16 there was still a sliver of gap between the letterforms and

    /// the card's actual bottom edge; this pushes it down until the

    /// glyphs themselves are what's getting cropped, which reads as

    /// "resting on the bottom" rather than "hovering just above it."

    private let bleed: CGFloat = 26

    /// Native backdrop pattern: a real glass capsule/circle placed BEHIND

    /// plain text/icon content via .glassEffect(in:). Static — no shimmer

    /// or other animation on these.

    @ViewBuilder

    private var topControls: some View {

        if #available(iOS 26.0, *) {

            GlassEffectContainer(spacing: 12) {

                HStack {

                    Text("\(month.posts.count) post\(month.posts.count == 1 ? "" : "s")")

                        .font(.footnote)

                        .fontWeight(.semibold)

                        .foregroundStyle(.white)

                        .padding(.horizontal, 12)

                        .padding(.vertical, 6)

                        .glassEffect(.clear.tint(.white.opacity(0.12)), in: Capsule())

                    Spacer()

                    Button {

                        // Hook up a real menu (share month, hide month, etc.) later.

                    } label: {

                        Image(systemName: "ellipsis")

                            .font(.footnote)

                            .fontWeight(.bold)

                            .foregroundStyle(.white)

                            .frame(width: 32, height: 32)

                    }

                    .glassEffect(.clear.tint(.white.opacity(0.12)), in: Circle())

                }

            }

            .padding(16)

        } else {

            // Pre-iOS 26 fallback — thin material approximation.

            HStack {

                Text("\(month.posts.count) post\(month.posts.count == 1 ? "" : "s")")

                    .font(.footnote)

                    .fontWeight(.semibold)

                    .foregroundStyle(.white)

                    .padding(.horizontal, 12)

                    .padding(.vertical, 6)

                    .background(.thinMaterial.opacity(0.5), in: Capsule())

                    .overlay(Capsule().stroke(.white.opacity(0.35), lineWidth: 0.75))

                Spacer()

                Button {

                } label: {

                    Image(systemName: "ellipsis")

                        .font(.footnote)

                        .fontWeight(.bold)

                        .foregroundStyle(.white)

                        .frame(width: 32, height: 32)

                        .background(.thinMaterial.opacity(0.5), in: Circle())

                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 0.75))

                }

            }

            .padding(16)

        }

    }

}

/// Glyph shape pattern: the month name's letterforms themselves become the

/// glass, via GlyphTextShape + .glassEffect(in:) — not a material masked to

/// a rendered Text view. See-through/translucent tint (matches the top

/// controls' badges) and spans `availableWidth` edge-to-edge, scaling with a

/// BOTTOM anchor so growth/shrink never moves the text's own baseline — the

/// parent (MonthCard) is what actually pins it to the card's bottom edge.

private struct GlassText: View {

    let text: String

    let availableWidth: CGFloat

    var fontSize: CGFloat = 78

    private let tracking: CGFloat = 0.5

    /// How much of `availableWidth` the glyphs actually occupy AFTER the

    /// scaleEffect below is applied — i.e. the real, final on-screen fill.

    /// 0.97 reads as "edge-to-edge with a hair of breathing room" rather

    /// than true 1.0 (which can make the glyphs look like they're clipping

    /// into the card's rounded corners on some month names).

    private let horizontalFillFraction: CGFloat = 0.97

    /// Condensed width trait makes each letterform taller-relative-to-width

    /// on its own, before any extra scaling is applied.

    private var uiFont: UIFont {

        UIFont.systemFont(ofSize: fontSize, weight: .heavy, width: .condensed)

    }

    /// Natural (unconstrained) size of the glyphs at `fontSize`.

    private var naturalSize: CGSize {

        let attributed = NSAttributedString(string: text, attributes: [

            .font: uiFont,

            .kern: tracking

        ])

        let size = attributed.size()

        return CGSize(width: size.width + 4, height: size.height + 10)

    }

    /// Scaled so that, once the horizontal scaleEffect in `body` is applied

    /// on top of this, the glyphs land at `horizontalFillFraction` of

    /// `availableWidth` — i.e. properly edge-to-edge, on any length of

    /// month name.

    private var fittedSize: CGSize {

        let natural = naturalSize

        guard natural.width > 0, availableWidth > 0 else { return natural }

        let targetWidth = availableWidth / horizontalFillFraction

        let scale = targetWidth / natural.width

        return CGSize(width: targetWidth, height: natural.height * scale)

    }

    var body: some View {

        Group {

            if #available(iOS 26.0, *) {

                Color.clear

                    .frame(width: fittedSize.width, height: fittedSize.height)

                    // .clear (not .regular) + a partial-opacity white tint is

                    // what makes this genuinely SEE-THROUGH — the photo behind

                    // the letterforms shows through the glass, refracted,

                    // rather than the glyphs reading as a solid frosted-white

                    // cutout. Same tint style as the top controls' badges.

                    .glassEffect(

                        .clear.tint(.white.opacity(0.35)),

                        in: GlyphTextShape(text: text, font: uiFont, tracking: tracking)

                    )

                    // Extra vertical stretch on top of the condensed font —

                    // anchored at .bottom so the BASELINE stays put while

                    // the letterforms grow taller upward from it. The x

                    // term here is intentionally close to 1 now (matches

                    // horizontalFillFraction) — fittedSize already did the

                    // real width-fitting work above.

                    .scaleEffect(x: horizontalFillFraction, y: 1.22, anchor: .bottom)

            } else {

                // No real refraction pre-iOS 26 — approximated with a

                // translucent (not fully opaque) white fill so it at least

                // reads as "see-through" rather than solid.

                Text(text)

                    .font(.system(size: fontSize, weight: .heavy, design: .rounded))

                    .tracking(tracking)

                    .lineLimit(1)

                    .minimumScaleFactor(0.3)

                    .foregroundStyle(.white.opacity(0.55))

                    .frame(width: fittedSize.width, alignment: .center)

                    .scaleEffect(x: horizontalFillFraction, y: 1.22, anchor: .bottom)

            }

        }

        .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

    }

}

#Preview {

    ScrollView { PostGridView(user: User.MOCK_USERS[0]) }

}
