import Foundation

enum MiniZipWriter {
    struct Entry {
        let path: String
        let data: Data
    }

    static func archive(entries: [Entry]) -> Data {
        var output = Data()
        var centralDirectory = Data()
        var offset = 0

        for entry in entries {
            let nameData = Data(entry.path.utf8)
            let crc = crc32(entry.data)

            var localHeader = Data()
            localHeader.appendUInt32LE(0x0403_4b50)
            localHeader.appendUInt16LE(20)
            localHeader.appendUInt16LE(0)
            localHeader.appendUInt16LE(0)
            localHeader.appendUInt16LE(0)
            localHeader.appendUInt16LE(0)
            localHeader.appendUInt32LE(crc)
            localHeader.appendUInt32LE(UInt32(entry.data.count))
            localHeader.appendUInt32LE(UInt32(entry.data.count))
            localHeader.appendUInt16LE(UInt16(nameData.count))
            localHeader.appendUInt16LE(0)
            localHeader.append(nameData)

            output.append(localHeader)
            output.append(entry.data)

            var centralHeader = Data()
            centralHeader.appendUInt32LE(0x0201_4b50)
            centralHeader.appendUInt16LE(20)
            centralHeader.appendUInt16LE(20)
            centralHeader.appendUInt16LE(0)
            centralHeader.appendUInt16LE(0)
            centralHeader.appendUInt16LE(0)
            centralHeader.appendUInt16LE(0)
            centralHeader.appendUInt32LE(crc)
            centralHeader.appendUInt32LE(UInt32(entry.data.count))
            centralHeader.appendUInt32LE(UInt32(entry.data.count))
            centralHeader.appendUInt16LE(UInt16(nameData.count))
            centralHeader.appendUInt16LE(0)
            centralHeader.appendUInt16LE(0)
            centralHeader.appendUInt16LE(0)
            centralHeader.appendUInt16LE(0)
            centralHeader.appendUInt32LE(0)
            centralHeader.appendUInt32LE(UInt32(offset))
            centralHeader.append(nameData)
            centralDirectory.append(centralHeader)

            offset += localHeader.count + entry.data.count
        }

        let centralDirectoryOffset = offset
        output.append(centralDirectory)

        var endRecord = Data()
        endRecord.appendUInt32LE(0x0605_4b50)
        endRecord.appendUInt16LE(0)
        endRecord.appendUInt16LE(0)
        endRecord.appendUInt16LE(UInt16(entries.count))
        endRecord.appendUInt16LE(UInt16(entries.count))
        endRecord.appendUInt32LE(UInt32(centralDirectory.count))
        endRecord.appendUInt32LE(UInt32(centralDirectoryOffset))
        endRecord.appendUInt16LE(0)
        output.append(endRecord)

        return output
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0 ..< 8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB8_8320
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFF_FFFF
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
