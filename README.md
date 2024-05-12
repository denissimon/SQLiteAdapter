# SQLiteAdapter

[![Swift](https://img.shields.io/badge/Swift-5-orange.svg?style=flat)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-lightgrey.svg)](https://developer.apple.com/swift/)

A simple wrapper around the SQLite3 API.

Installation
------------

#### Swift Package Manager

To install SQLiteAdapter using [Swift Package Manager](https://swift.org/package-manager):

```txt
Xcode: File -> Add Packages
Enter Package URL: https://github.com/denissimon/SQLiteAdapter
```

#### CocoaPods

To install SQLiteAdapter using [CocoaPods](https://cocoapods.org), add this line to your `Podfile`:

```ruby
pod 'SQLiteAdapter', '~> 0.6'
```

#### Carthage

To install SQLiteAdapter using [Carthage](https://github.com/Carthage/Carthage), add this line to your `Cartfile`:

```ruby
github "denissimon/SQLiteAdapter"
```

#### Manually

Copy folder `SQLiteAdapter` into your project.

Usage
-----

**Opening the database:**

```swift
import SQLiteAdapter

// The sqlite file will be created in the specified path if it has not yet been created
let dbPath = try! (FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("db.sqlite")).path
let sqlite = try? SQLite(path: dbPath) // with 'recreate: true', the sqlite file will be deleted and recreated

print(sqlite.dbPath) // -> the path of the sqlite file
```

**Modeling and creating an SQL table:**

```swift
let sqlTable = SQLTable(
    name: "ExampleTable",
    columns: [
        ("id", .INT),
        ("json", .TEXT),
        ("isDeleted", .BOOL),
        ("updated", .DATE)
    ],
    primaryKey: "id" // optionally ("id" by default)
)

let statementCreateTable = """
    CREATE TABLE IF NOT EXISTS "\(sqlTable.name)"(
        "\(sqlTable.primaryKey)" INTEGER NOT NULL,
        "json" TEXT NULL,
        "isDeleted" BOOLEAN DEFAULT 0 NOT NULL CHECK (isDeleted IN (0, 1)),
        "updated" DATETIME NOT NULL,
        PRIMARY KEY("\(sqlTable.primaryKey)" AUTOINCREMENT)
    );
    """

try? sqlite?.createTable(sql: statementCreateTable)
```

**SQL operations:**

```swift
do {
    var sql = "INSERT INTO \(sqlTable.name) (json, updated) VALUES (?, ?);"
    let _ = try sqlite.insertRow(sql: sql, params: ["someJson", Date()])
    
    sql = "INSERT INTO \(sqlTable.name) (json, updated) VALUES (?, ?), (?, ?);"
    let lastInsertID = try sqlite.insertRow(sql: sql, params: [nil, Date(), nil, Date()])
    assert(lastInsertID == 3)
    
    sql = "UPDATE \(sqlTable.name) SET isDeleted = ?, updated = ? WHERE \(sqlTable.primaryKey) IN (2, 3)"
    try sqlite.updateRow(sql: sql, params: [true, Date()])
    assert(sqlite.changes == 2)
    
    sql = "SELECT * FROM \(sqlTable.name) WHERE isDeleted = ?"
    let rows = try sqlite.getRow(from: sqlTable, sql: sql, params: [true])
    assert(rows.count == 2)
    
    try sqlite.deleteByID(in: sqlTable, id: 2)
    try sqlite.deleteByID(in: sqlTable, id: 3)
    
    let rowCount = try sqlite.getRowCount(in: sqlTable)
    assert(rowCount == 1)
    
    var row = try sqlite.getFirstRow(from: sqlTable)
    assert(row[0].value as! Int == 1) // "id" INTEGER NOT NULL
    assert(row[1].value as? String == "someJson") // "json" TEXT NULL
    assert(row[2].value as! Bool == false) // "isDeleted" BOOLEAN DEFAULT 0 NOT NULL
    assert((row[3].value as! Date) <= Date()) // "updated" DATETIME NOT NULL
} catch {
    print("SQLite:", error.localizedDescription)
}
```

**Optional settings:**

```swift
sqlite.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
sqlite.dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
sqlite.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
```
 
More usage examples can be found in [SQLiteAdapterTests.swift](https://github.com/denissimon/SQLiteAdapter/blob/main/Tests/SQLiteAdapterTests/SQLiteAdapterTests.swift) and [iOS-MVVM-Clean-Architecture](https://github.com/denissimon/iOS-MVVM-Clean-Architecture) where this adapter was used.

### Supported SQLite types

```swift
case INT // Includes INT, INTEGER, INT2, INT8, BIGINT, MEDIUMINT, SMALLINT, TINYINT
case BOOL // Includes BOOL, BOOLEAN, BIT
case TEXT // Includes TEXT, CHAR, CHARACTER, VARCHAR, CLOB, VARIANT, VARYING_CHARACTER, NATIONAL_VARYING_CHARACTER, NATIVE_CHARACTER, NCHAR, NVARCHAR
case REAL // Includes REAL, DOUBLE, FLOAT, NUMERIC, DECIMAL, DOUBLE_PRECISION
case BLOB // Includes BLOB, BINARY, VARBINARY
case DATE // Includes DATE, DATETIME, TIME, TIMESTAMP
```

### Public methods 

Can be extended and customized by inheriting the [SQLite](https://github.com/denissimon/SQLiteAdapter/blob/main/Sources/SQLiteAdapter/SQLiteAdapter.swift) class.

```swift
func createTable(sql: String) throws
func checkIfTableExists(_ table: SQLTable) throws -> Bool
func dropTable(_ table: SQLTable, vacuum: Bool) throws
func addIndex(to table: SQLTable, forColumn columnName: String, unique: Bool, order: SQLOrder) throws
func checkIfIndexExists(in table: SQLTable, indexName: String) throws -> Bool
func dropIndex(in table: SQLTable, forColumn columnName: String) throws
func beginTransaction() throws
func endTransaction() throws
func insertRow(sql: String, params: [Any]?) throws -> Int
func updateRow(sql: String, params: [Any]?) throws
func deleteRow(sql: String, params: [Any]?) throws
func deleteByID(in table: SQLTable, id: Int) throws
func deleteAllRows(in table: SQLTable, vacuum: Bool, resetAutoincrement: Bool) throws
func getRowCount(in table: SQLTable) throws -> Int
func getRowCountWithCondition(sql: String, params: [Any]?) throws -> Int
func getRow(from table: SQLTable, sql: String, params: [Any]?) throws -> [SQLValues]
func getAllRows(from table: SQLTable) throws -> [SQLValues]
func getByID(from table: SQLTable, id: Int) throws -> SQLValues
func getFirstRow(from table: SQLTable) throws -> SQLValues
func getLastRow(from table: SQLTable) throws -> SQLValues
func vacuum() throws
func query(sql: String, params: [Any]?) throws
```

License
-------

Licensed under the [MIT license](https://github.com/denissimon/SQLiteAdapter/blob/main/LICENSE)
