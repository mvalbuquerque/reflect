//
// Drive.swift
// ReflectFramework
//
// Created by Bruno Fernandes on 18/03/16.
// Copyright © 2016 BFS. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

/// Drive Class execute instrution on Data Base
internal class Driver<T>: DriverProtocol where T:ReflectProtocol {
   
    /// Connection with data base SQLite
    fileprivate lazy var db: Connection = {
        return Reflect.settings.getConnection()
    }()
    /**
     Create object
     
     - parameter obj: Reflect Object
     
     - throws: `Result.Error`
     */
    internal func create(_ obj: T.Type) throws {
        let rft = obj.init()
        let schema = Schema.create(rft)
        try db.execute(schema.statement.sql)
    }
    /**
     Destroy object
     
     - parameter obj: Reflect Object
     
     - throws: `Result.Error`
     */
    internal func drop(_ obj: T.Type) throws {
        let schema = Schema<T>.drop(T.entityName())
        try db.execute(schema.statement.sql)
    }
    /**
     Create Index
     
     - parameter obj:    Object Reflect
     - parameter field:  Column names that the index will be applied
     - parameter unique: True if the index should be unique, false if it should not be unique (defaults to false)
     
     - throws: `Result.Error`
     */
    internal func index(_ obj:T.Type, field: String, unique: Bool = false) throws {
        let schema = Schema<T>.index(entity: obj.entityName(), field: field, unique: unique)
        try db.run(schema)
    }
    /**
     Delete all Object
     
     - parameter obj: Object Reflect
     - parameter field:  Column names that the index will be applied
     
     - throws: `Result.Error`
     */
    internal func dropIndex(_ obj: T.Type, field: String) throws {
        let schema = Schema<T>.dropIndex(entity: T.entityName(), field: field)
        try db.run(schema)
    }
    /**
     Delete all Object
     
     - parameter obj: Object Reflect
     
     - throws: `Result.Error`
     */
    internal func removeAll(_ obj: T.Type) throws {
        let rft = obj.init()
        try db.runChange(Schema.delete(rft))
    }
    /**
     Save or Update Object
     
     - parameter obj: Object Reflect
     
     - throws: `Result.Error`
     */
    internal func save(_ obj: T) throws {
        var rft = obj
        if rft.objectId == nil {
            let rowId = try db.runRowId(Schema.insert(rft))
            rft.objectId = NSNumber(value: rowId as Int64)
        }
        else{
            try change(obj)
        }
    }
    /**
     Change Object
     
     - parameter obj: Object Reflect
     
     - throws:  `Result.Error`
     
     - returns: total of changes
     */
    @discardableResult
    internal func change(_ obj: T) throws -> Int {
        return Int(try db.runChange(Schema.update(obj)))
    }
    /**
     Delete Object
     
     - parameter obj: Object Reflect
     
     - throws: `Result.Error`
     
     - returns: total of changes
     */
    @discardableResult
    internal func delete(_ obj: T) throws -> Int {
        return try db.runChange(Schema.delete(obj))
    }
    /**
     Select One
     
     - parameter obj:     Object Reflect
     - parameter include: Class in conform with protocol Reflect Protocol
     
     - throws:  `Result.Error`
     */
    internal func fetch(_ obj: T, include:[Any.Type] = []) throws {
        let q = Query<T>().filter("\(T.entityName()).objectId", Comparison.equals, value: obj.objectId!.int64Value)
        
        for k in include {
            if let sub = k as? Reflect.Type {
                q.join(sub)
            }
        }
        
        if let row = try db.prepareFetch(q) {
            objectsForType(obj as! Reflect, row: row)
        }
        else{
            throw Result.error(message: "Not found", code: 1001, statement: nil)
        }
    }
    /**
     Select Object with objectId
     
     - parameter id:      objectId selected
     - parameter include: Class in conform with protocol Reflect Protocol
     
     - throws: `Result.Error`
     
     - returns: return a new instance to Object Reflect
     */
    internal func find(_ id: Int, include:[Any.Type] = []) throws -> T? {
        var rft = T()
        rft.objectId = NSNumber(value: id)
        try fetch(rft, include: include)
        return rft
    }
    /**
     Select Objects with Query Filter
     
     - parameter query: Query filter
     
     - throws: `Result.Error`
     
     - returns: return a new instances to Objects of type Reflect
     */
    internal func find(_ query: Query<T>) throws -> [T] {
        
        var results:[T] = []
        for row in try db.prepareQuery(query)! {
            let obj:T = T()
            objectsForType(obj as! Reflect, row: row)
            results.append(obj)
        }
        return results
    }
    /**
     Select Objects
     
     - parameter query: String query
     
     - throws: `Result.Error`
     
     - returns: return Array Dictionary
     */
    internal func find(_ query: String) throws -> [[String: Value?]] {
    
        let stmt = try db.prepare(query,[])
        var results:[[String: Value?]] = []
        for row in stmt {
            var item:[String: Value?] = [:]
            for (index, name) in stmt.columnNames.enumerated() {
                item[name] = row[index]!
            }
            results.append(item)
        }
        return results
    }
    /**
     Select Object
     
     - parameter query:  Query object
     - parameter column: Field name
     
     - throws: `Result.Error`
     
     - returns: Return a value
     */
    internal func scalar(_ query: Query<T>, column:String) throws -> Value? {
        return try db.scalar(query)
    }
    /**
     Transaction Object
     
     - parameter obj:  Object
     - parameter callBack: Call back to querys
     
     - throws: `Result.Error`
     
     */
    internal func transaction(_ obj: T.Type, callback: @escaping () throws -> Void) throws {
        return try db.transaction(block: callback)
    }
    
