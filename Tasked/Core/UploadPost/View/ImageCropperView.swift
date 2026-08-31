//
//  ImageCropperView.swift
//  Tasked
//
//  New: shared crop UI for both post upload and profile picture. The user
//  drags to reposition and pinches to zoom inside a fixed square frame, and
//  "Choose" always renders exactly what's inside that frame into a fixed
//  1024x1024 output — regardless of the source photo's original resolution
//  or aspect ratio. This is what was previously missing: a huge or oddly-
//  shaped picked photo would go straight to upload and mess up the feed
//  layout. Now every post image and every profile picture is the same
//  predictable square size.
//

import SwiftUI

/// Visual shape of the crop frame. The exported image is ALWAYS a square —
/// `.circle` just previews it clipped to a circle, since that's how profile
/// pictures are displayed everywhere else in the app (CircularProfileImageView).
enum CropShape {
    case square
    case circle
}

struct ImageCropperView: View {
    let image: UIImage
    var cropShape: CropShape = .square

    /// Called with the final cropped square image, or nil if the user cancelled.
    let onComplete: (UIImage?) -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// Tracks the on-screen side length of the crop frame so renderCroppedImage
    /// (called from the toolbar, outside the GeometryReader below) can convert
    /// screen points into output pixels.
    @State private var editorSide: CGFloat = 320

    /// Side length (px) of the exported square. Capped deliberately so a post
    /// or profile picture can never be an oversized file that blows up the
    /// feed layout or takes forever to upload.
    private let outputSize: CGFloat = 1024
    private let maxScale: CGFloat = 5.0

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let side = min(geo.size.width, geo.size.height) - 48

                VStack(spacing: 20) {
                    Spacer()

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: side, height: side)
                            .scaleEffect(scale)
                            .offset(offset)
                            .clipped()
                    }
                    .frame(width: side, height: side)
                    .clipShape(cropShape == .circle ? AnyShape(Circle()) : AnyShape(Rectangle()))
                    .overlay {
                        if cropShape == .circle {
                            Circle().stroke(Color.white, lineWidth: 1.5)
                        } else {
                            Rectangle().stroke(Color.white, lineWidth: 1.5)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(dragGesture)
                    .simultaneousGesture(magnificationGesture)
                    .onAppear { editorSide = side }
                    .onChange(of: side) { _, newValue in editorSide = newValue }

                    Text("Drag to reposition · pinch to zoom")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onComplete(nil) }
                        .tint(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Choose") { onComplete(renderCroppedImage()) }
                        .fontWeight(.semibold)
                        .tint(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(maxScale, max(1.0, lastScale * value))
            }
            .onEnded { _ in lastScale = scale }
    }

    /// Renders exactly what's visible inside the crop frame — at the current
    /// zoom/pan — into a fixed `outputSize` x `outputSize` square. The math
    /// mirrors SwiftUI's own `.scaledToFill()` sizing so what you see in the
    /// editor is exactly what comes out.
    private func renderCroppedImage() -> UIImage {
        let imageSize = image.size
        let fillScale = max(editorSide / imageSize.width, editorSide / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
        let exportScale = outputSize / editorSide

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        return renderer.image { _ in
            let drawWidth = fittedSize.width * scale * exportScale
            let drawHeight = fittedSize.height * scale * exportScale
            let drawX = (outputSize - drawWidth) / 2 + offset.width * exportScale
            let drawY = (outputSize - drawHeight) / 2 + offset.height * exportScale
            image.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }
    }
}

#Preview {
    ImageCropperView(image: UIImage(systemName: "photo.fill") ?? UIImage()) { _ in }
}
