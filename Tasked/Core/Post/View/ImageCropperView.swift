//
//  ImageCropperView.swift
//  Tasked
//
//  Shared crop UI for both post upload and profile picture.
//  Updated (New Post revamp pass): the crop window is no longer locked to a
//  fixed square. ImageCropperView now takes `allowedAspectRatios` — when
//  there's more than one, a pill picker lets the person switch between
//  Square (1:1), Portrait (4:5), and Feed (5:4, matching FeedCell's own
//  image frame exactly) right there in the cropper, and the crop frame
//  itself resizes to match. A single-entry list (the default) hides the
//  picker entirely and behaves exactly like the old fixed-square cropper —
//  EditProfilePictureView is unaffected by this change.
//  All the pan/zoom clamping math (fittedSize/clampedOffset) is generalized
//  from a single "side" to a full CGSize so it works for non-square crop
//  windows too. onComplete now also hands back which aspect ratio was used,
//  so the caller (UploadPostViewModel) can size its preview to match.
//

import SwiftUI

enum CropShape {
    case square
    case circle
}

/// The aspect ratio (width : height) offered while cropping.
enum CropAspectRatio: CaseIterable, Identifiable, Equatable {
    case square
    case portrait
    case feed

    var id: Self { self }

    /// width / height.
    var ratio: CGFloat {
        switch self {
        case .square: return 1.0
        case .portrait: return 4.0 / 5.0
        case .feed: return 5.0 / 4.0
        }
    }

    var label: String {
        switch self {
        case .square: return "1:1"
        case .portrait: return "4:5"
        case .feed: return "5:4"
        }
    }

    var icon: String {
        switch self {
        case .square: return "square"
        case .portrait: return "rectangle.portrait"
        case .feed: return "rectangle"
        }
    }
}

struct ImageCropperView: View {
    let image: UIImage
    var cropShape: CropShape = .square

    /// Which aspect ratios the person can switch between. A single entry
    /// (the default) hides the picker and behaves like a fixed-ratio
    /// cropper — what EditProfilePictureView still uses.
    var allowedAspectRatios: [CropAspectRatio] = [.square]
    var initialAspectRatio: CropAspectRatio = .square

    /// Called with the final cropped image (or nil if cancelled) and
    /// whichever aspect ratio was in effect when it was called.
    let onComplete: (UIImage?, CropAspectRatio) -> Void

    @State private var aspectRatio: CropAspectRatio
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    /// On-screen size of the crop frame — tracked so renderCroppedImage
    /// (called from the toolbar, outside the GeometryReader below) can
    /// convert screen points into output pixels.
    @State private var editorSize: CGSize = CGSize(width: 320, height: 320)

    /// Longest side (px) of the exported image. Capped deliberately so a
    /// post or profile picture can never be an oversized file.
    private let outputLongSide: CGFloat = 1024
    private let maxScale: CGFloat = 5.0

    init(
        image: UIImage,
        cropShape: CropShape = .square,
        allowedAspectRatios: [CropAspectRatio] = [.square],
        initialAspectRatio: CropAspectRatio = .square,
        onComplete: @escaping (UIImage?, CropAspectRatio) -> Void
    ) {
        self.image = image
        self.cropShape = cropShape
        self.allowedAspectRatios = allowedAspectRatios
        self.initialAspectRatio = initialAspectRatio
        self.onComplete = onComplete
        self._aspectRatio = State(initialValue: initialAspectRatio)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let maxDimension = min(geo.size.width, geo.size.height) - 48
                let size = cropSize(for: maxDimension)

                VStack(spacing: 20) {
                    Spacer()

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: size.width, height: size.height)
                            .scaleEffect(scale)
                            .offset(offset)
                            .clipped()
                    }
                    .frame(width: size.width, height: size.height)
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
                    .onAppear {
                        editorSize = size
                        offset = clampedOffset(offset, scale: scale, size: size)
                        lastOffset = offset
                    }
                    .onChange(of: size) { _, newValue in
                        editorSize = newValue
                        offset = clampedOffset(offset, scale: scale, size: newValue)
                        lastOffset = offset
                    }

