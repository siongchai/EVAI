import Foundation

struct XLSXWorksheetRow: Equatable {
    let rowIndex: Int
    let cells: [String: String]
}

enum XLSXWorkbookError: LocalizedError {
    case invalidFormat
    case missingWorksheet
    case missingHeader

    var errorDescription: String? {
        switch self {
        case .invalidFormat: "The Excel file format is not supported."
        case .missingWorksheet: "No worksheet was found in the Excel file."
        case .missingHeader: "The worksheet header row could not be recognized."
        }
    }
}

enum XLSXWorkbookReader {
    static func readRows(from workbookData: Data) throws -> [XLSXWorksheetRow] {
        let sharedStringsData = try MiniZipReader.extractEntry(named: "xl/sharedStrings.xml", from: workbookData)
        let sharedStrings = parseSharedStrings(from: sharedStringsData)

        let sheetData: Data
        do {
            sheetData = try MiniZipReader.extractEntry(named: "xl/worksheets/sheet1.xml", from: workbookData)
        } catch MiniZipError.entryNotFound {
            throw XLSXWorkbookError.missingWorksheet
        }

        return parseSheetRows(from: sheetData, sharedStrings: sharedStrings)
    }

    private static func parseSharedStrings(from data: Data) -> [String] {
        let parser = SharedStringsXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        _ = xmlParser.parse()
        return parser.strings
    }

    private static func parseSheetRows(from data: Data, sharedStrings: [String]) -> [XLSXWorksheetRow] {
        let parser = SheetXMLParser(sharedStrings: sharedStrings)
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        _ = xmlParser.parse()
        return parser.rows
            .sorted { $0.key < $1.key }
            .map { XLSXWorksheetRow(rowIndex: $0.key, cells: $0.value) }
    }
}

// MARK: - Shared strings

private final class SharedStringsXMLParser: NSObject, XMLParserDelegate {
    private(set) var strings: [String] = []
    private var currentParts: [String] = []
    private var isTextElement = false

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "si" {
            currentParts = []
        }
        if elementName == "t" {
            isTextElement = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isTextElement {
            currentParts.append(string)
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "t" {
            isTextElement = false
        }
        if elementName == "si" {
            strings.append(currentParts.joined())
            currentParts = []
        }
    }
}

// MARK: - Sheet rows

private final class SheetXMLParser: NSObject, XMLParserDelegate {
    private let sharedStrings: [String]
    private(set) var rows: [Int: [String: String]] = [:]

    private var currentRow = 0
    private var currentColumn = ""
    private var currentCellType = ""
    private var currentValue = ""
    private var isValueElement = false

    init(sharedStrings: [String]) {
        self.sharedStrings = sharedStrings
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        switch elementName {
        case "row":
            currentRow = Int(attributeDict["r"] ?? "") ?? currentRow
        case "c":
            currentColumn = columnLetters(from: attributeDict["r"] ?? "")
            currentCellType = attributeDict["t"] ?? ""
            currentValue = ""
        case "v":
            isValueElement = true
            currentValue = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isValueElement {
            currentValue += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "v" {
            isValueElement = false
        }
        if elementName == "c" {
            guard !currentColumn.isEmpty, currentRow > 0 else { return }
            let resolved = resolveValue(currentValue, type: currentCellType)
            rows[currentRow, default: [:]][currentColumn] = resolved
        }
    }

    private func resolveValue(_ raw: String, type: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard type == "s", let index = Int(trimmed), sharedStrings.indices.contains(index) else {
            return trimmed
        }
        return sharedStrings[index]
    }

    private func columnLetters(from cellReference: String) -> String {
        String(cellReference.prefix { $0.isLetter })
    }
}
