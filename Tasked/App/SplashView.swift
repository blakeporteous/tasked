//
//  SplashView.swift
//  Tasked
//
//  Rewritten (Launch animation pass): the static breathing-icon splash is
//  replaced with the actual "Tasked." wordmark, followed by an animation of
//  its trailing dot: it swoops along a curved path — growing the whole time
//  it travels, not after arriving — until it's swallowed the entire screen
//  in blue. Calls `onFinished()` right as that completes (screen is fully
//  blue at that point) so the caller can swap in real content underneath
//  with a quick crossfade rather than a jarring cut.
//
//  Updated (Size + curved-motion pass):
//  - logoAspectRatio is now read from the actual bundled "Logo" asset via
//    UIImage(named:) at runtime instead of a hardcoded guess based on a
//    reference export.
//  - The dot's motion (position along a quadratic Bézier curve) and its
//    scale-up are both driven by a single animated `progress` value (0...1),
//    via FlyingDot below.
//  Updated (Decoupled easing pass): position and scale used to share the
//  exact same progress curve, which meant scale ballooned almost as fast as
//  the dot moved — visually the growth swallowed the swoop entirely within
//  the first ~30% of the animation, so it just read as "expanding," no
//  visible curve. FlyingDot now applies two SEPARATE easing curves to the
//  same underlying linear `progress`: position uses a gentle smoothstep (so
//  the arc stays visible across most of the timeline), while scale is
//  raised to `scaleEasePower` (currently 3.2) — staying nearly flat at
//  first, then rocketing up right at the end. That's what gives the
//  "swoops along the curve, THEN rapidly pops to fill the screen" feel,
//  driven by one continuous animation rather than sequential steps.
//
//  How the dot overlay lines up with the baked-in dot in the logo artwork:
//  the "Logo" asset is a flat image with the wordmark AND the dot painted
//  into it as one image — there's no separate dot asset to animate. So a
//  real SwiftUI Circle is drawn in the exact position/size/color of that
//  painted-in dot (measured directly from the asset — see calibration
//  below), sitting invisibly on top of it at rest. When the animation
//  starts, the wordmark fades away and this Circle is what's actually seen
//  moving/growing — from the viewer's perspective it reads as "the dot
//  detaches and takes over."
//
//  CALIBRATION: dotCenterFraction/dotRadiusFractionOfWidth/dotColor below
//  were measured from a reference export of the logo artwork. These are
//  FRACTIONS of the logo's own width/height, so they hold regardless of
//  what resolution the bundled asset is — but only as long as the bundled
//  asset has the same composition/padding as that reference. If a re-export
//  ever changes the padding around the wordmark, re-measure these three.
//
//  Updated (Full-coverage pass): the circle was landing just short of
//  fully covering the screen on some sizes — the overshoot multiplier in
//  scaleNeededToCoverScreen (how much bigger than "exactly reaches the
//  farthest corner" the final circle grows) was bumped from 1.15 to 1.3 for
//  a bigger safety margin, and swoopDuration was nudged up slightly
//  (0.75s -> 0.85s) so the growth has a touch more time to read clearly
//  before onFinished() fires.
//

import SwiftUI

struct SplashView: View {

    /// Called once the full sequence (static logo -> dot swoops out -> full
    /// screen blue) has finished. The screen is already 100% solid blue at
    /// the moment this fires, so whatever the caller shows next can
    /// crossfade in over it with no visible seam.
    var onFinished: () -> Void = {}

    // MARK: - Calibration (fractions of the logo artwork's own dimensions)

    private let dotCenterFraction = CGPoint(x: 0.95, y: 0.671)
    private let dotRadiusFractionOfWidth: CGFloat = 0.0369
    private let dotColor = Color.appAccent

    /// Display width of the wordmark. Tune freely — height follows
    /// automatically from the real asset's aspect ratio (see
    /// logoAspectRatio below).
    private let logoDisplayWidth: CGFloat = 260

    /// Reads the ACTUAL bundled asset's real pixel aspect ratio at runtime
    /// rather than assuming one, so this keeps working correctly even if
    /// the asset is ever re-exported at a different resolution (confirmed
    /// currently 400x120, matching the calibration below).
    private var logoAspectRatio: CGFloat {
        guard let uiImage = UIImage(named: "Logo"), uiImage.size.height > 0 else {
            return 400.0 / 120.0 // fallback only if the asset can't be found
        }
        return uiImage.size.width / uiImage.size.height
    }

    // MARK: - Timing (seconds)

    private let holdDuration = 0.9
    private let logoFadeDuration = 0.3
    private let swoopDuration = 0.85

    /// How aggressively the SCALE curve is back-loaded relative to the
    /// POSITION curve — see FlyingDot below. Higher = the dot stays smaller
    /// for longer before rocketing up at the very end (more "exponential").
    private let scaleEasePower: CGFloat = 3.2

    // MARK: - How much the path bows into a curve

    /// How far the curve's control point is pushed away from the straight
    /// line between start and end, as a fraction of the screen's smaller
    /// dimension. Bigger = more pronounced arc.
    private let curveBulge: CGFloat = 0.22

    // MARK: - Animated state

    @State private var progress: CGFloat = 0 // 0 = resting on the wordmark, 1 = fully covers the screen
    @State private var logoOpacity: Double = 1

