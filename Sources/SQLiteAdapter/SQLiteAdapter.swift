//
//  SQLiteAdapter.swift
//  https://github.com/denissimon/SQLiteAdapter
//
//  Created by Denis Simon on 14/01/2024.
//
//  MIT License (https://github.com/denissimon/SQLiteAdapter/blob/main/LICENSE)
//

import Foundation
import SQLite3

public enum SQLiteError: Error {
    case OpenDB(_ msg: String)
    case Prepare(_ msg: String)
    case Step(_ msg: String)
    case Bind(_ msg: String)
    case Column(_ msg: String)
    case Statement(_ msg: String)
    case Other(_ msg: String)
}

// http://www.sqlite.org/datatype3.html
public enum SQLType {
    case INT // Includes INT, INTEGER, INT2, INT8, BIGINT, MEDIUMINT, SMALLINT, TINYINT
    case BOOL // Includes BOOL, BOOLEAN, BIT
    case TEXT // Includes TEXT, CHAR, CHARACTER, VARCHAR, CLOB, VARIANT, VARYING_CHARACTER, NATIONAL_VARYING_CHARACTER, NATIVE_CHARACTER, NCHAR, NVARCHAR
    case REAL // Includes REAL, NUMERIC, DECIMAL, FLOAT, DOUBLE, DOUBLE_PRECISION
    case BLOB // Includes BLOB, BINARY, VARBINARY
    case NULL
    // TODO: DATE, DATETIME, TIME, TIMESTAMP
}

public enum SQLOrder {
    case ASC
    case DESC
    case none
}

/// enum SQLType has the following cases:
/// case INT (includes INT, INTEGER, INT2, INT8, BIGINT, MEDIUMINT, SMALLINT, TINYINT, BIT)
/// case BOOL (includes BOOL, BOOLEAN
/// case TEXT (includes TEXT, CHAR, CHARACTER, VARCHAR, CLOB, VARIANT, VARYING_CHARACTER, NATIONAL_VARYING_CHARACTER, NATIVE_CHARACTER, NCHAR, NVARCHAR)
/// case REAL (includes REAL, NUMERIC, DECIMAL, FLOAT, DOUBLE, DOUBLE_PRECISION)
/// case BLOB (includes BLOB, BINARY, VARBINARY)
/// case NULL
public typealias SQLValues = [(type: SQLType, value: Any?)]

public protocol SQLiteType {
    func createTable(sql: String) throws
    func checkIfTableExists(_ tableName: String) throws -> Bool
    func dropTable(_ tableName: String, vacuum: Bool) throws
    func addIndex(to tableName: String, forColumn columnName: String, unique: Bool, order: SQLOrder) throws
    func checkIfIndexExists(in tableName: String, indexName: String) throws -> Bool
    func dropIndex(in tableName: String, forColumn columnName: String) throws
    func beginTransaction() throws
    func endTransaction() throws
    func insertRow(sql: String, params: [Any]?) throws -> Int
    func updateRow(sql: String, params: [Any]?) throws
    func deleteRow(sql: String, params: [Any]?) throws
    func deleteByID(in tableName: String, id: Int) throws
    func deleteAllRows(in tableName: String, vacuum: Bool, resetAutoincrement: Bool) throws
    func getRowCount(in tableName: String) throws -> Int
    func getRowCountWithCondition(sql: String, params: [Any]?) throws -> Int
    func getRow(sql: String, params: [Any]?, valuesToGet: SQLValues) throws -> [SQLValues]
    func getAllRows(in tableName: String, valuesToGet: SQLValues) throws -> [SQLValues]
    func getByID(in tableName: String, id: Int, valuesToGet: SQLValues) throws -> SQLValues
    func getLastRow(in tableName: String, valuesToGet: SQLValues) throws -> SQLValues
    func getLastInsertID() -> Int
    func vacuum() throws
    func resetAutoincrement(in tableName: String) throws
    func query(sql: String, params: [Any]?) throws
}

open class SQLite: SQLiteType {
    
    public private(set) var dbPointer: OpaquePointer?
    public private(set) var dbPath: String!
    
    private let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
    private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    
    public var dateFormatter = DateFormatter()
    public var primaryKey = "id"
    
    public init(path: String, recreateDB: Bool = false) throws {
        if recreateDB {
            try deleteDB(path: path)
        }
        
        var db: OpaquePointer?
        
        if sqlite3_open(path, &db) == SQLITE_OK {
            dbPointer = db
            dbPath = path
            setUp()
            log("database opened successfully, path: \(path)")
        } else {
            defer {
                if db != nil {
                    sqlite3_close(db)
                }
            }
            dbPointer = nil
            throw SQLiteError.OpenDB(getErrorMessage(dbPointer: db))
        }
    }
    
