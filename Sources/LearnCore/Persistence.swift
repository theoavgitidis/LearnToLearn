import Foundation

public struct LibraryRepository {
    public let url: URL
    public var backupURL: URL { url.appendingPathExtension("backup") }
    public init(url: URL) { self.url = url }
    public static var standard: LibraryRepository {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return .init(url: base.appendingPathComponent("LearnToLearn", isDirectory: true).appendingPathComponent("library.json"))
    }
    public func load() throws -> LearningLibrary? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Self.decodeBackup(Data(contentsOf: url))
    }
    public func save(_ library: LearningLibrary) throws {
        let data = try Self.encodeBackup(library)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let existing = try Data(contentsOf: url)
            // Never replace the last good backup with an invalid file.
            _ = try Self.decodeBackup(existing)
            try existing.write(to: backupURL, options: .atomic)
        }
        try data.write(to: url, options: .atomic)
    }
    public static func encodeBackup(_ library: LearningLibrary) throws -> Data {
        _ = try library.validated()
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(library)
    }
    public static func decodeBackup(_ data: Data) throws -> LearningLibrary {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LearningLibrary.self, from: data).validated()
    }
}
