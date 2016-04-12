//
//  QueryFrameworkTest.swift
//  ReflectFramework
//
//  Created by Bruno Fernandes on 11/04/16.
//  Copyright © 2016 BFS. All rights reserved.
//

import XCTest
@testable import ReflectFramework

class QueryFrameworkTest: XCTestCase {

    var trace:[String] = []
    
    override func setUp() {
        super.setUp()
        
        Reflect.configuration("", baseNamed: "Tests.db")
        Reflect.settings.log { (SQL:String) in
            self.trace.append(SQL)
        }
        
        //populateData()
        populateDataFake()
        
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testQueryObjectClass() {
        trace = []
        /**
         Find an Object
         */
        var usr1 = User.findById(1)
        XCTAssertTrue(trace[0] == "SELECT * FROM User WHERE User.objectId = 1;", "it isn't compatible")
        XCTAssertTrue(usr1!.address.objectId == nil , "it isn't compatible")
        
        // Include another object
        // type Reflect Object
        usr1 = User.findById(1, include: Address.self)
        XCTAssertTrue(trace[1] == "SELECT Address.objectId AS 'Address.objectId', Address.createdAt AS 'Address.createdAt', Address.updatedAt AS 'Address.updatedAt', Address.street AS 'Address.street', Address.number AS 'Address.number', Address.state AS 'Address.state', Address.zip AS 'Address.zip', User.* FROM User INNER JOIN Address ON User.Address_objectId = Address.objectId WHERE User.objectId = 1;", "it isn't compatible")
        XCTAssertTrue(usr1!.address.objectId != nil , "it isn't compatible")
        
        /**
         Fetch an Object
         */
        let usr2 = User()
        usr2.objectId = 2
        usr2.fetch()
        XCTAssertTrue(trace[2] == "SELECT * FROM User WHERE User.objectId = 2;", "it isn't compatible")
        XCTAssertTrue(usr2.address.objectId == nil , "it isn't compatible")
        
        // Include another object
        // type Reflect Object
        usr2.fetch(include: Address.self)
        XCTAssertTrue(trace[3] == "SELECT Address.objectId AS 'Address.objectId', Address.createdAt AS 'Address.createdAt', Address.updatedAt AS 'Address.updatedAt', Address.street AS 'Address.street', Address.number AS 'Address.number', Address.state AS 'Address.state', Address.zip AS 'Address.zip', User.* FROM User INNER JOIN Address ON User.Address_objectId = Address.objectId WHERE User.objectId = 2;", "it isn't compatible")
        XCTAssertTrue(usr2.address.objectId != nil , "it isn't compatible")
    
    }
    
    func testQueryFilter() {
    
        trace = []
        /**
         Filter Objects
         
         Key to compare:
         Equals, GreaterThan, LessThan, NotEquals, In, NotIn, Is, Like, NotLike
         
        */
        
        /**
         Equals
        */
        var query = User.query()
        
        query.filter("age", .Equals, value: 25)
        var users = query.findObject()
    
        var usersFake = userList.filter { (u:User) -> Bool in
            u.age == 25
        }
        
        XCTAssertTrue(trace[0] == "SELECT * FROM User WHERE age = 25;", "it isn't compatible")
        XCTAssertTrue(users.count == usersFake.count , "it isn't compatible")
        
        /**
         Not Equals
         */
        query = User.query()
        query.filter("gender", .NotEquals, value: "male")
        
        users = query.findObject()
        
        usersFake = userList.filter { (u:User) -> Bool in
            u.gender != "male"
        }
        
        XCTAssertTrue(trace[1] == "SELECT * FROM User WHERE gender != 'male';", "it isn't compatible")
        XCTAssertTrue(users.count == usersFake.count , "it isn't compatible")
        
        /**
         Greater Than
         */
        query = User.query()
        query.filter("registerNumber", .GreaterThan, value: 5000)
        
        users = query.findObject()
    
        usersFake = userList.filter { (u:User) -> Bool in
            u.registerNumber > 5000
        }
        
        XCTAssertTrue(trace[2] == "SELECT * FROM User WHERE registerNumber > 5000;", "it isn't compatible")
        XCTAssertTrue(users.count == usersFake.count , "it isn't compatible")

        /**
         Less Than
        */
        query = User.query()
        query.filter("registerNumber", Comparison.LessThan, value: 4500)
        
        users = query.findObject()
    
        usersFake = userList.filter { (u:User) -> Bool in
            u.registerNumber < 4500
        }
        
        XCTAssertTrue(trace[3] == "SELECT * FROM User WHERE registerNumber < 4500;", "it isn't compatible")
        XCTAssertTrue(users.count == usersFake.count , "it isn't compatible")
        
        /**
         In
         */
        var query2 = Address.query()
        query2.filter("state", .In, value: "MI", "GA", "LI")
        
        var addresses = query2.findObject()
        
        var addressesFake = addressList.filter { (a:Address) -> Bool in
            a.state == "MI" || a.state == "GA" || a.state == "LI"
        }
        
        XCTAssertTrue(trace[4] == "SELECT * FROM Address WHERE state IN ('MI' , 'GA' , 'LI');", "it isn't compatible")
        XCTAssertTrue(addresses.count == addressesFake.count , "it isn't compatible")
        
        /**
         Not In
         */
        query2 = Address.query()
        query2.filter("number", .NotIn, value: 105, 226, 760, 728)
        
        addresses = query2.findObject()
        
        addressesFake = addressList.filter { (a:Address) -> Bool in
            a.number != 105 && a.number != 226 && a.number != 760 && a.number != 728
        }
        
        XCTAssertTrue(trace[5] == "SELECT * FROM Address WHERE number NOT IN (105 , 226 , 760 , 728);", "it isn't compatible")
        XCTAssertTrue(addresses.count == addressesFake.count , "it isn't compatible")
        
        /**
         Is
        */
        query2 = Address.query()
        query2.filter("updatedAt", .Is, value: nil)
        
        addresses = query2.findObject()

        XCTAssertTrue(trace[6] == "SELECT * FROM Address WHERE updatedAt IS NULL;", "it isn't compatible")
        XCTAssertTrue(addresses.first!.street == "Value null", "it isn't compatible")

        /**
         Like
         Example : 'A%' '%A' '%a%'
         */
        query = User.query()
        query.filter("firstName", .Like, value: "A%")
        
        users = query.findObject()
        
        usersFake = userList.filter { (u:User) -> Bool in
            u.firstName.hasPrefix("A")
        }
        
        XCTAssertTrue(trace[7] == "SELECT * FROM User WHERE firstName LIKE 'A%';", "it isn't compatible")
        XCTAssertTrue(users.count == usersFake.count , "it isn't compatible")
        
        /**
         Not Like
         Example : 'A%' '%A' '%a%'
         */
        
        query = User.query()
        query.filter("firstName", .NotLike, value: "%mi%")
        
        users = query.findObject()
        
        usersFake = userList.filter { (u:User) -> Bool in
            !u.firstName.contains("mi")
        }
        
        XCTAssertTrue(trace[8] == "SELECT * FROM User WHERE firstName NOT LIKE '%mi%';", "it isn't compatible")
        XCTAssertTrue(users.count == usersFake.count , "it isn't compatible")
    }

    func testQueryFilterAdvanced() {
        trace = []

        /**
         More Filter 
        */
        
        //Basic filters
        var query = User.query()
        
        query.filter("age", .GreaterThan, value: 30)
             .filter("gender", .Equals, value: "male")
        
        var users = query.findObject()
        
        var usersFake = userList.filter { (u:User) -> Bool in
            u.age > 30 && u.gender == "male"
        }
        
        XCTAssertTrue(trace[0] == "SELECT * FROM User WHERE age > 30 AND gender = 'male';", "it isn't compatible")
        XCTAssertTrue(users.count == usersFake.count , "it isn't compatible")
        
        /**
         And / Or
        */
        
        query = User.query()
        
        query.filter("gender", .Equals, value: "female").or { q in
            q.filter("age", .GreaterThan, value: 70)
                .filter("age", .LessThan, value: 20)
        }
        
        users = query.findObject()
        
        usersFake = userList.filter { (u:User) -> Bool in
            u.gender == "female" && (u.age > 70 || u.age < 20)
        }
        
        XCTAssertTrue(trace[1] == "SELECT * FROM User WHERE gender = 'female' AND (age > 70 OR age < 20);", "it isn't compatible")
        XCTAssertTrue(users.count == usersFake.count , "it isn't compatible")
        
        /**
         Join
         */
        
        query = User.query()
        
        query.join(Address.self)
        query.or { q in
            q.filter("gender", .Equals, value: "female").filter("age", .GreaterThan, value: 50)
        }.and { q in
            q.filter("Address.state", .In, value: "MI", "GA", "LI")
        }
        
        users = query.findObject()
        
        usersFake = userList.filter { (u:User) -> Bool in
            (u.gender == "female" || u.age > 50) && (u.address.state == "MI" || u.address.state == "GA" || u.address.state == "LI")
        }
        
        XCTAssertTrue(trace[2] == "SELECT Address.objectId AS 'Address.objectId', Address.createdAt AS 'Address.createdAt', Address.updatedAt AS 'Address.updatedAt', Address.street AS 'Address.street', Address.number AS 'Address.number', Address.state AS 'Address.state', Address.zip AS 'Address.zip', User.* FROM User INNER JOIN Address ON User.Address_objectId = Address.objectId WHERE (gender = 'female' OR age > 50) AND (Address.state IN ('MI' , 'GA' , 'LI'));", "it isn't compatible")
        XCTAssertTrue(users.count == usersFake.count , "it isn't compatible")
    }
    
    func testQueryAggregate() {
        
        trace = []
        /**
         Count Object
         */
        let query = User.query()
        let count = query.count()
        XCTAssertTrue(trace[0] == "SELECT COUNT(*) AS count FROM User", "it isn't compatible")
        XCTAssertTrue(count == Double(userList.count), "it isn't compatible")
        
        /**
         Sum Object
         */
        let sum = query.sum("age")
        XCTAssertTrue(trace[1] == "SELECT SUM(age) AS value FROM User", "it isn't compatible")
        
        let agesTotal:Int = userList.map {
            return $0.age
            }.reduce(0) {
                return $0 + $1
        }
        
        XCTAssertTrue(sum == Double(agesTotal), "it isn't compatible")
        
        /**
         Avg Object
         */
        let avg = query.average("age")
        XCTAssertTrue(trace[2] == "SELECT AVG(age) AS average FROM User", "it isn't compatible")
        XCTAssertTrue(avg == (Double(agesTotal) / count ), "it isn't compatible")
        
        /**
         Max Object
         */
        let max = query.max("birthday") as! String
        XCTAssertTrue(trace[3] == "SELECT MAX(birthday) AS maximum FROM User", "it isn't compatible")
        
        let listDate = userList.map ({ $0.birthday! })
        let maxDate = listDate.reduce(listDate[0]){$0 > $1 ? $1 : $0}.datatypeValue
        
        XCTAssertTrue(maxDate == max, "it isn't compatible")
        

        /**
         Min Object
         */
        let min = query.min("birthday") as! String
        XCTAssertTrue(trace[4] == "SELECT MIN(birthday) AS minimum FROM User", "it isn't compatible")
        
        let minDate = listDate.reduce(listDate[0]){$0 < $1 ? $1 : $0}.datatypeValue
        
        XCTAssertTrue(minDate == min, "it isn't compatible")
        
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }

}