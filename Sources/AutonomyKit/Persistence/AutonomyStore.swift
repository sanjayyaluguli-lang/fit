import Foundation

public enum StoreError: Error, Sendable {
    case unsupportedSchema(Int)
    case corruptFile(String)
}

/// Local-first store. Reads are synchronous from an in-memory copy; writes are
/// debounced to disk atomically. There is no server in the loop and no request
/// that has to succeed for the app to work.
public actor AutonomyStore {
    public private(set) var data: AutonomyData

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var pendingSave: Task<Void, Never>?
    private let saveDebounce: Duration

    public init(fileURL: URL, saveDebounce: Duration = .seconds(1)) throws {
        self.fileURL = fileURL
        self.saveDebounce = saveDebounce

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        if FileManager.default.fileExists(atPath: fileURL.path) {
            let raw = try Data(contentsOf: fileURL)
            do {
                let loaded = try decoder.decode(AutonomyData.self, from: raw)
                guard loaded.schemaVersion <= AutonomyData.currentSchemaVersion else {
                    throw StoreError.unsupportedSchema(loaded.schemaVersion)
                }
                self.data = loaded
            } catch let error as StoreError {
                throw error
            } catch {
                throw StoreError.corruptFile(String(describing: error))
            }
        } else {
            let seeded = AutonomyData.firstRun()
            self.data = seeded
            try Self.write(seeded, to: fileURL, encoder: encoder)
        }
    }

    /// The only way to change anything. Mutations are applied in-memory
    /// immediately and flushed shortly after, so the UI never waits on disk.
    @discardableResult
    public func update<T>(_ mutation: (inout AutonomyData) -> T) -> T {
        let result = mutation(&data)
        scheduleSave()
        return result
    }

    public func flush() async {
        pendingSave?.cancel()
        pendingSave = nil
        saveNow()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [saveDebounce] in
            try? await Task.sleep(for: saveDebounce)
            guard !Task.isCancelled else { return }
            self.saveNow()
        }
    }

    private func saveNow() {
        try? Self.write(data, to: fileURL, encoder: encoder)
    }

    private static func write(_ data: AutonomyData, to url: URL, encoder: JSONEncoder) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoded = try encoder.encode(data)
        // Atomic so a crash mid-write can never leave a half-file behind.
        try encoded.write(to: url, options: [.atomic])
    }

    /// Default location: the app's own Application Support directory, which is
    /// backed up by iCloud only if the owner turns that on in Settings.
    public static func defaultFileURL(
        fileManager: FileManager = .default,
        appFolder: String = "Autonomy"
    ) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return base
            .appendingPathComponent(appFolder, isDirectory: true)
            .appendingPathComponent("autonomy.json", isDirectory: false)
    }
}
