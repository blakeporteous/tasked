//
//  UploadPostView.swift
//  Tasked
//
//  Updated (New Post revamp pass): full visual + functional revamp.
//  - Added an "Advanced options" card (hide like count, turn off
//    commenting on this post) — UI-only for now, same affordance-now-
//    wiring-later pattern PostingSettingsViews already uses; Post.swift
//    has no matching fields yet.
//  - Overall layout restyled to sit on a grouped background with
//    gray6-card sections, matching the rest of the app (Settings, Edit
//    Profile) instead of the previous flatter loose-control VStack.
//  Updated (Location pass): added a Location row under the photo picker —
//  shows whatever LocationPickerView resolved (or what
//  UploadPostViewModel auto-detected from the photo's own GPS data), with
//  a tap opening the picker to add or change it.
//  Updated (Single-crop pass): the cropper no longer offers a choice of
//  aspect ratios — every post is cropped at the feed's own 5:4 ratio
//  (`allowedAspectRatios: [.feed]`), since that's the only place a post's
//  photo is actually shown. Dropped the aspect-ratio badge/"Change" row
//  that used to sit under the preview along with it — "Recrop" still
//  handles repositioning/re-zooming within that one fixed ratio.
//

import SwiftUI
import PhotosUI

struct UploadPostView: View {
    @StateObject var viewModel = UploadPostViewModel()
    @Binding var tabIndex: Int

    private let taskCardFillColor = Color.appAccent
    private let taskCardCornerRadius: CGFloat = 24
    private let previewCornerRadius: CGFloat = 20

    /// Width of the photo preview/picker — screen width minus this
    /// screen's own horizontal padding.
    private var previewWidth: CGFloat {
        UIScreen.main.bounds.width - 32
    }

    private var previewHeight: CGFloat {
        previewWidth / viewModel.aspectRatio.ratio
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let task = viewModel.currentTask {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("THIS WEEK'S TASK")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .tracking(0.5)
                                .foregroundStyle(.white.opacity(0.85))
                            Text(task.title)
                                .font(.headline)
                                .textCase(.uppercase)
                                .tracking(0.3)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .glassCard(cornerRadius: taskCardCornerRadius, tint: taskCardFillColor)
                    }

                    if viewModel.hasPostedThisWeek {
                        alreadyPostedState
                    } else {
                        photoPickerCard

                        if viewModel.postImage != nil {
                            locationRow
                            advancedOptionsCard
                        }

                        if viewModel.isUploading {
                            ProgressView(value: viewModel.uploadProgress)
                        }

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            Task {
                                try await viewModel.uploadPost()
                                if viewModel.errorMessage == nil {
                                    tabIndex = 0
                                }
                            }
                        } label: {
                            Text(viewModel.isUploading ? "Posting..." : "Share Post")
                                .inkButton(isDisabled: viewModel.postImage == nil || viewModel.isUploading)
                        }
                        .disabled(viewModel.postImage == nil || viewModel.isUploading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.reset()
                        tabIndex = 0
                    }
                }
            }
            .fullScreenCover(isPresented: $viewModel.showCropper) {
                if let raw = viewModel.rawPickedImage {
                    // Only the feed's own aspect ratio is offered — a
                    // single-entry list hides ImageCropperView's ratio
                    // picker entirely, since a post is only ever shown at
                    // this one ratio anywhere in the app.
                    ImageCropperView(
                        image: raw,
                        cropShape: .square,
                        allowedAspectRatios: [.feed],
                        initialAspectRatio: .feed
                    ) { cropped, chosenRatio in
                        viewModel.handleCropped(cropped, aspectRatio: chosenRatio)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showLocationPicker) {
                LocationPickerView { name, coordinate in
                    viewModel.applyLocation(name: name, coordinate: coordinate)
                }
            }
            .onAppear {
                viewModel.refreshHasPostedThisWeek()
            }
        }
    }

    private var alreadyPostedState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("You've already posted this week")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Check back next week for a new task.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var photoPickerCard: some View {
        ZStack(alignment: .topTrailing) {
            PhotosPicker(selection: $viewModel.selectedImage, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: previewCornerRadius)
                        .fill(Color(.systemGray6))
                        .frame(width: previewWidth, height: previewHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: previewCornerRadius)
                                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: viewModel.postImage == nil ? [8] : []))
                                .foregroundStyle(Color(.systemGray3))
                        )

                    if let image = viewModel.postImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: previewWidth, height: previewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 36))
                            Text("Choose a photo")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Tap to select from your library")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            if viewModel.postImage != nil {
                Button {
                    viewModel.recrop()
                } label: {
                    Label("Recrop", systemImage: "crop")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                }
                .padding(10)
            }
        }
    }

    /// Shows whatever location is currently set (auto-detected from the
    /// photo's GPS data, or picked manually) with a one-tap way into
    /// LocationPickerView to add or change it.
    private var locationRow: some View {
        Button {
            viewModel.showLocationPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                if let location = viewModel.selectedLocationName {
                    Text(location)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                } else {
                    Text("Add location")
                }
                Spacer()
                Text(viewModel.selectedLocationName == nil ? "Add" : "Change")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var advancedOptionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Advanced options")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Hide like count", isOn: $viewModel.hideLikeCount)
            Divider()
            Toggle("Turn off commenting", isOn: $viewModel.commentsDisabled)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    UploadPostView(tabIndex: .constant(0))
}
