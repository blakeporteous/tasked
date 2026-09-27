//
//  AppColors.swift
//  Tasked
//
//  New (Accent-color pass): single source of truth for the app's accent
//  color. Every place that used to hardcode Color(red: 13/255, green:
//  113/255, blue: 255/255) or the system .blue now reads Color.appAccent
//  instead — change the two RGB values below and every dot, banner, badge,
//  link, and button that uses the accent updates together instead of
//  needing to be hunted down file by file.
//
//  Built on a UIColor dynamic provider (not a flat Color) so it can carry a
//  different value in dark mode later just by editing the "dark" case below
//  — nothing else needs to change when that's tuned.
//

import SwiftUI
import UIKit

extension Color {
    /// The app's single accent color — swap the two UIColor values below to
    /// retint the whole app.
    static let appAccent = Color(UIColor { traits in
        switch traits.userInterfaceStyle {
        case .dark:
            return UIColor(red: 64.0 / 255.0, green: 156.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
        default:
            return UIColor(red: 13.0 / 255.0, green: 113.0 / 255.0, blue: 255.0 / 255.0, alpha: 1)
        }
    })
}
