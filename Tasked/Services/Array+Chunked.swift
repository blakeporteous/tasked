//
//  Array+Chunked.swift
//  Tasked
//

import Foundation

extension Array {
    /// Splits the array into chunks of at most `size` elements.
    /// Used because Firestore's `whereField(_:in:)` only supports up to 30 values per query.
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
