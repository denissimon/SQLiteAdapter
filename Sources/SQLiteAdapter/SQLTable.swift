//
//  SQLTable.swift
//  https://github.com/denissimon/SQLiteAdapter
//
//  Created by Denis Simon on 10/04/2024.
//
//  MIT License (https://github.com/denissimon/SQLiteAdapter/blob/main/LICENSE)
//

open class SQLTable {
    
    public let name: String
    public let columnTypes: SQLValues
    public let primaryKey: String
    
    public init(name: String, columnTypes: SQLValues, primaryKey: String = "id") {
        self.name = name
        self.columnTypes = columnTypes
        self.primaryKey = primaryKey
    }
}
