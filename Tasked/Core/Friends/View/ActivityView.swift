//
//  ActivityView.swift
//  Tasked
//
//  Updated (Features 1 & 6): now focused purely on friend requests — the old
//  "Recent Activity" placeholder section was removed because NotificationsView
//  (reachable from the Feed bell) is the real home for that now, and having both
//  screens claim the same territory was a duplicate navigation path.
//  Updated (Live friend-requests pass): matched to ActivityViewModel's switch
//  to a live listener — Retry now restarts the listener (startListening())
//  rather than calling a one-shot fetch that no longer exists, and pull-to-
//  refresh does the same (mostly redundant now that the list is live, but
//  kept for the familiar "just in case" gesture).
//

import SwiftUI

struct ActivityView: View {
    @StateObject private var viewModel = ActivityViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.incomingRequests.isEmpty {
                ProgressView()
                    .padding(.top, 40)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 8) {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        viewModel.startListening()
                    }
                    .font(.footnote)
                }
                .padding(.top, 40)
                .padding(.horizontal, 24)
            } else if viewModel.incomingRequests.isEmpty {
                Text("No pending friend requests.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 40)
            } else {
                List(viewModel.incomingRequests) { request in
                    HStack {
                        if let user = viewModel.incomingUsers[request.fromUid] {
                            CircularProfileImageView(user: user, size: .xSmall)
                            Text(user.username)
                                .fontWeight(.semibold)
                        } else {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(width: 40, height: 40)
                            Text("Someone")
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()

                        Button("Accept") {
                            Task { await viewModel.accept(request) }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .fixedSize()

                        Button("Decline") {
                            Task { await viewModel.decline(request) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .fixedSize()
                    }
                }
                .listStyle(.plain)
                .refreshable { viewModel.startListening() }
            }
        }
        .navigationTitle("Friend Requests")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ActivityView() }
}
