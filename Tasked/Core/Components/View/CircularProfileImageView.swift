//
//  CircularProfileImageView.swift
//  Tasked
//
//  Updated (Circle revamp pass): back to circular avatars everywhere — the
//  square/ink-block treatment is gone. Ink chrome (outline + offset shadow)
//  is now drawn as a circle instead of a square, where it's still applied.
//  Updated (No-chrome-by-default pass): the offset black shadow behind the
//  outline was reading as a "double circle" wherever a .large avatar showed
//  up (profile header, private profile view, edit profile screens) — the
//  size-based default that auto-applied it for .large is gone. Ink chrome
//  now only shows up where a call site explicitly opts in via
//  showsInkChrome: true, which nothing currently does.
//  Updated (Custom-dimension pass): added an optional `overrideDimension`
//  so a call site can go bigger (or smaller) than the fixed sizes in
//  `profileImageSize` — e.g. ProfileHeaderView sizing the avatar off a
//  fraction of the screen's height. `size` is still required (existing call
//  sites are unaffected — overrideDimension defaults to nil, falling back
//  to size.dimension exactly as before).
//

import SwiftUI
import Kingfisher

enum profileImageSize {
    case xSmall
    case small
    case medium
    case large

    var dimension: CGFloat {
        switch self {
        case .xSmall: return 40
        case .small: return 48
        case .medium: return 64
        case .large: return 80
        }
    }
}

struct CircularProfileImageView: View {
    let user: User
    let size: profileImageSize

    /// Overrides `size.dimension` when set — lets a call site pick an exact
    /// pixel diameter (e.g. a fraction of screen height) instead of one of
    /// the fixed sizes above.
    var overrideDimension: CGFloat? = nil

    /// Explicit opt-in only now — leave nil (or false) for a plain circle
    /// with no outline/shadow. Nothing in the app currently sets this true.
    var showsInkChrome: Bool? = nil

    private var dimension: CGFloat {
        overrideDimension ?? size.dimension
    }

    private var appliesInkChrome: Bool {
        showsInkChrome ?? false
    }

    private let outlineWidth: CGFloat = 2
    private let shadowOffset: CGFloat = 4

    var body: some View {
        Group {
            if let imageURL = user.profileImageUrl {
                KFImage(URL(string: imageURL))
                    .resizable()
                    .scaledToFill()
                    .frame(width: dimension, height: dimension)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(.systemGray4))
                    .overlay(
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(Color(.systemGray))
                            .padding(dimension * 0.22)
                    )
                    .frame(width: dimension, height: dimension)
            }
        }
        .overlay {
            if appliesInkChrome {
                Circle().stroke(Color.black, lineWidth: outlineWidth)
            }
        }
        .background {
            if appliesInkChrome {
                Circle()
                    .fill(Color.black)
                    .offset(x: shadowOffset, y: shadowOffset)
            }
        }
    }
}

#Preview {
    CircularProfileImageView(user: User.MOCK_USERS[0], size: .large)
}
