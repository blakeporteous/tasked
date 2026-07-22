//
//  IGTextFieldModifier.swift
//  Tasked
//
//  Created by Blake Porteous on 17/03/2025.
//

import Foundation
import SwiftUI

struct IGTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .padding(12)
            .background(Color(.systemGray6))
            .presentationCornerRadius(10)
            .padding(.horizontal, 24)
    }
}
