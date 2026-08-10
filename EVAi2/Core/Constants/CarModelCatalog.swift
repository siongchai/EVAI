import Foundation

enum CarModelCatalog {
    static let other = "Other"

    private static let modelsByBrand: [String: [String]] = [
        "Aion": ["ES", "HT", "V", "Y Plus"],
        "Alfa Romeo": ["Giulia", "Stelvio", "Tonale"],
        "Audi": ["A1", "A3", "A4", "A6", "A8", "Q2", "Q3", "Q5", "Q7", "Q8", "e-tron", "Q4 e-tron", "Q8 e-tron"],
        "Bentley": ["Bentayga", "Continental GT", "Flying Spur"],
        "BMW": ["1 Series", "2 Series", "3 Series", "4 Series", "5 Series", "7 Series", "X1", "X3", "X4", "X5", "X6", "X7", "iX1", "iX2", "iX3", "iX", "i4", "i5", "i7", "Z4"],
        "BYD": ["Atto 3", "Dolphin", "Seal", "Han", "Tang", "M6", "e6"],
        "Chery": ["Tiggo 7 Pro", "Tiggo 8 Pro", "Omoda 5"],
        "Citroën": ["C3", "C4", "C5 Aircross", "e-C4", "Berlingo"],
        "Cupra": ["Born", "Formentor", "Leon"],
        "Ferrari": ["296 GTB", "812", "Purosangue", "Roma", "SF90"],
        "Fiat": ["500", "500e", "Panda"],
        "Ford": ["Everest", "Focus", "Mustang Mach-E", "Ranger", "Territory"],
        "Genesis": ["G70", "G80", "G90", "GV60", "GV70", "GV80"],
        "Honda": ["BR-V", "City", "Civic", "CR-V", "HR-V", "Jazz", "Accord", "Odyssey", "e:N1", "e:N2"],
        "Hyundai": ["Avante", "Elantra", "Ioniq", "Ioniq 5", "Ioniq 6", "Kona", "Santa Fe", "Staria", "Tucson", "Venue"],
        "Isuzu": ["D-Max", "MU-X"],
        "Jaguar": ["E-Pace", "F-Pace", "F-Type", "I-Pace", "XF"],
        "Jeep": ["Avenger", "Compass", "Grand Cherokee", "Wrangler"],
        "Kia": ["Carnival", "Cerato", "EV6", "EV9", "Niro EV", "Picanto", "Seltos", "Sonet", "Sportage", "Stonic"],
        "Lamborghini": ["Huracán", "Revuelto", "Urus"],
        "Land Rover": ["Defender", "Discovery", "Discovery Sport", "Range Rover", "Range Rover Evoque", "Range Rover Sport", "Range Rover Velar"],
        "Lexus": ["ES", "IS", "LC", "LM", "LS", "LX", "NX", "RX", "RZ", "UX"],
        "Lotus": ["Eletre", "Emeya", "Emira"],
        "Maserati": ["Ghibli", "Grecale", "GranTurismo", "Levante", "MC20"],
        "Mazda": ["CX-3", "CX-30", "CX-5", "CX-60", "CX-8", "CX-90", "Mazda2", "Mazda3", "MX-5"],
        "McLaren": ["750S", "Artura", "GT"],
        "Mercedes-Benz": ["A-Class", "C-Class", "CLA", "E-Class", "S-Class", "GLA", "GLB", "GLC", "GLE", "GLS", "G-Class", "EQA", "EQB", "EQC", "EQE", "EQS", "AMG GT"],
        "MG": ["Cyberster", "HS", "MG4 EV", "MG5", "ZS", "ZS EV"],
        "Mini": ["Aceman", "Cooper", "Countryman"],
        "Mitsubishi": ["Attrage", "Eclipse Cross", "Outlander", "Space Star", "Triton", "Xpander"],
        "NIO": ["EC6", "EC7", "ES6", "ES7", "ES8", "ET5", "ET7"],
        "Nissan": ["Ariya", "Kicks", "Leaf", "Navara", "Note", "Serena", "Sylphy", "X-Trail"],
        "Omoda": ["Omoda 5", "Omoda E5"],
        "Peugeot": ["2008", "3008", "408", "5008", "508", "e-2008", "e-308"],
        "Polestar": ["2", "3", "4"],
        "Porsche": ["718", "911", "Cayenne", "Macan", "Panamera", "Taycan", "Taycan Cross Turismo"],
        "Proton": ["Persona", "S70", "Saga", "X50", "X70", "X90"],
        "Renault": ["Arkana", "Captur", "Kadjar", "Koleos", "Megane E-Tech", "Zoe"],
        "Rolls-Royce": ["Cullinan", "Ghost", "Phantom", "Spectre"],
        "Skoda": ["Enyaq", "Fabia", "Kamiq", "Kodiaq", "Karoq", "Octavia", "Superb"],
        "Smart": ["#1", "#3"],
        "Subaru": ["BRZ", "Forester", "Outback", "WRX", "XV"],
        "Suzuki": ["Ertiga", "Jimny", "Swift", "Vitara"],
        "Tesla": ["Model 3", "Model S", "Model X", "Model Y"],
        "Toyota": ["Alphard", "bZ4X", "Camry", "Corolla", "Corolla Cross", "C-HR", "Fortuner", "Harrier", "Hilux", "Noah", "Prius", "RAV4", "Sienta", "Vellfire", "Voxy", "Yaris", "Yaris Cross"],
        "Volkswagen": ["Arteon", "Golf", "ID.3", "ID.4", "ID.5", "Passat", "Polo", "T-Cross", "Tiguan", "T-Roc", "Touareg"],
        "Volvo": ["C40", "EX30", "EX90", "S60", "S90", "V60", "V90", "XC40", "XC60", "XC90"],
        "XPeng": ["G6", "G9", "P7", "X9"],
        "Zeekr": ["001", "007", "009", "X"]
    ]

    static func models(for brand: String) -> [String] {
        modelsByBrand[brand] ?? []
    }

    static func pickerOptions(for brand: String, including current: String) -> [String] {
        var options = models(for: brand)
        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, !options.contains(trimmed), trimmed != other {
            options.append(trimmed)
        }
        options.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        options.append(other)
        return options
    }

    static func hasCatalogModels(for brand: String) -> Bool {
        !models(for: brand).isEmpty
    }
}
