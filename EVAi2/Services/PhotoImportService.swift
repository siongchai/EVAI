import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct ImportedPhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            ImportedPhoto(data: data)
        }
        DataRepresentation(importedContentType: .jpeg) { data in
            ImportedPhoto(data: data)
        }
        DataRepresentation(importedContentType: .heic) { data in
            ImportedPhoto(data: data)
        }
        DataRepresentation(importedContentType: .png) { data in
            ImportedPhoto(data: data)
        }
        DataRepresentation(importedContentType: .webP) { data in
            ImportedPhoto(data: data)
        }
    }
}

enum PhotoImportService {
    @MainActor
    static func importSequentially(
        from items: [PhotosPickerItem],
        handler: (Data) -> Void
    ) async -> Bool {
        var importedAny = false

        for item in items {
            let data: Data?
            if let photo = try? await item.loadTransferable(type: ImportedPhoto.self) {
                data = photo.data
            } else if let raw = try? await item.loadTransferable(type: Data.self) {
                data = raw
            } else {
                data = nil
            }

            guard let data else { continue }
            handler(data)
            importedAny = true
        }

        return importedAny
    }
}
