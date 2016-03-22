//
//  Query.swift
//  ReflectFramework
//
//  Created by Bruno Fernandes on 22/03/16.
//  Copyright © 2016 BFS. All rights reserved.
//

import Foundation

class Query<T :Initable>{
    typealias Handler = (query: Query) -> Query
    
    private var dataClause:[Filter]
    private var dataArgs:[AnyObject]
    private var nextPlaceholder: String {
        return "?"
    }
    
    init(){
        dataClause = []
        dataArgs   = []
    }
    
    func filter(key:String, _ comparison: Comparison, value:AnyObject...) -> Self {
        if value.count > 1 {
            dataClause.append(Filter.Subset(key, comparison, value))
        }
        else{
            dataClause.append(Filter.Compare(key, comparison, value.first!))
        }
        return self
    }
    
    func or(handler: Handler) -> Self {
        let q = handler(query: Query())
        let filter = Filter.Group(.Or, q.dataClause)
        dataClause.append(filter)
        return self
    }
    
    func and(handler: Handler) -> Self {
        let q = handler(query: Query())
        let filter = Filter.Group(.And, q.dataClause)
        dataClause.append(filter)
        return self
    }
    
    func list() -> [T]? {
        
        if dataClause.count == 0 {
            return nil
        }
        
        var filterClause: [String] = []
        for filter in dataClause {
            filterClause.append(filterOutput(filter))
        }
        
        let q = "SELECT * FROM \(T.tableName()) WHERE " + filterClause.joinWithSeparator(" AND ")

        return Service<T>().query(q, args: dataArgs)
    }
    
    /*
    // MARK: - Private Methods
    */
    private func filterOutput(filter: Filter) -> String {
        switch filter {
        case .Compare(let field, let comparison, let value):
            dataArgs.append(value)
            return "\(field) \(comparison.description) \(nextPlaceholder)"
        case .Subset(let field, let scope, let values):
            let valueDescriptions = values.map { value in
                dataArgs.append(value)
                return nextPlaceholder
                }.joinWithSeparator(" , ")
            return "\(field) \(scope) (\(valueDescriptions))"
        case .Group(let op, let filters):
            let f: [String] = filters.map {
                if case .Group = $0 {
                    return self.filterOutput($0)
                }
                return "\(self.filterOutput($0))"
            }
            return "(" + f.joinWithSeparator(" \(op.description) ") + ")"
        }
    }
}