    internal func log(_ callback: ((String) -> Void)?) {
        db.trace(callback)
    }
}
// MARK: Extension Driver Methods Private
private extension Driver {
    /**
     Get objects of a specified type, matching a filter, from the database
     
     - parameter object: Reflect Object
     - parameter row:    Row Object Data Base
     - parameter alias:  alias name to find subscript Row
     */
    func objectsForType<T>(_ object: T, row: Row, alias:String = "") where T: ReflectProtocol, T: NSObject {
        
        let propertyData = ReflectData.validPropertyDataForObject(object)
        for property in propertyData {
            if property.isClass {
                if let sub = property.type as? Reflect.Type {
                    let objectSub = sub.init()
                    objectsForType(objectSub, row: row, alias: "\(sub.entityName()).")
                    object.setValue(objectSub, forKey: property.name!)
                }
            }
            else{
                let column = "\(alias)\(property.name!)"
                if let value = bindValue(property.type, column: column, row: row) {
                    object.setValue(value, forKey: property.name!)
                }
            }
        }
    }
    /**
     Bind Value
     
     - parameter type:   Type Object
     - parameter column: column name data Base
     - parameter row:    Row Object
     
     - returns: retunr object valid if nothing nil
     */
    func bindValue(_ type: Any.Type?, column:String, row:Row) -> Any? {
        if row[column] {
            switch type {
            case is String.Type, is NSString.Type:
                return row[column].asString()
            case is Int.Type, is Int8.Type, is Int16.Type, is Int32.Type:
                return row[column].asInt()
            case is UInt.Type, is UInt8.Type, is UInt16.Type, is UInt32.Type:
                return row[column].asInt()
            case is Int64.Type, is UInt64.Type:
                return row[column].asInt()
            case is Double.Type:
                return row[column].asDouble()
            case is Float.Type:
                return row[column].asFloat()
            case is Bool.Type:
                return row[column].asBool()
            case is NSNumber.Type:
                return row[column].asNumber()
            case is Date.Type:
                return row[column].asDate()
            case is Data.Type:
                return row[column].asData()
            default:
                return nil
            }
        }
        return nil
    }
}
