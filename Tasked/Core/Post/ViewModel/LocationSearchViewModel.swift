//
//  LocationSearchViewModel.swift
//  Tasked
//
//  New (Location pass): backs LocationPickerView's search field with
//  MKLocalSearchCompleter, filtered to address-style results so typing
//  "Auck" surfaces "Auckland, New Zealand" etc. — the completer itself
//  only ever returns text fragments, no coordinates, so resolve(_:) runs a
//  separate, short MKLocalSearch lookup to turn a tapped suggestion into an
//  actual place name + coordinate.
//  Updated (Cities-only pass): MKLocalSearchCompleter has no true
//  city-vs-street result type, even restricted to .address — it happily
//  returns house-numbered street addresses too. Since a street address
//  result almost always leads with a house number ("123 Queen Street") and
//  a city name never does, completerDidUpdateResults now filters those out
//  client-side before they ever reach the suggestions list. Not bulletproof
//  (a very small number of legitimate place names start with a digit), but
//  it's the closest available approximation of "cities only."
//

import Foundation
import MapKit
import Combine

struct LocationSuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion

    static func == (lhs: LocationSuggestion, rhs: LocationSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class LocationSearchViewModel: NSObject, ObservableObject {
    @Published var queryFragment = "" {
        didSet { completer.queryFragment = queryFragment }
    }
    @Published var suggestions: [LocationSuggestion] = []
    @Published var isResolving = false
    @Published var errorMessage: String?

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        // Addresses (rather than points of interest) read closest to
        // "cities" for this app's purposes — a POI filter would surface
        // restaurants/landmarks instead of place names. Filtered further
        // in completerDidUpdateResults below to drop street-level results.
        completer.resultTypes = .address
    }

    /// Resolves a tapped suggestion into a display name (city + country, where
    /// available) plus its coordinate.
    func resolve(_ suggestion: LocationSuggestion) async -> (name: String, coordinate: CLLocationCoordinate2D)? {
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }

        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else {
                errorMessage = "Couldn't find that location."
                return nil
            }
            let name = Self.displayName(for: item.placemark, fallback: suggestion.title)
            return (name, item.placemark.coordinate)
        } catch {
            errorMessage = "Couldn't look up that location."
            return nil
        }
    }

    /// "City, Country" — falls back to whatever text was already shown if
    /// the placemark doesn't resolve a locality.
    static func displayName(for placemark: MKPlacemark, fallback: String) -> String {
        let city = placemark.locality ?? placemark.name
        if let city, let country = placemark.country {
            return "\(city), \(country)"
        }
        return city ?? fallback
    }

    /// Street-address results almost always lead with a house number
    /// ("123 Queen Street"); city-level results don't. This is the closest
    /// MKLocalSearchCompleter gets to a "cities only" filter.
    private static func isLikelyCity(_ completion: MKLocalSearchCompletion) -> Bool {
        guard let firstChar = completion.title.trimmingCharacters(in: .whitespaces).first else { return false }
        return !firstChar.isNumber
    }
}

extension LocationSearchViewModel: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.filter(Self.isLikelyCity)
        Task { @MainActor in
            self.suggestions = results.map {
                LocationSuggestion(title: $0.title, subtitle: $0.subtitle, completion: $0)
            }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }
}
