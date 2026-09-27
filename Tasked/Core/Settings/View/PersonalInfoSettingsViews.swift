//
//  PersonalInfoSettingsViews.swift
//  Tasked
//
//  New (Settings revamp pass): backs the new "Personal Information" settings
//  group. None of these fields exist on User.swift yet, so each screen just
//  holds its value locally as a placeholder — same "affordance now, wiring
//  later" pattern as PostingSettingsViews.
//

import SwiftUI

struct DateOfBirthSettingsView: View {
    @State private var dateOfBirth = Date()

    var body: some View {
        SettingsDetailView(title: "Date of Birth") {
            SettingsCard {
                DatePicker("Date of birth", selection: $dateOfBirth, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            Text("Your birthday isn't shown on your profile — it's just used to keep your account info accurate.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct GenderSettingsView: View {
    private let options = ["Prefer not to say", "Female", "Male", "Non-binary", "Custom"]
    @State private var selection = "Prefer not to say"

    var body: some View {
        SettingsDetailView(title: "Gender") {
            SettingsCard {
                Picker("Gender", selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }
}

struct CountryRegionSettingsView: View {
    @State private var countryOrRegion = ""

    var body: some View {
        SettingsDetailView(title: "Country/Region") {
            SettingsCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Country/Region")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Add your country or region...", text: $countryOrRegion)
                        .autocorrectionDisabled()
                }
            }
        }
    }
}

struct LanguageSettingsView: View {
    private let options = ["English", "Spanish", "French", "German", "Japanese"]
    @State private var selection = "English"

    var body: some View {
        SettingsDetailView(title: "Language") {
            SettingsCard {
                Picker("Language", selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
    }
}
