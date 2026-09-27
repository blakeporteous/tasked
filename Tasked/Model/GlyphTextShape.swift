//
//  GlyphTextShape.swift
//  Tasked
//
//  New (Liquid Glass text pass): a SwiftUI Shape built from the literal
//  glyph outlines of a string, extracted via CoreText. This is what lets
//  .glassEffect(in:) render REAL Liquid Glass (refraction/lensing that
//  follows the letterforms) as the text itself, rather than a material
//  rectangle masked to a Text view's rendered alpha — the latter looks
//  frosted but doesn't refract along the actual glyph edges the way
//  .glassEffect(in: someShape) does.
//

import SwiftUI
import CoreText

struct GlyphTextShape: Shape {
    let text: String
    let font: UIFont
    var tracking: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let ctFont = CTFontCreateWithFontDescriptor(font.fontDescriptor, font.pointSize, nil)
        let combined = CGMutablePath()
        var penX: CGFloat = 0

        for scalar in text.unicodeScalars {
            var unichar = UniChar(scalar.value)
            var glyph = CGGlyph()
            let mapped = CTFontGetGlyphsForCharacters(ctFont, &unichar, &glyph, 1)

            if mapped, let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) {
                var transform = CGAffineTransform(translationX: penX, y: 0)
                if let transformed = glyphPath.copy(using: &transform) {
                    combined.addPath(transformed)
                }
            }

            var advance = CGSize.zero
            if mapped {
                CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &advance, 1)
            } else {
                advance.width = font.pointSize * 0.32 // space / unmapped fallback
            }
            penX += advance.width + tracking
        }

        guard !combined.isEmpty else { return Path() }

        // CoreText's coordinate space is y-up; SwiftUI's is y-down.
        var flip = CGAffineTransform(scaleX: 1, y: -1)
        guard let flipped = combined.copy(using: &flip) else { return Path() }

        // Uniformly scale the combined outline to fit `rect`, then center it.
        let flippedBounds = flipped.boundingBoxOfPath
        guard flippedBounds.width > 0, flippedBounds.height > 0 else { return Path() }

        let scale = min(rect.width / flippedBounds.width, rect.height / flippedBounds.height)
        var scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        guard let scaled = flipped.copy(using: &scaleTransform) else { return Path() }

        let scaledBounds = scaled.boundingBoxOfPath
        let dx = rect.minX + (rect.width - scaledBounds.width) / 2 - scaledBounds.minX
        let dy = rect.minY + (rect.height - scaledBounds.height) / 2 - scaledBounds.minY
        var center = CGAffineTransform(translationX: dx, y: dy)
        guard let final = scaled.copy(using: &center) else { return Path() }

        return Path(final)
    }
}
