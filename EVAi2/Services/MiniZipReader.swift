import Foundation
import zlib

enum MiniZipError: LocalizedError {
    case invalidArchive
    case entryNotFound(String)
    case decompressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidArchive: "The Excel file is not a valid archive."
        case .entryNotFound(let name): "Missing archive entry: \(name)."
        case .decompressionFailed: "Failed to decompress Excel workbook data."
        }
    }
}

enum MiniZipReader {
    static func extractEntry(named name: String, from archive: Data) throws -> Data {
        let target = name.replacingOccurrences(of: "\\", with: "/")
        var offset = 0

        while offset + 30 <= archive.count {
            guard archive[offset] == 0x50, archive[offset + 1] == 0x4B else {
                offset += 1
                continue
            }

            let signature = archive.readUInt32LE(at: offset)
            if signature == 0x02014b50 || signature == 0x06054b50 {
                break
            }
            guard signature == 0x04034b50 else {
                offset += 1
                continue
            }

            let compressionMethod = archive.readUInt16LE(at: offset + 8)
            let compressedSize = Int(archive.readUInt32LE(at: offset + 18))
            let uncompressedSize = Int(archive.readUInt32LE(at: offset + 22))
            let nameLength = Int(archive.readUInt16LE(at: offset + 26))
            let extraLength = Int(archive.readUInt16LE(at: offset + 28))

            let nameStart = offset + 30
            guard nameStart + nameLength <= archive.count else {
                throw MiniZipError.invalidArchive
            }

            let entryName = String(data: archive.subdata(in: nameStart ..< nameStart + nameLength), encoding: .utf8) ?? ""
            let dataStart = nameStart + nameLength + extraLength
            let dataEnd = dataStart + compressedSize
            guard dataEnd <= archive.count else {
                throw MiniZipError.invalidArchive
            }

            let compressedData = archive.subdata(in: dataStart ..< dataEnd)
            offset = dataEnd

            if entryName == target {
                switch compressionMethod {
                case 0:
                    return compressedData
                case 8:
                    return try inflateRawDeflate(compressedData, expectedSize: uncompressedSize)
                default:
                    throw MiniZipError.decompressionFailed
                }
            }
        }

        throw MiniZipError.entryNotFound(name)
    }

    private static func inflateRawDeflate(_ data: Data, expectedSize: Int) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw MiniZipError.decompressionFailed
        }
        defer { _ = inflateEnd(&stream) }

        let capacity = max(expectedSize, 1024)
        var output = Data(count: capacity)

        let status: Int32 = try data.withUnsafeBytes { rawInput in
            guard let inputPointer = rawInput.bindMemory(to: Bytef.self).baseAddress else {
                throw MiniZipError.decompressionFailed
            }

            stream.next_in = UnsafeMutablePointer(mutating: inputPointer)
            stream.avail_in = uInt(data.count)

            return try output.withUnsafeMutableBytes { rawOutput in
                guard let outputPointer = rawOutput.bindMemory(to: Bytef.self).baseAddress else {
                    throw MiniZipError.decompressionFailed
                }
                stream.next_out = outputPointer
                stream.avail_out = uInt(capacity)
                return inflate(&stream, Z_FINISH)
            }
        }

        guard status == Z_STREAM_END else {
            throw MiniZipError.decompressionFailed
        }

        output.count = capacity - Int(stream.avail_out)
        return output
    }
}

private extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset])
            | (UInt32(self[offset + 1]) << 8)
            | (UInt32(self[offset + 2]) << 16)
            | (UInt32(self[offset + 3]) << 24)
    }
}