                    if allowedAspectRatios.count > 1 {
                        aspectRatioPicker
                    }

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
                    Button("Cancel") { onComplete(nil, aspectRatio) }
                        .tint(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Choose") { onComplete(renderCroppedImage(), aspectRatio) }
                        .fontWeight(.semibold)
                        .tint(.white)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    /// Row of pill buttons for switching between the allowed aspect ratios.
    /// Changing the ratio re-clamps (rather than resets) the current
    /// pan/zoom, so switching ratios after already framing the shot doesn't
    /// throw away the person's positioning any more than strictly necessary.
    private var aspectRatioPicker: some View {
        HStack(spacing: 10) {
            ForEach(allowedAspectRatios) { option in
                Button {
                    aspectRatio = option
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option.icon)
                        Text(option.label)
                    }
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(aspectRatio == option ? .black : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(aspectRatio == option ? Color.white : Color.white.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
        }
    }

    /// The crop frame's on-screen size for the current aspect ratio, fit
    /// within a `maxDimension` x `maxDimension` box so it always fits the
    /// screen regardless of device size or orientation.
    private func cropSize(for maxDimension: CGFloat) -> CGSize {
        let ratio = aspectRatio.ratio
        if ratio >= 1 {
            let width = maxDimension
            return CGSize(width: width, height: width / ratio)
        } else {
            let height = maxDimension
            return CGSize(width: height * ratio, height: height)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let proposed = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clampedOffset(proposed, scale: scale, size: editorSize)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let proposedScale = min(maxScale, max(1.0, lastScale * value))
                scale = proposedScale
                // Zooming out can leave the previous offset out of bounds
                // for the new (smaller) scale, so re-clamp immediately.
                offset = clampedOffset(offset, scale: proposedScale, size: editorSize)
            }
            .onEnded { _ in
                lastScale = scale
                lastOffset = offset
            }
    }

    /// The size the image renders at once `.scaledToFill()`'d into `size`,
    /// before any additional pinch-zoom `scale` is applied — mirrors the
    /// same fill-scale math renderCroppedImage uses, so the on-screen
    /// clamp and the actual export always agree.
    private func fittedSize(for size: CGSize) -> CGSize {
        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0, size.width > 0, size.height > 0 else {
            return size
        }
        let fillScale = max(size.width / imageSize.width, size.height / imageSize.height)
        return CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
    }

    /// Clamps a proposed offset so the crop window never moves outside the
    /// bounds of the image as currently zoomed. Generalized from a single
    /// "side" to a full width/height pair so it works for any aspect ratio.
    private func clampedOffset(_ proposed: CGSize, scale: CGFloat, size: CGSize) -> CGSize {
        let fitted = fittedSize(for: size)
        let scaledWidth = fitted.width * scale
        let scaledHeight = fitted.height * scale

        let maxX = max(0, (scaledWidth - size.width) / 2)
        let maxY = max(0, (scaledHeight - size.height) / 2)

        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }

    /// Renders exactly what's visible inside the crop frame — at the
    /// current zoom/pan/aspect ratio — into an output image whose longest
    /// side is `outputLongSide`, preserving that ratio exactly rather than
    /// forcing a square.
    private func renderCroppedImage() -> UIImage {
        let imageSize = image.size
        let fillScale = max(editorSize.width / imageSize.width, editorSize.height / imageSize.height)
        let fitted = CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)

        let ratio = aspectRatio.ratio
        let outputSize: CGSize = ratio >= 1
            ? CGSize(width: outputLongSide, height: outputLongSide / ratio)
            : CGSize(width: outputLongSide * ratio, height: outputLongSide)

        let exportScale = outputSize.width / editorSize.width

        let renderer = UIGraphicsImageRenderer(size: outputSize)
        return renderer.image { _ in
            let drawWidth = fitted.width * scale * exportScale
            let drawHeight = fitted.height * scale * exportScale
            let drawX = (outputSize.width - drawWidth) / 2 + offset.width * exportScale
            let drawY = (outputSize.height - drawHeight) / 2 + offset.height * exportScale
            image.draw(in: CGRect(x: drawX, y: drawY, width: drawWidth, height: drawHeight))
        }
    }
}

#Preview {
    ImageCropperView(
        image: UIImage(systemName: "photo.fill") ?? UIImage(),
        allowedAspectRatios: [.feed, .square, .portrait]
    ) { _, _ in }
}
