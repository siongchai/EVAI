import Foundation
import SwiftData

enum CarLookup {
    static func primaryCar(in modelContext: ModelContext) -> Car? {
        let cars = (try? modelContext.fetch(FetchDescriptor<Car>())) ?? []
        return cars.first(where: \.isPrimary)
    }

    static func primaryCarDisplayName(in modelContext: ModelContext) -> String? {
        primaryCar(in: modelContext)?.displayName.nilIfEmpty
    }
}
