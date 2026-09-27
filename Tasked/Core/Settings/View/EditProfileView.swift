//
//  EditProfileView.swift
//  Tasked
//
//  Rewritten for Feature 5A: text fields only (username, bio). Picture
//  editing lives in EditProfilePictureView now. Reachable only from Settings.
//  Updated (Drop fullname pass): removed the "Name" row — only Username and
//  Bio remain, matching EditProfileViewModel no longer tracking fullname.
//  Updated (Username availability pass): shows the same live "Checking
//  availability…" / "already taken" feedback under the Username field that
//  CreateUsernameView shows at sign-up, and disables "Done" while a check is
//  in flight or the current value is taken.
//  Updated (Profile revamp pass): added a "Location" row below Bio.
//  Updated (Settings template pass): rebuilt on the shared
//  SettingsDetailView/SettingsCard template (SettingsTemplates.swift)
//  instead of its own hand-rolled ScrollView/background — same fields and
//  save logic, just matching the rest of Settings visually now.
//  Updated (Location pass): the Location row is no longer a free-typed
//  TextField — it's now a tappable row (matching UploadPostView's own
//  Location row) that opens the same LocationPickerView city-search sheet.
//  Picking a result auto-fills it; tapping again lets the person change it.
//

import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel: EditProfileViewModel

    init(user: User) {
        self._viewModel = StateObject(wrappedValue: EditProfileViewModel(user: user))
    }

    private var isSaveDisabled: Bool {
        viewModel.isSaving || viewModel.isCheckingUsername || viewModel.usernameError != nil
    }

    var body: some View {
        SettingsDetailView(title: "Edit Profile") {
            HStack {
                Spacer()
                CircularProfileImageView(user: viewModel.user, size: .large)
                Spacer()
            }

            SettingsCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Username")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter your username...", text: $viewModel.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }

                if viewModel.isCheckingUsername {
                    Text("Checking availability…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let usernameError = viewModel.usernameError {
                    Text(usernameError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Bio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter your bio...", text: $viewModel.bio, axis: .vertical)
                        .lineLimit(3...6)
                }

                Divider()

                Button {
                    viewModel.showLocationPicker = true
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Text(viewModel.location.isEmpty ? "Add your location..." : viewModel.location)
                                .foregroundStyle(viewModel.location.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task {
                    if await viewModel.save() {
                        dismiss()
                    }
                }
            } label: {
                // Deliberately NOT .inkButton() — that shared chrome
                // defaults to the app's orange/red CTA color, and this
                // screen wants blue specifically. Self-contained styling
                // here (same full-width/uppercase/rounded shape as
                // inkButton, just tinted with Color.appAccent).
                Group {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Save Changes")
                    }
                }
                .font(.subheadline)
                .fontWeight(.bold)
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.appAccent)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .compositingGroup()
                .opacity(isSaveDisabled ? 0.5 : 1)
            }
            .disabled(isSaveDisabled)
        }
        .sheet(isPresented: $viewModel.showLocationPicker) {
            LocationPickerView { name, coordinate in
                viewModel.applyLocation(name: name, coordinate: coordinate)
            }
        }
    }
}

#Preview {
    NavigationStack { EditProfileView(user: User.MOCK_USERS[0]) }
}
