//
//  WeeklyTaskBannerView.swift
//  Tasked
//
//  New in Feature 4. Pinned to the top of the Home feed, replacing the old
//  standalone "Goal" tab.
//

import SwiftUI

struct WeeklyTaskBannerView: View {
    let task: WeeklyTask

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THIS WEEK'S TASK")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.85))
                .tracking(0.5)

            Text(task.title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            if !task.description.isEmpty {
                Text(task.description)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(colors: [Color.blue, Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    WeeklyTaskBannerView(task: WeeklyTask.MOCK_TASK)
}
