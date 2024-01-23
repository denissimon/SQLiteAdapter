import XCTest
@testable import SQLiteAdapter

final class SQLiteAdapterTests: XCTestCase {
    func testCreatingAndOpeningDB() throws {
        let sqliteDB = try? SQLite(path: "")
        XCTAssertEqual(sqliteDB != nil, true)
    }
}