    deinit {
        if dbPointer != nil {
            sqlite3_close(dbPointer)
            dbPointer = nil
        }
    }
    
    private func setUp() {
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    private func deleteDB(path: String) throws {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: path)
        } catch {
            throw SQLiteError.Other("SQLite file has not been deleted")
        }
    }
    
    private func log(_ str: String) {
        #if DEBUG
        print("SQLite: \(str)")
        #endif
    }
    
    private func getErrorMessage(dbPointer: OpaquePointer?) -> String {
        if let errorPointer = sqlite3_errmsg(dbPointer) {
            let errorMessage = String(cString: errorPointer)
            return errorMessage
        }
        return "SQLite error"
    }
    
    private func prepareStatement(sql: String) throws -> OpaquePointer? {
        var queryStatement: OpaquePointer?
        guard sqlite3_prepare_v2(dbPointer, sql, -1, &queryStatement, nil) == SQLITE_OK else {
            throw SQLiteError.Prepare(getErrorMessage(dbPointer: dbPointer))
        }
        return queryStatement
    }
    
    private func bindPlaceholders(sqlStatement: OpaquePointer?, params: [Any]?) throws {
        guard let params = params else { return }
        
        let paramsCount = sqlite3_bind_parameter_count(sqlStatement)
        let count = params.count
        if paramsCount != Int32(count) {
            throw SQLiteError.Bind(getErrorMessage(dbPointer: dbPointer))
        }
        
        for index in 0...(count-1) {
            
            let index = index+1 // placeholder serial number, should start with 1
            
            var statusCode: Int32 = 0
            
            // Detect placeholder data types
            if let intValue = params[index - 1] as? Int {
                statusCode = sqlite3_bind_int(sqlStatement, Int32(index), Int32(intValue))
            } else if let boolValue = params[index - 1] as? Bool {
                statusCode = sqlite3_bind_int(sqlStatement, Int32(index), Int32(boolValue ? 1 : 0 ))
            } else if let stringValue = params[index - 1] as? NSString {
                statusCode = sqlite3_bind_text(sqlStatement, Int32(index), stringValue.utf8String, -1, SQLITE_TRANSIENT)
            } else if let doubleValue = params[index - 1] as? Double {
                statusCode = sqlite3_bind_double(sqlStatement, Int32(index), doubleValue)
            } else if let data = params[index - 1] as? Data {
                data.withUnsafeBytes { bytes in
                    statusCode = sqlite3_bind_blob(sqlStatement, Int32(index), bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
                }
            } else if let date = params[index - 1] as? Date {
                let dateStr = dateFormatter.string(from: date)
                statusCode = sqlite3_bind_text(sqlStatement, Int32(index), dateStr, -1, SQLITE_TRANSIENT)
            } else {
                statusCode = sqlite3_bind_null(sqlStatement, Int32(index))
            }
            
            guard statusCode == SQLITE_OK else {
                throw SQLiteError.Bind(getErrorMessage(dbPointer: dbPointer))
            }
        }
    }
    
    private func operation(sql: String, params: [Any]? = nil) throws {
        let sqlStatement = try prepareStatement(sql: sql)
        defer {
            sqlite3_finalize(sqlStatement)
        }
        
        try bindPlaceholders(sqlStatement: sqlStatement, params: params)
        
        guard sqlite3_step(sqlStatement) == SQLITE_DONE else {
            throw SQLiteError.Step(getErrorMessage(dbPointer: dbPointer))
        }
    }
    
    public func createTable(sql: String) throws {
        guard sql.uppercased().trimmingCharacters(in: .whitespaces).hasPrefix("CREATE ") else {
            throw SQLiteError.Statement("Invalid SQL statement")
        }
        try operation(sql: sql)
        log("successfully created table, sql: \(sql)")
    }
    
    public func checkIfTableExists(_ tableName: String) throws -> Bool {
        if let count = try? getRowCountWithCondition(sql: "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='\(tableName)';") {
            let result = count == 1 ? true : false
            log("successfully checked if table \(tableName) exists: \(result)")
            return result
        }
        throw SQLiteError.Other(getErrorMessage(dbPointer: dbPointer))
    }
    
    public func dropTable(_ tableName: String, vacuum: Bool = true) throws {
        let sql = "DROP TABLE IF EXISTS \(tableName);"
        try operation(sql: sql)
        if vacuum {
            try self.vacuum()
        }
        log("successfully droped table \(tableName)")
    }
    
    public func addIndex(to tableName: String, forColumn columnName: String, unique: Bool = false, order: SQLOrder = .none) throws {
        
        let indexName = "\(tableName)_\(columnName)_idx"
        
        var sql = ""
        if !unique {
            sql = "CREATE INDEX \"\(indexName)\" ON \"\(tableName)\" (\"\(columnName)\""
        } else {
            sql = "CREATE UNIQUE INDEX \"\(indexName))\" ON \"\(tableName)\" (\"\(columnName)\""
        }
        
        switch order {
        case .ASC:
            sql += " ASC);"
        case .DESC:
            sql += " DESC);"
        case .none:
            sql += ");"
        }
        
        try operation(sql: sql)
        log("successfully added index \(indexName)")
    }
    
    public func checkIfIndexExists(in tableName: String, indexName: String) throws -> Bool {
        if let count = try? getRowCountWithCondition(sql: "SELECT count(*) FROM sqlite_master WHERE type='index' AND tbl_name='\(tableName)' AND name='\(indexName)';") {
            let result = count == 1 ? true : false
            log("successfully checked if index \(indexName) exists: \(result)")
            return result
        }
        throw SQLiteError.Other(getErrorMessage(dbPointer: dbPointer))
    }
    
    public func dropIndex(in tableName: String, forColumn columnName: String) throws {
        let indexName = "\(tableName)_\(columnName)_idx"
        let sql = "DROP INDEX IF EXISTS \"\(indexName)\";"
        try operation(sql: sql)
        log("successfully droped index \(indexName)")
    }
    
    public func beginTransaction() throws {
        let sql = "BEGIN TRANSACTION;"
        try operation(sql: sql)
        log("BEGIN TRANSACTION")
    }
    
    public func endTransaction() throws {
        let sql = "COMMIT;"
        try operation(sql: sql)
        log("COMMIT")
    }
    
    /// Can be used to insert one or several rows depending on the SQL statement
    /// - Returns: The id for the last inserted row
    public func insertRow(sql: String, params: [Any]? = nil) throws -> Int {
        guard sql.uppercased().trimmingCharacters(in: .whitespaces).hasPrefix("INSERT ") else {
            throw SQLiteError.Statement("Invalid SQL statement")
        }
        try operation(sql: sql, params: params)
        log("successfully inserted row(s), sql: \(sql)")
        return getLastInsertID()
    }
    
    /// Can be used to update one or several rows depending on the SQL statement
    public func updateRow(sql: String, params: [Any]? = nil) throws {
        guard sql.uppercased().trimmingCharacters(in: .whitespaces).hasPrefix("UPDATE ") else {
            throw SQLiteError.Statement("Invalid SQL statement")
        }
        try operation(sql: sql, params: params)
        log("successfully updated row(s), sql: \(sql)")
    }
    
    /// Can be used to delete one or several rows depending on the SQL statement
    public func deleteRow(sql: String, params: [Any]? = nil) throws {
        guard sql.uppercased().trimmingCharacters(in: .whitespaces).hasPrefix("DELETE ") else {
            throw SQLiteError.Statement("Invalid SQL statement")
        }
        try operation(sql: sql, params: params)
        log("successfully deleted row(s), sql: \(sql)")
    }
    
    public func deleteByID(in tableName: String, id: Int) throws {
        let sql = "DELETE FROM \(tableName) WHERE \(primaryKey) = ?;"
        try operation(sql: sql, params: [id])
        log("successfully deleted a row by id \(id) in \(tableName)")
    }
    
    public func deleteAllRows(in tableName: String, vacuum: Bool = true, resetAutoincrement: Bool = true) throws {
        let sql = "DELETE FROM \(tableName);"
        try operation(sql: sql)
        log("successfully deleted all rows in \(tableName)")
        if vacuum {
            try self.vacuum()
        }
        if resetAutoincrement {
            try self.resetAutoincrement(in: tableName)
        }
    }
    
    public func getRowCount(in tableName: String) throws -> Int {
        let sql = "SELECT count(*) FROM \(tableName);"
        let sqlStatement = try prepareStatement(sql: sql)
        defer {
            sqlite3_finalize(sqlStatement)
        }
        guard sqlite3_step(sqlStatement) == SQLITE_ROW else {
            throw SQLiteError.Step(getErrorMessage(dbPointer: dbPointer))
        }
        let count = sqlite3_column_int(sqlStatement, 0)
        log("successfully got a row count in \(tableName): \(count)")
        return Int(count)
    }
    
    public func getRowCountWithCondition(sql: String, params: [Any]? = nil) throws -> Int {
        guard sql.uppercased().trimmingCharacters(in: .whitespaces).hasPrefix("SELECT ") else {
            throw SQLiteError.Statement("Invalid SQL statement")
        }
        
        let sqlStatement = try prepareStatement(sql: sql)
        defer {
            sqlite3_finalize(sqlStatement)
        }
        
        try bindPlaceholders(sqlStatement: sqlStatement, params: params)
        
        guard sqlite3_step(sqlStatement) == SQLITE_ROW else {
            throw SQLiteError.Step(getErrorMessage(dbPointer: dbPointer))
        }
        let count = sqlite3_column_int(sqlStatement, 0)
        log("successfully got a row count with condition: \(count), sql: \(sql)")
        return Int(count)
    }
    
    /// Can be used to read one or several rows depending on the SQL statement
    public func getRow(sql: String, params: [Any]? = nil, valuesToGet: SQLValues) throws -> [SQLValues] {
        guard sql.uppercased().trimmingCharacters(in: .whitespaces).hasPrefix("SELECT ") else {
            throw SQLiteError.Statement("Invalid SQL statement")
        }
        
        let sqlStatement = try prepareStatement(sql: sql)
        defer {
            sqlite3_finalize(sqlStatement)
        }
        
        try bindPlaceholders(sqlStatement: sqlStatement, params: params)
        
        var allRows: [SQLValues] = []
        var rowValues: SQLValues = SQLValues([])
        
        while sqlite3_step(sqlStatement) == SQLITE_ROW {
            rowValues = SQLValues([])
            for (index,value) in valuesToGet.enumerated() {
                
                let index = Int32(index) // column serial number, should start with 0
                
                // Check for data types of returned values
                switch value.type {
                case .INT, .BOOL:
                    let intValue = sqlite3_column_int(sqlStatement, index)
                    rowValues.append((value.type, intValue))
                case .TEXT:
                    if let queryResult = sqlite3_column_text(sqlStatement, index) {
                        let stringValue = String(cString: queryResult)
                        rowValues.append((value.type, stringValue))
                    } else {
                        rowValues.append((value.type, nil))
                    }
                case .REAL:
                    let doubleValue = sqlite3_column_double(sqlStatement, index)
                    rowValues.append((value.type, doubleValue))
                case .BLOB:
                    let dataValue = sqlite3_column_blob(sqlStatement, index)
                    rowValues.append((value.type, dataValue))
                default:
                    rowValues.append((value.type, nil))
                }
            }
            allRows.append(rowValues)
        }
        
        log("successfully read row(s), count: \(allRows.count), sql: \(sql)")
        return allRows
    }
    
    public func getAllRows(in tableName: String, valuesToGet: SQLValues) throws -> [SQLValues] {
        let sql = "SELECT * FROM \(tableName);"
        let result = try getRow(sql: sql, valuesToGet: valuesToGet)
        log("successfully read all rows in \(tableName), count: \(result.count)")
        return result
    }
    
    public func getByID(in tableName: String, id: Int, valuesToGet: SQLValues) throws -> SQLValues {
        let sql = "SELECT * FROM \(tableName) WHERE \(primaryKey) = ? LIMIT 1;"
        let result = try getRow(sql: sql, params: [id], valuesToGet: valuesToGet)
        if result.count == 1 {
            log("successfully read a row by id \(id) in \(tableName)")
            return result[0]
        } else {
            throw SQLiteError.Column(getErrorMessage(dbPointer: dbPointer))
        }
    }
    
    public func getLastRow(in tableName: String, valuesToGet: SQLValues) throws -> SQLValues {
        let sql = "SELECT * FROM \(tableName) WHERE \(primaryKey) = (SELECT MAX(\(primaryKey)) FROM \(tableName));"
        let result = try getRow(sql: sql, valuesToGet: valuesToGet)
        if result.count == 1 {
            log("successfully read last row in \(tableName)")
            return result[0]
        } else {
            throw SQLiteError.Column(getErrorMessage(dbPointer: dbPointer))
        }
    }
    
    public func getLastInsertID() -> Int {
        return Int(sqlite3_last_insert_rowid(dbPointer))
    }
    
    /// Repack the DB to take advantage of deleted data
    public func vacuum() throws {
        let sql = "VACUUM;"
        try operation(sql: sql)
        log("VACUUM")
    }
    
    public func resetAutoincrement(in tableName: String) throws {
        let sql = "UPDATE sqlite_sequence SET SEQ=0 WHERE name='\(tableName)';"
        try operation(sql: sql)
        log("successfully reseted autoincrement in \(tableName)")
    }
    
    /// Any other query except reading
    public func query(sql: String, params: [Any]? = nil) throws {
        try operation(sql: sql, params: params)
        log("successful query, sql: \(sql)")
    }
}
