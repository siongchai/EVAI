import Foundation
import SwiftData
import UIKit

@Model
final class UserProfile {
    var id: UUID = Foundation.UUID()
    var fullName: String = ""
    var email: String = ""
    var imageFileID: String = ""
    var updatedAt: Date = Foundation.Date.now

    init(
        id: UUID = UUID(),
        fullName: String = "",
        email: String = "",
        imageFileID: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.imageFileID = imageFileID
        self.updatedAt = updatedAt
    }

    var displayName: String {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? AppConstants.defaultUserName : trimmed
    }

    var photoImage: UIImage? {
        guard !imageFileID.isEmpty else { return nil }
        return ImageStorageManager.loadDisplayImage(id: imageFileID)
    }
}

enum UserProfileService {
    @MainActor
    static func ensureProfile(in context: ModelContext) -> UserProfile {
        if let existing = try? context.fetch(FetchDescriptor<UserProfile>()).first {
            return existing
        }

        let profile = UserProfile(fullName: AppConstants.defaultUserName, email: "")
        context.insert(profile)
        try? context.save()
        return profile
    }

    static func displayName(from profile: UserProfile?) -> String {
        profile?.displayName ?? AppConstants.defaultUserName
    }

    @MainActor
    static func validateStoredAssets(in context: ModelContext) {
        ImageStorageManager.prepareStorageIfNeeded()

        if let profiles = try? context.fetch(FetchDescriptor<UserProfile>()) {
            for profile in profiles where !profile.imageFileID.isEmpty {
                if !ImageStorageManager.storedImageExists(id: profile.imageFileID) {
                    profile.imageFileID = ""
                    profile.updatedAt = .now
                }
            }
        }

        if let cars = try? context.fetch(FetchDescriptor<Car>()) {
            for car in cars where !car.imageFileID.isEmpty {
                if !ImageStorageManager.storedImageExists(id: car.imageFileID) {
                    car.imageFileID = ""
                    car.updatedAt = .now
                }
            }
        }

        try? context.save()
    }
}
