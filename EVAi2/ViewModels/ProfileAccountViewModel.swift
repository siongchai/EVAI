import Foundation
import Observation
import SwiftData
import UIKit

@Observable
@MainActor
final class ProfileAccountViewModel {
    var fullName = ""
    var email = ""
    var photoPreview: UIImage?
    var saveMessage: String?
    var saveError: String?

    private var pendingPhotoData: Data?
    private var removeExistingPhoto = false

    func bind(profile: UserProfile) {
        fullName = profile.fullName
        email = profile.email
        photoPreview = profile.photoImage
        pendingPhotoData = nil
        removeExistingPhoto = false
        saveMessage = nil
        saveError = nil
    }

    func setPhoto(from data: Data) {
        pendingPhotoData = (try? ImageProcessor.optimizeForPortrait(data)) ?? data
        photoPreview = ImageProcessor.makeThumbnail(from: pendingPhotoData ?? data)
        removeExistingPhoto = false
        saveError = nil
    }

    func removePhoto() {
        pendingPhotoData = nil
        photoPreview = nil
        removeExistingPhoto = true
    }

    @discardableResult
    func save(to profile: UserProfile, using context: ModelContext) -> Bool {
        saveError = nil
        saveMessage = nil

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedEmail.isEmpty, !trimmedEmail.isValidEmail {
            saveError = "Enter a valid email address."
            return false
        }

        profile.fullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.email = trimmedEmail
        profile.updatedAt = .now

        do {
            try persistPhoto(on: profile)
            try context.save()
            saveMessage = "Profile updated."
            pendingPhotoData = nil
            removeExistingPhoto = false
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    private func persistPhoto(on profile: UserProfile) throws {
        if let data = pendingPhotoData {
            if !profile.imageFileID.isEmpty {
                ImageStorageManager.deleteImage(id: profile.imageFileID)
            }
            profile.imageFileID = try ImageStorageManager.saveProfilePhoto(data, profileID: profile.id)
            return
        }

        if removeExistingPhoto, !profile.imageFileID.isEmpty {
            ImageStorageManager.deleteImage(id: profile.imageFileID)
            profile.imageFileID = ""
        }
    }
}
