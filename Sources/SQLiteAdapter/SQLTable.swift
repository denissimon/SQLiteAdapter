//
//  SQLTable.swift
//  https://github.com/denissimon/SQLiteAdapter
//
//  Created by Denis Simon on 10/04/2024.
//
//  MIT License (https://github.com/denissimon/SQLiteAdapter/blob/main/LICENSE)
//

final public class SQLTable: Sendable {
    
    public let name: String
    public let columns: SQLTableColums
    public let primaryKey: String
    
    public init(name: String, columns: SQLTableColums, primaryKey: String = "id") {
        self.name = name
        self.columns = columns
        self.primaryKey = primaryKey
    }
}
