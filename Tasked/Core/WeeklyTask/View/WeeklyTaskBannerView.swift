//
//  WeeklyTaskBannerView.swift
//  Tasked
//
//  New in Feature 4. Pinned to the top of the Home feed, replacing the old
//  standalone "Goal" tab.
//  Updated (Ink block pass): restyled to match the app's shared "ink block"
//  chrome (InkButtonStyle.swift) — squared corners, heavy black outline,
//  solid black offset shadow, bold uppercase label — instead of the old
//  rounded gradient card. Fill is kept blue (not the shared orange/red CTA
//  color) since this is a status banner, not an actionable button.
//  Updated (Liquid Glass pass): the squared ink-block chrome is gone —
//  this now uses the shared `glassCard(cornerRadius:tint:)` from
//  InkButtonStyle.swift (real `.glassEffect` on iOS 26+, a tinted frosted
//  fallback on earlier versions), same blue tint as before, rounded rather
//  than squared corners, no black outline or hard offset shadow. Text
//  content/structure (THIS WEEK'S TASK caption, title, description) is
//  untouched.
//

import SwiftUI

struct WeeklyTaskBannerView: View {
    let task: WeeklyTask

    private let fillColor = Color.appAccent
    private let cornerRadius: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THIS WEEK'S TASK")
                .font(.caption2)
                .fontWeight(.bold)
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.85))

            Text(task.title)
                .font(.title3)
                .fontWeight(.bold)
                .textCase(.uppercase)
                .tracking(0.3)
                .foregroundStyle(.white)

            if !task.description.isEmpty {
                Text(task.description)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard(cornerRadius: cornerRadius, tint: fillColor)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    WeeklyTaskBannerView(task: WeeklyTask.MOCK_TASK)
}
