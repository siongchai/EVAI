import Foundation

/// Curated trim/variant lists for common EVs sold in Singapore.
enum CarVariantCatalog {
    static let other = "Other"

    private static func key(brand: String, model: String) -> String {
        "\(brand)|\(model)"
    }

    private static let variantsByModel: [String: [String]] = [
        // Tesla
        key(brand: "Tesla", model: "Model 3"): [
            "Highland RWD", "Highland Long Range", "Performance",
            "RWD", "Long Range"
        ],
        key(brand: "Tesla", model: "Model Y"): ["RWD", "Long Range", "Performance"],
        key(brand: "Tesla", model: "Model S"): ["Long Range", "Plaid"],
        key(brand: "Tesla", model: "Model X"): ["Long Range", "Plaid"],

        // BYD
        key(brand: "BYD", model: "Atto 3"): ["Standard", "Extended"],
        key(brand: "BYD", model: "Dolphin"): ["Dynamic", "Premium"],
        key(brand: "BYD", model: "Seal"): ["Dynamic", "Premium", "Performance"],
        key(brand: "BYD", model: "Han"): ["EV Premium", "EV Performance"],
        key(brand: "BYD", model: "Tang"): ["EV Premium"],
        key(brand: "BYD", model: "M6"): ["Standard", "Premium"],
        key(brand: "BYD", model: "e6"): ["Standard"],

        // Hyundai
        key(brand: "Hyundai", model: "Ioniq 5"): ["Inspiration", "Prestige"],
        key(brand: "Hyundai", model: "Ioniq 6"): ["Inspiration", "Prestige"],
        key(brand: "Hyundai", model: "Kona"): ["Inspiration", "Sunroof"],
        key(brand: "Hyundai", model: "Ioniq"): ["Elite", "Premium"],

        // Kia
        key(brand: "Kia", model: "EV6"): ["Air", "GT-Line", "GT"],
        key(brand: "Kia", model: "EV9"): ["Air", "GT-Line"],
        key(brand: "Kia", model: "Niro EV"): ["Standard", "Premium"],

        // BMW
        key(brand: "BMW", model: "i4"): ["eDrive35", "eDrive40", "M50"],
        key(brand: "BMW", model: "iX3"): ["M Sport"],
        key(brand: "BMW", model: "iX"): ["xDrive40", "xDrive50", "M60"],
        key(brand: "BMW", model: "iX1"): ["eDrive20", "xDrive30"],
        key(brand: "BMW", model: "iX2"): ["xDrive30"],
        key(brand: "BMW", model: "i5"): ["eDrive40", "M60"],
        key(brand: "BMW", model: "i7"): ["xDrive60", "M70"],

        // Mercedes-Benz
        key(brand: "Mercedes-Benz", model: "EQA"): ["EQA 250+"],
        key(brand: "Mercedes-Benz", model: "EQB"): ["EQB 250+"],
        key(brand: "Mercedes-Benz", model: "EQC"): ["EQC 400 4MATIC"],
        key(brand: "Mercedes-Benz", model: "EQE"): ["EQE 350+", "EQE 500 4MATIC"],
        key(brand: "Mercedes-Benz", model: "EQS"): ["EQS 450+", "EQS 580 4MATIC"],

        // MG
        key(brand: "MG", model: "MG4 EV"): ["Standard", "Lux", "XPOWER"],
        key(brand: "MG", model: "ZS EV"): ["Standard", "Lux"],
        key(brand: "MG", model: "Cyberster"): ["Standard", "Performance"],

        // Polestar
        key(brand: "Polestar", model: "2"): [
            "Standard Range Single Motor", "Long Range Single Motor",
            "Long Range Dual Motor", "BST Edition"
        ],
        key(brand: "Polestar", model: "3"): ["Long Range Dual Motor", "Performance"],
        key(brand: "Polestar", model: "4"): ["Long Range Single Motor", "Long Range Dual Motor"],

        // Volvo
        key(brand: "Volvo", model: "EX30"): ["Core", "Plus", "Ultra"],
        key(brand: "Volvo", model: "EX90"): ["Plus", "Ultra"],
        key(brand: "Volvo", model: "XC40"): ["Recharge Plus", "Recharge Ultimate"],
        key(brand: "Volvo", model: "C40"): ["Recharge Plus", "Recharge Ultimate"],

        // Nissan
        key(brand: "Nissan", model: "Leaf"): ["Standard", "Premium"],
        key(brand: "Nissan", model: "Ariya"): ["Advance", "Evolve+"],

        // Porsche
        key(brand: "Porsche", model: "Taycan"): ["Standard", "4S", "Turbo", "Turbo S"],
        key(brand: "Porsche", model: "Taycan Cross Turismo"): ["4", "4S", "Turbo"],

        // Audi
        key(brand: "Audi", model: "e-tron"): ["55 quattro", "S"],
        key(brand: "Audi", model: "Q4 e-tron"): ["35", "40", "50 quattro"],
        key(brand: "Audi", model: "Q8 e-tron"): ["55 quattro", "SQ8"],

        // Volkswagen
        key(brand: "Volkswagen", model: "ID.3"): ["Pro", "Pro Performance"],
        key(brand: "Volkswagen", model: "ID.4"): ["Pro", "Pro Performance", "GTX"],
        key(brand: "Volkswagen", model: "ID.5"): ["Pro", "Pro Performance", "GTX"],

        // XPeng
        key(brand: "XPeng", model: "G6"): ["Standard", "Performance"],
        key(brand: "XPeng", model: "P7"): ["Standard", "Performance"],
        key(brand: "XPeng", model: "G9"): ["Standard", "Performance"],
        key(brand: "XPeng", model: "X9"): ["Standard", "Performance"],

        // NIO
        key(brand: "NIO", model: "ES6"): ["Standard", "Long Range"],
        key(brand: "NIO", model: "ES8"): ["Standard", "Long Range"],
        key(brand: "NIO", model: "ET5"): ["Standard", "Long Range"],
        key(brand: "NIO", model: "ET7"): ["Standard", "Long Range"],
        key(brand: "NIO", model: "EC6"): ["Standard", "Long Range"],
        key(brand: "NIO", model: "EC7"): ["Standard", "Long Range"],
        key(brand: "NIO", model: "ES7"): ["Standard", "Long Range"],

        // Zeekr
        key(brand: "Zeekr", model: "001"): ["WE", "ME", "YOU"],
        key(brand: "Zeekr", model: "007"): ["Standard", "Performance"],
        key(brand: "Zeekr", model: "009"): ["Standard", "Performance"],
        key(brand: "Zeekr", model: "X"): ["Standard", "Performance"],

        // Honda / Toyota / Mini / Smart
        key(brand: "Honda", model: "e:N2"): ["Standard", "Advanced"],
        key(brand: "Toyota", model: "bZ4X"): ["X", "G"],
        key(brand: "Mini", model: "Cooper"): ["SE Essential", "SE Excited"],
        key(brand: "Mini", model: "Aceman"): ["E Classic", "E Favoured", "E JCW"],
        key(brand: "Smart", model: "#1"): ["Pro", "Pro+"],
        key(brand: "Smart", model: "#3"): ["Pro", "Pro+"],

        // Genesis / Lotus / Aion / Omoda
        key(brand: "Genesis", model: "GV60"): ["Standard", "Performance"],
        key(brand: "Lotus", model: "Eletre"): ["S", "R"],
        key(brand: "Lotus", model: "Emeya"): ["S", "R"],
        key(brand: "Aion", model: "Y Plus"): ["Elite", "Premium"],
        key(brand: "Aion", model: "ES"): ["Standard", "Premium"],
        key(brand: "Omoda", model: "Omoda E5"): ["Standard", "Premium"],

        // Ford / Cupra / Skoda / Lexus / Jaguar / Peugeot
        key(brand: "Ford", model: "Mustang Mach-E"): ["Select", "Premium", "GT"],
        key(brand: "Cupra", model: "Born"): ["V1", "V2", "V3"],
        key(brand: "Skoda", model: "Enyaq"): ["60", "80", "80x"],
        key(brand: "Lexus", model: "RZ"): ["Premium", "Luxury"],
        key(brand: "Jaguar", model: "I-Pace"): ["S", "SE", "HSE"],
        key(brand: "Peugeot", model: "e-2008"): ["Allure", "GT"],
        key(brand: "Peugeot", model: "e-308"): ["Allure", "GT"],
        key(brand: "Renault", model: "Megane E-Tech"): ["Equilibre", "Techno", "Iconic"],
        key(brand: "Renault", model: "Zoe"): ["R135"],
        key(brand: "Fiat", model: "500e"): ["Icon", "La Prima"]
    ]

    static func variants(for brand: String, model: String) -> [String] {
        variantsByModel[key(brand: brand, model: model)] ?? []
    }

    static func pickerOptions(for brand: String, model: String, including current: String) -> [String] {
        var options = variants(for: brand, model: model)
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !options.contains(trimmed), trimmed != other {
            options.append(trimmed)
        }
        options.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        options.append(other)
        return options
    }

    static func hasCatalogVariants(for brand: String, model: String) -> Bool {
        !variants(for: brand, model: model).isEmpty
    }
}
