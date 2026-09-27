//
//  ShareableImage.swift
//  Tasked
//
//  New (Share fix pass): wraps a UIImage — pulled straight from
//  Kingfisher's in-memory cache, which is the SAME image FeedCell is
//  already displaying, so sharing triggers no extra network fetch — in a
//  Transferable conformance so ShareLink can hand the recipient app the
//  actual photo instead of a bare Firebase Storage URL. Previously
//  FeedCell's share button used `ShareLink(item: URL)` pointed at the raw
//  storage link — it opened a share sheet, but most destinations (Messages,
//  Mail, etc.) just showed a plain link with no image preview rather than
//  attaching the photo itself.
//

import SwiftUI
import UniformTypeIdentifiers

struct ShareableImage: Transferable {
    let image: UIImage
    let caption: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .jpeg) { shareable in
            shareable.image.jpegData(compressionQuality: 0.9) ?? Data()
        }
    }
}
