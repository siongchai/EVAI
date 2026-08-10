import Foundation

enum XLSXCellValue: Equatable {
    case number(Double)
    case text(String)
}

enum XLSXWorkbookWriter {
    static func writeWorkbook(rows: [[String: XLSXCellValue]]) -> Data {
        var sharedStrings: [String] = []
        var sharedStringLookup: [String: Int] = [:]

        func indexForSharedString(_ value: String) -> Int {
            if let index = sharedStringLookup[value] {
                return index
            }
            let index = sharedStrings.count
            sharedStrings.append(value)
            sharedStringLookup[value] = index
            return index
        }

        var sheetRowsXML = ""
        for (rowOffset, row) in rows.enumerated() {
            let rowNumber = rowOffset + 1
            var cellsXML = ""
            for column in ExcelChargingLogLayout.headerColumns {
                guard let value = row[column] else { continue }
                let cellReference = "\(column)\(rowNumber)"
                switch value {
                case .number(let number):
                    cellsXML += """
                    <c r="\(cellReference)"><v>\(formatNumber(number))</v></c>
                    """
                case .text(let text):
                    let index = indexForSharedString(text)
                    cellsXML += """
                    <c r="\(cellReference)" t="s"><v>\(index)</v></c>
                    """
                }
            }
            sheetRowsXML += """
            <row r="\(rowNumber)">\(cellsXML)</row>
            """
        }

        let sharedStringsXML = sharedStrings
            .map { string in
                """
                <si><t>\(xmlEscape(string))</t></si>
                """
            }
            .joined()

        let sheetXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
          <sheetData>
            \(sheetRowsXML)
          </sheetData>
        </worksheet>
        """

        let sharedStringsDocument = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="\(sharedStrings.count)" uniqueCount="\(sharedStrings.count)">
          \(sharedStringsXML)
        </sst>
        """

        let workbookXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
          <sheets>
            <sheet name="Sheet1" sheetId="1" r:id="rId1"/>
          </sheets>
        </workbook>
        """

        let workbookRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        </Relationships>
        """

        let rootRelsXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """

        let contentTypesXML = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
          <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        </Types>
        """

        return MiniZipWriter.archive(entries: [
            .init(path: "[Content_Types].xml", data: Data(contentTypesXML.utf8)),
            .init(path: "_rels/.rels", data: Data(rootRelsXML.utf8)),
            .init(path: "xl/workbook.xml", data: Data(workbookXML.utf8)),
            .init(path: "xl/_rels/workbook.xml.rels", data: Data(workbookRelsXML.utf8)),
            .init(path: "xl/worksheets/sheet1.xml", data: Data(sheetXML.utf8)),
            .init(path: "xl/sharedStrings.xml", data: Data(sharedStringsDocument.utf8))
        ])
    }

    private static func formatNumber(_ value: Double) -> String {
        String(value)
    }

    private static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
