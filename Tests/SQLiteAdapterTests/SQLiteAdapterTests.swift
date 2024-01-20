import XCTest
@testable import SQLiteAdapter

final class SQLiteAdapterTests: XCTestCase {
    func testCreatingAndOpeningDB() throws {
        let sql = try? SQLite(path: "")
        XCTAssertEqual(sql != nil, true)
    }
}