    var body: some View {
        GeometryReader { geo in
            let screenSize = geo.size
            let logoHeight = logoDisplayWidth / logoAspectRatio
            let logoOrigin = CGPoint(
                x: (screenSize.width - logoDisplayWidth) / 2,
                y: (screenSize.height - logoHeight) / 2
            )
            let dotRadius = logoDisplayWidth * dotRadiusFractionOfWidth
            let restingDotCenter = CGPoint(
                x: logoOrigin.x + dotCenterFraction.x * logoDisplayWidth,
                y: logoOrigin.y + dotCenterFraction.y * logoHeight
            )
            // Where the dot ends up before/while it swallows the screen —
            // down and to the left of the logo. Tune freely.
            let flownCenter = CGPoint(x: screenSize.width * 0.28, y: screenSize.height * 0.78)

            let control = curveControlPoint(from: restingDotCenter, to: flownCenter, screenSize: screenSize)
            let finalScale = scaleNeededToCoverScreen(from: flownCenter, screenSize: screenSize, dotRadius: dotRadius)

            ZStack {
                Color.white.ignoresSafeArea()

                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: logoDisplayWidth)
                    .position(x: screenSize.width / 2, y: screenSize.height / 2)
                    .opacity(logoOpacity)

                FlyingDot(
                    progress: progress,
                    start: restingDotCenter,
                    control: control,
                    end: flownCenter,
                    startScale: 1,
                    endScale: finalScale,
                    scaleEasePower: scaleEasePower,
                    color: dotColor,
                    baseDiameter: dotRadius * 2
                )
            }
            .onAppear {
                runSequence()
            }
        }
        .ignoresSafeArea()
    }

    /// Offsets the midpoint of the straight start->end line perpendicular to
    /// that line, so the quadratic Bézier bows into a real arc instead of a
    /// straight shot. The offset is biased down-and-left so the curve reads
    /// as swooping rather than a mechanical corner.
    private func curveControlPoint(from start: CGPoint, to end: CGPoint, screenSize: CGSize) -> CGPoint {
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        let bulge = min(screenSize.width, screenSize.height) * curveBulge
        return CGPoint(x: mid.x - bulge, y: mid.y + bulge)
    }

    /// The scale that makes a circle centered at `from` reach (and
    /// overshoot) the single farthest screen corner, so the final frame is
    /// solid blue edge-to-edge on any device size.
    private func scaleNeededToCoverScreen(from center: CGPoint, screenSize: CGSize, dotRadius: CGFloat) -> CGFloat {
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: screenSize.width, y: 0),
            CGPoint(x: 0, y: screenSize.height),
            CGPoint(x: screenSize.width, y: screenSize.height)
        ]
        let maxDistance = corners
            .map { hypot($0.x - center.x, $0.y - center.y) }
            .max() ?? max(screenSize.width, screenSize.height)
        return (maxDistance / dotRadius) * 1.3 // bigger overshoot so no edge is ever left uncovered
    }

    private func runSequence() {
        Task {
            // 1. Hold the static logo for a beat.
            try? await Task.sleep(nanoseconds: UInt64(holdDuration * 1_000_000_000))

            // 2. Fade the wordmark out quickly...
            withAnimation(.easeOut(duration: logoFadeDuration)) {
                logoOpacity = 0
            }

            // 3. ...while the dot swoops along its curve AND grows, in one
            // continuous motion, ending in full-screen blue. Driven LINEARLY
            // in time — FlyingDot applies its own separate easing curves to
            // position vs. scale internally, so an outer easeIn here would
            // just distort both of those on top of each other.
            withAnimation(.linear(duration: swoopDuration)) {
                progress = 1
            }

            try? await Task.sleep(nanoseconds: UInt64(swoopDuration * 1_000_000_000))
            onFinished()
        }
    }
}

/// A circle whose position (along a quadratic Bézier curve) and scale are
/// both driven by a single `progress` value, so SwiftUI's animation system
/// interpolates the whole swoop-and-grow motion smoothly frame by frame —
/// rather than treating "move" and "grow" as two separate, sequential steps.
private struct FlyingDot: View, Animatable {
    var progress: CGFloat
    let start: CGPoint
    let control: CGPoint
    let end: CGPoint
    let startScale: CGFloat
    let endScale: CGFloat
    /// Exponent applied to progress before it drives scale — see `scale`
    /// below. Higher = growth stays suppressed longer, then rockets up
    /// harder at the very end ("exponential").
    let scaleEasePower: CGFloat
    let color: Color
    let baseDiameter: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// Position uses a gentle ease (smoothstep: slow-fast-slow) on the RAW
    /// progress, so the curve is still clearly visible across most of the
    /// timeline — it isn't fighting with a scale curve that's ballooning at
    /// the same rate.
    private var positionT: CGFloat {
        progress * progress * (3 - 2 * progress)
    }

    /// Point on the quadratic Bézier curve (start -> control -> end) at `positionT`.
    private var position: CGPoint {
        let t = positionT
        let mt = 1 - t
        return CGPoint(
            x: mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x,
            y: mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
        )
    }

    /// Scale uses progress raised to a power — this is what makes growth
    /// stay small/flat for most of the animation and then shoot up rapidly
    /// right at the end, instead of growing in lockstep with the swoop.
    private var scale: CGFloat {
        let scaleT = pow(progress, scaleEasePower)
        return startScale + (endScale - startScale) * scaleT
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: baseDiameter, height: baseDiameter)
            .scaleEffect(scale)
            .position(position)
    }
}

#Preview {
    SplashView()
}
