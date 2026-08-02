//
//  ImageUploader.swift
//  Tasked
//
//  Created by Blake Porteous on 23/07/2025.
//

import UIKit
import Firebase
import FirebaseAuth
import FirebaseStorage

struct ImageUploader {
    static func uploadImage(image: UIImage) async throws -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return nil }
        let filename = NSUUID().uuidString
        let path = "profile_images/\(filename)"
        let ref = Storage.storage().reference(withPath: path)

        // Required by the Storage rule's request.resource.contentType.matches('image/.*')
        // check. Without this, putDataAsync uploads with no content type set, the rule
        // never matches, and Storage reports it back as a generic "permission denied"
        // error rather than a content-type error — this was the actual bug.
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        print("DEBUG: Uploading image — uid: \(Auth.auth().currentUser?.uid ?? "nil"), path: \(path), size: \(imageData.count) bytes, contentType: \(metadata.contentType ?? "nil")")

        do {
            let _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            return url.absoluteString

        } catch let error as StorageError {
            print("DEBUG: Failed to upload image — StorageError: \(error), details: \((error as NSError).userInfo)")
            return nil
        } catch {
            print("DEBUG: Failed to upload image with error \(error)")
            return nil
        }
    }
}
