import XCTest
#if SWIFT_PACKAGE
@testable import CountdownCore
#else
@testable import CountdownApp
#endif

final class EventStoreTests: XCTestCase {
    private var directory: URL!
    private var store: EventStore!
    private let calendar = DateEngine(timeZone: TimeZone(secondsFromGMT: 0)!).calendar

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("CountdownTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = EventStore(url: directory.appendingPathComponent("events.json"))
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    private var example: CountEvent { CountEvent(kind: .countdown, title: "A trip", date: CalendarDay(year: 2030, month: 5, day: 1)) }

    func testNewCollectionStartsEmpty() throws {
        XCTAssertEqual(try store.load(calendar: calendar), EventCollection())
    }

    func testSaveEditRemoveAndRestoreRoundTrip() throws {
        var collection = EventCollection(events: [example])
        try store.save(collection, calendar: calendar)
        XCTAssertEqual(try store.load(calendar: calendar), collection)
        collection.events[0].title = "A longer adventure"
        try store.save(collection, calendar: calendar)
        XCTAssertEqual(try store.load(calendar: calendar).events[0].title, "A longer adventure")
        let removed = collection.events.removeFirst()
        collection.deleted.append(DeletedEvent(event: removed, deletedAt: Date()))
        try store.save(collection, calendar: calendar)
        let loaded = try store.load(calendar: calendar)
        XCTAssertTrue(loaded.events.isEmpty)
        XCTAssertEqual(loaded.deleted.first?.event, removed)
        collection.events.append(collection.deleted.removeFirst().event)
        try store.save(collection, calendar: calendar)
        XCTAssertEqual(try store.load(calendar: calendar), collection)
    }

    func testMalformedLoadDoesNotTouchFile() throws {
        let bytes = Data("not valid json".utf8)
        try bytes.write(to: store.url)
        XCTAssertThrowsError(try store.load(calendar: calendar))
        XCTAssertEqual(try Data(contentsOf: store.url), bytes)
    }

    func testInvalidSaveDoesNotReplaceValidCollection() throws {
        let good = EventCollection(events: [example])
        try store.save(good, calendar: calendar)
        let bytes = try Data(contentsOf: store.url)
        var invalid = good
        invalid.events[0].title = ""
        XCTAssertThrowsError(try store.save(invalid, calendar: calendar))
        XCTAssertEqual(try Data(contentsOf: store.url), bytes)
    }

    func testDuplicateIdentifiersRejectedAcrossTrashAndActive() throws {
        let event = example
        let collection = EventCollection(events: [event], deleted: [DeletedEvent(event: event, deletedAt: Date())])
        XCTAssertThrowsError(try store.save(collection, calendar: calendar))
    }

    func testUnknownSchemaPreserved() throws {
        let bytes = Data("{\"version\":2,\"events\":[],\"deleted\":[]}".utf8)
        try bytes.write(to: store.url)
        XCTAssertThrowsError(try store.load(calendar: calendar))
        XCTAssertEqual(try Data(contentsOf: store.url), bytes)
    }

    func testWriteFailureIsReported() throws {
        let blocked = directory.appendingPathComponent("file-not-directory")
        try Data("occupied".utf8).write(to: blocked)
        let failing = EventStore(url: blocked.appendingPathComponent("events.json"))
        XCTAssertThrowsError(try failing.save(EventCollection(events: [example]), calendar: calendar))
    }
}
