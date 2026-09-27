//
//  LocationPickerView.swift
//  Tasked
//
//  New (Location pass): sheet presented from UploadPostView's "Location"
//  row. Search-as-you-type list of city suggestions — tapping one resolves
//  it to a real place name + coordinate (LocationSearchViewModel) and hands
//  it back via onSelect.
//

import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = LocationSearchViewModel()

    /// Called with the resolved display name and coordinate once a
    /// suggestion is tapped and successfully resolved.
    let onSelect: (String, CLLocationCoordinate2D) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                content

                if viewModel.isResolving {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .searchable(text: $viewModel.queryFragment, prompt: "Search for a city")
            .navigationTitle("Add Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.queryFragment.trimmingCharacters(in: .whitespaces).isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("Search for a city")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        } else if viewModel.suggestions.isEmpty {
            Text("No matching places found.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 40)
        } else {
            List(viewModel.suggestions) { suggestion in
                Button {
                    Task {
                        if let resolved = await viewModel.resolve(suggestion) {
                            onSelect(resolved.name, resolved.coordinate)
                            dismiss()
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}

#Preview {
    LocationPickerView { _, _ in }
}
