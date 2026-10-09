import XCTest
@testable import IHateFinderCore

final class FavoritePlacesStoreTests: XCTestCase {
    func testOrderedPlacesSurviveRelaunchAsJSONPaths() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let places = [folder("/favorites/z"), folder("/favorites/a"), folder("/favorites/m")]
        FavoritePlacesStore(defaults: defaults).save(places)

        let data = try XCTUnwrap(defaults.data(forKey: "favorite-places.v1"))
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: data), places.map(\.path))
        let relaunched = FavoritePlacesStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suite)))
        XCTAssertEqual(relaunched.load(), places)
    }

    func testSaveNormalizesDuplicatePathsPreservingFirstOccurrence() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FavoritePlacesStore(defaults: defaults)
        store.save([folder("/favorites/a/../b"), folder("/favorites/c"),
                    folder("/favorites/b"), folder("/favorites/c/.")])

        let data = try XCTUnwrap(defaults.data(forKey: "favorite-places.v1"))
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: data), ["/favorites/b", "/favorites/c"])
        XCTAssertEqual(FavoritePlacesStore(defaults: defaults).load(), [folder("/favorites/b"), folder("/favorites/c")])
    }

    func testLoadNormalizesDuplicateStoredPathsPreservingOrder() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONEncoder().encode(["/favorites/a/../b", "/favorites/c", "/favorites/b", "/favorites/c/."]),
                     forKey: "favorite-places.v1")
        XCTAssertEqual(FavoritePlacesStore(defaults: defaults).load(), [folder("/favorites/b"), folder("/favorites/c")])
    }

    func testRemovalReorderingAndEmptyListReplacePersistedPlaces() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FavoritePlacesStore(defaults: defaults)
        let a = folder("/favorites/a")
        let b = folder("/favorites/b")
        let c = folder("/favorites/c")
        store.save([a, b, c])
        store.save([c, a])
        XCTAssertEqual(FavoritePlacesStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suite))).load(), [c, a])
        store.save([a, c])
        XCTAssertEqual(FavoritePlacesStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suite))).load(), [a, c])
        store.save([])
        XCTAssertEqual(FavoritePlacesStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suite))).load(), [])
        let data = try XCTUnwrap(defaults.data(forKey: "favorite-places.v1"))
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: data), [])
    }

    func testUnavailableFoldersRemainPersisted() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("unavailable", isDirectory: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
        FavoritePlacesStore(defaults: defaults).save([missing])
        XCTAssertEqual(FavoritePlacesStore(defaults: try XCTUnwrap(UserDefaults(suiteName: suite))).load(), [missing])
    }

    func testMissingCorruptAndInvalidStorageLoadsEmptyList() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = FavoritePlacesStore(defaults: defaults, key: "test-favorites")
        XCTAssertEqual(store.load(), [])
        for data in [Data("not-json".utf8), Data("{}".utf8), Data("[42]".utf8),
                     try JSONEncoder().encode(["/valid", "relative"]),
                     try JSONEncoder().encode(["/valid", "/nul\0path"]),
                     try JSONEncoder().encode(["https://example.com/folder"])] {
            defaults.set(data, forKey: "test-favorites")
            XCTAssertEqual(store.load(), [])
        }
        defaults.set("wrong storage type", forKey: "test-favorites")
        XCTAssertEqual(store.load(), [])
        store.save([folder("/valid")])
        XCTAssertEqual(FavoritePlacesStore(defaults: defaults, key: "test-favorites").load(), [folder("/valid")])
        XCTAssertNil(defaults.object(forKey: "favorite-places.v1"))
    }

    func testSaveRejectsNonLocalNonFileRelativeAndNULURLs() throws {
        let (defaults, suite) = try isolatedDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let invalid = try ["https://example.com/folder", "file://server/folder", "file:relative", "file:///nul%00path"]
            .map { try XCTUnwrap(URL(string: $0)) }
        let literalPercentName = try XCTUnwrap(URL(string: "file:///literal%2500path"))
        let store = FavoritePlacesStore(defaults: defaults)
        store.save([folder("/valid")] + invalid + [literalPercentName, folder("/another")])
        let data = try XCTUnwrap(defaults.data(forKey: "favorite-places.v1"))
        XCTAssertEqual(try JSONDecoder().decode([String].self, from: data), ["/valid", "/literal%00path", "/another"])
        XCTAssertEqual(FavoritePlacesStore(defaults: defaults).load(), [folder("/valid"), folder("/literal%00path"), folder("/another")])
    }

    private func folder(_ path: String) -> URL {
        URL(fileURLWithPath: path, isDirectory: true)
    }

    private func isolatedDefaults() throws -> (UserDefaults, String) {
        let suite = "FavoritePlacesStoreTests.\(UUID().uuidString)"
        return (try XCTUnwrap(UserDefaults(suiteName: suite)), suite)
    }
}
