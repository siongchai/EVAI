import Foundation

enum CarBrandCatalog {
    static let other = "Other"

    /// Common passenger-car brands sold or registered in Singapore.
    static let commonBrands: [String] = [
        "Aion",
        "Alfa Romeo",
        "Audi",
        "Bentley",
        "BMW",
        "BYD",
        "Chery",
        "Citroën",
        "Cupra",
        "Ferrari",
        "Fiat",
        "Ford",
        "Genesis",
        "Honda",
        "Hyundai",
        "Isuzu",
        "Jaguar",
        "Jeep",
        "Kia",
        "Lamborghini",
        "Land Rover",
        "Lexus",
        "Lotus",
        "Maserati",
        "Mazda",
        "McLaren",
        "Mercedes-Benz",
        "MG",
        "Mini",
        "Mitsubishi",
        "NIO",
        "Nissan",
        "Omoda",
        "Peugeot",
        "Polestar",
        "Porsche",
        "Proton",
        "Renault",
        "Rolls-Royce",
        "Skoda",
        "Smart",
        "Subaru",
        "Suzuki",
        "Tesla",
        "Toyota",
        "Volkswagen",
        "Volvo",
        "XPeng",
        "Zeekr"
    ]

    static func pickerOptions(including current: String) -> [String] {
        var options = commonBrands
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !options.contains(trimmed), trimmed != other {
            options.append(trimmed)
        }
        options.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        options.append(other)
        return options
    }
}
