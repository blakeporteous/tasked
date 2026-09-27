//
//  IGTextFieldModifier.swift
//  Tasked
//
//  Created by Blake Porteous on 17/03/2025.
//  Updated (Field shadow pass): every field using this modifier (email,
//  username, password across sign-up, login, change password, etc.) now
//  matches the same "ink block" chrome as inkButton() — a heavy 3pt black
//  outline plus a solid black shadow offset by 6pt, instead of sitting
//  completely flat.
//  Updated (Focus-state fill pass): fields now start white at rest and
//  switch to the grey fill only once you're actually in the field
//  (focused/typing) — using @FocusState internally rather than a fixed
//  grey background the whole time. On iPad with a trackpad/mouse or Mac
//  Catalyst this also visually doubles as a "hover" cue; on iPhone touch
//  there's no hover state, so tapping in is what triggers it there.
//

import Foundation
import SwiftUI

struct IGTextFieldModifier: ViewModifier {
    @FocusState private var isFocused: Bool

    private let outlineWidth: CGFloat = 3
    private let shadowOffset: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .font(.subheadline)
            .padding(12)
            .background(isFocused ? Color(.systemGray6) : Color.white)
            .overlay(
                Rectangle()
                    .stroke(Color.black, lineWidth: outlineWidth)
            )
            .background(
                Rectangle()
                    .fill(Color.black)
                    .offset(x: shadowOffset, y: shadowOffset)
            )
            .padding(.horizontal, 24)
            // Applied here so every auth field (email, username, password) gets
            // consistent keyboard behaviour without repeating modifiers per-screen.
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(.never)
    }
}
