//
//  UploadPostView.swift
//  Tasked
//
//  Created by Blake Porteous on 24/03/2025.
//  Redesigned for Features 3 & 7: caption field removed (caption is automatic),
//  cleaner layout, visible upload progress, clearer errors.
//

import SwiftUI
import PhotosUI

struct UploadPostView: View {
    @StateObject var viewModel = UploadPostViewModel()
    @Binding var tabIndex: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let task = viewModel.currentTask {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("THIS WEEK'S TASK")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                        Text(task.title)
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                PhotosPicker(selection: $viewModel.selectedImage, matching: .images) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                            .frame(height: 320)

                        if let image = viewModel.postImage {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(height: 320)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 36))
                                Text("Choose a photo")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)

                if viewModel.isUploading {
                    ProgressView(value: viewModel.uploadProgress)
                        .padding(.horizontal)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
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
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(viewModel.postImage == nil ? Color.blue.opacity(0.5) : Color.blue)
                        .cornerRadius(10)
                }
                .disabled(viewModel.postImage == nil || viewModel.isUploading)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 12)
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
        }
    }
}

#Preview {
    UploadPostView(tabIndex: .constant(0))
}
