import Foundation

/// Synchronous, atomic writes make each UI mutation a small transaction.
/// The UI publishes its candidate collection only after save succeeds.
struct EventStore {
    let url: URL

    func load(calendar: Calendar) throws -> EventCollection {
        guard FileManager.default.fileExists(atPath: url.path) else { return EventCollection() }
        let value = try JSONDecoder().decode(EventCollection.self, from: Data(contentsOf: url))
        try value.validate(calendar: calendar)
        return value
    }

    func save(_ collection: EventCollection, calendar: Calendar) throws {
        try collection.validate(calendar: calendar)
        let folder = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(collection)
        #if os(iOS)
        try bytes.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try bytes.write(to: url, options: .atomic)
        #endif
    }
}
