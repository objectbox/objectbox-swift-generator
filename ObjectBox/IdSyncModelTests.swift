//  Copyright © 2018-2019 ObjectBox. All rights reserved.

import Foundation
import Quick
import Nimble
@testable import Sourcery
@testable import SourceryRuntime
import PathKit


class IdSyncTests: XCTestCase {
    func testEmptyFile() throws {
        let schemaData = Schema()
        
        let jsonFile = URL(fileURLWithPath: "/tmp").appendingPathComponent("model.json")
        try? FileManager.default.removeItem(at: jsonFile)

        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        try idSync.write()
        
        XCTAssertEqual(schemaData.entities.count, 0)
        
        let data = try? Data(contentsOf: jsonFile)
        XCTAssertNotNil(data)
        var jsonContents: IdSync.IdSyncModel?
        if let data = data {
            let decoder = JSONDecoder()
            jsonContents = try? decoder.decode(IdSync.IdSyncModel.self, from: data)
        }
        XCTAssertNotNil(jsonContents)
        if let jsonContents = jsonContents {
            XCTAssertEqual(jsonContents.entities?.count ?? 0, 0)
        }
    }

    func testOneEmptyClassFile() throws {
        let schemaData = Schema()
        let entity = SchemaEntity()
        entity.className = "FirstEntity"
        schemaData.entities.append(entity)
        
        let jsonFile = URL(fileURLWithPath: "/tmp").appendingPathComponent("model.json")
        try? FileManager.default.removeItem(at: jsonFile)
        
        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        try idSync.write()

        XCTAssertEqual(schemaData.entities.count, 1)
        
        let data = try? Data(contentsOf: jsonFile)
        XCTAssertNotNil(data)
        var jsonContents: IdSync.IdSyncModel?
        if let data = data {
            let decoder = JSONDecoder()
            jsonContents = try? decoder.decode(IdSync.IdSyncModel.self, from: data)
        }
        XCTAssertNotNil(jsonContents)
        if let jsonContents = jsonContents {
            XCTAssertEqual(jsonContents.entities?.count ?? 0, 1)
            let entity = jsonContents.entities?.first
            XCTAssertNotNil(entity)
            if let entity = entity {
                XCTAssertEqual(entity.name, "FirstEntity")
                XCTAssertGreaterThanOrEqual(entity.id.id, 0)
                XCTAssertGreaterThanOrEqual(entity.id.uid & ~0xff, 0)
                XCTAssertEqual(entity.properties?.count ?? 0, 0)
                XCTAssertEqual(entity.relations?.count ?? 0, 0)
            }
        }
    }
    
    func testOneMinimalClassFile() throws {
        let schemaData = Schema()
        let entity = SchemaEntity()
        entity.className = "FirstEntity"
        let prop = SchemaProperty()
        prop.propertyName = "identifikationsNummer"
        prop.propertyType = "EntityId<FirstEntity>"
        prop.entityName = "FirstEntity"
        entity.properties.append(prop)
        schemaData.entities.append(entity)
        
        let jsonFile = URL(fileURLWithPath: "/tmp").appendingPathComponent("model.json")
        try? FileManager.default.removeItem(at: jsonFile)
        
        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        try idSync.write()

        XCTAssertEqual(schemaData.entities.count, 1)
        
        let data = try? Data(contentsOf: jsonFile)
        XCTAssertNotNil(data)
        var jsonContents: IdSync.IdSyncModel?
        if let data = data {
            let decoder = JSONDecoder()
            jsonContents = try? decoder.decode(IdSync.IdSyncModel.self, from: data)
        }
        XCTAssertNotNil(jsonContents)
        if let jsonContents = jsonContents {
            XCTAssertEqual(jsonContents.entities?.count ?? 0, 1)
            let entity = jsonContents.entities?.first
            XCTAssertNotNil(entity)
            if let entity = entity {
                XCTAssertEqual(entity.name, "FirstEntity")
                XCTAssertGreaterThan(entity.id.id, 0)
                XCTAssertGreaterThan(entity.id.uid & ~0xff, 0)
                XCTAssertEqual(entity.properties?.count ?? 0, 1)
                let onlyProperty = entity.properties?.first
                XCTAssertNotNil(onlyProperty)
                if let onlyProperty = onlyProperty {
                    XCTAssertEqual(onlyProperty.name, "identifikationsNummer")
                    XCTAssertGreaterThan(onlyProperty.id.id, 0)
                    XCTAssertGreaterThan(onlyProperty.id.uid, 0)
                }
                XCTAssertEqual(entity.relations?.count ?? 0, 0)
            }
        }
    }

    func multiPropertyClassSchema() -> Schema {
        let schemaData = Schema()
        let entity = SchemaEntity()
        entity.className = "FirstEntity"
        let prop = SchemaProperty()
        prop.propertyName = "id"
        prop.propertyType = "EntityId<FirstEntity>"
        prop.entityName = "FirstEntity"
        entity.properties.append(prop)
        let prop2 = SchemaProperty()
        prop2.propertyName = "name"
        prop2.propertyType = "String"
        prop2.entityName = "FirstEntity"
        entity.properties.append(prop2)
        schemaData.entities.append(entity)
        
        let entity2 = SchemaEntity()
        entity2.className = "SecondEntity"
        let prop3 = SchemaProperty()
        prop3.propertyName = "id"
        prop3.propertyType = "EntityId<SecondEntity>"
        prop3.entityName = "SecondEntity"
        entity2.properties.append(prop3)
        let prop4 = SchemaProperty()
        prop4.propertyName = "name"
        prop4.propertyType = "String"
        prop4.entityName = "SecondEntity"
        entity2.properties.append(prop4)
        schemaData.entities.append(entity2)
        
        return schemaData
    }
    
    func testMultiClassMultiPropertyClassFile() throws {
        let schemaData = multiPropertyClassSchema()

        let jsonFile = URL(fileURLWithPath: "/tmp").appendingPathComponent("model.json")
        try? FileManager.default.removeItem(at: jsonFile)
        
        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        try idSync.write()

        XCTAssertEqual(schemaData.entities.count, 2)
        
        let data = try? Data(contentsOf: jsonFile)
        XCTAssertNotNil(data)
        var jsonContents: IdSync.IdSyncModel?
        if let data = data {
            let decoder = JSONDecoder()
            jsonContents = try? decoder.decode(IdSync.IdSyncModel.self, from: data)
        }
        XCTAssertNotNil(jsonContents)
        if let jsonContents = jsonContents {
            XCTAssertEqual(jsonContents.entities?.count ?? 0, 2)

            var entityUid = IdUid()
            var entityProp1Uid = IdUid()
            var entityProp2Uid = IdUid()
            let entity = jsonContents.entities?.first
            XCTAssertNotNil(entity)
            if let entity = entity {
                XCTAssertEqual(entity.name, "FirstEntity")
                entityUid = entity.id
                XCTAssertEqual(entity.id.id, 1)
                XCTAssertGreaterThan(entity.id.uid & ~0xff, 0)
                XCTAssertEqual(entity.properties?.count ?? 0, 2)
                let firstProperty = entity.properties?.first
                XCTAssertNotNil(firstProperty)
                if let firstProperty = firstProperty {
                    XCTAssertEqual(firstProperty.name, "id")
                    XCTAssertEqual(firstProperty.id.id, 1)
                    XCTAssertGreaterThan(firstProperty.id.uid, 0)
                    entityProp1Uid = firstProperty.id
                }
                let secondProperty = entity.properties?[1]
                XCTAssertNotNil(secondProperty)
                if let secondProperty = secondProperty {
                    XCTAssertEqual(secondProperty.name, "name")
                    XCTAssertEqual(secondProperty.id.id, 2)
                    XCTAssertGreaterThan(secondProperty.id.uid, 0)
                    entityProp2Uid = secondProperty.id
                }
                XCTAssertEqual(entity.relations?.count ?? 0, 0)
            }
            
            var entity2Uid = IdUid()
            var entity2Prop1Uid = IdUid()
            var entity2Prop2Uid = IdUid()
            let entity2 = jsonContents.entities?[1]
            XCTAssertNotNil(entity2)
            if let entity2 = entity2 {
                XCTAssertEqual(entity2.name, "SecondEntity")
                entity2Uid = entity2.id
                XCTAssertEqual(entity2.id.id, 2)
                XCTAssertGreaterThan(entity2.id.uid & ~0xff, 0)
                XCTAssertEqual(entity2.properties?.count ?? 0, 2)
                let firstProperty = entity2.properties?.first
                XCTAssertNotNil(firstProperty)
                if let firstProperty = firstProperty {
                    XCTAssertEqual(firstProperty.name, "id")
                    XCTAssertEqual(firstProperty.id.id, 1)
                    XCTAssertGreaterThan(firstProperty.id.uid, 0)
                    entity2Prop1Uid = firstProperty.id
                }
                let secondProperty = entity2.properties?[1]
                XCTAssertNotNil(secondProperty)
                if let secondProperty = secondProperty {
                    XCTAssertEqual(secondProperty.name, "name")
                    XCTAssertEqual(secondProperty.id.id, 2)
                    XCTAssertGreaterThan(secondProperty.id.uid, 0)
                    entity2Prop2Uid = secondProperty.id
                }
                XCTAssertEqual(entity2.relations?.count ?? 0, 0)
            }
            
            // Test synching a second time, are the UIDs still the same?
            let schemaData2 = multiPropertyClassSchema()
            let idSync2 = try IdSync.IdSync(jsonFile: jsonFile)
            try idSync2.sync(schema: schemaData2)
            
            XCTAssertEqual(schemaData2.entities[0].modelUid, entityUid.uid)
            XCTAssertEqual(schemaData2.entities[0].properties[0].modelId?.uid, entityProp1Uid.uid)
            XCTAssertEqual(schemaData2.entities[0].properties[1].modelId?.uid, entityProp2Uid.uid)
            XCTAssertEqual(schemaData2.entities[1].modelUid, entity2Uid.uid)
            XCTAssertEqual(schemaData2.entities[1].properties[0].modelId?.uid, entity2Prop1Uid.uid)
            XCTAssertEqual(schemaData2.entities[1].properties[1].modelId?.uid, entity2Prop2Uid.uid)
        }
    }
    
    func testPropertyIdOverrides() throws {
        let schemaData = multiPropertyClassSchema()
        
        let jsonFile = URL(fileURLWithPath: "/tmp").appendingPathComponent("model.json")
        try? FileManager.default.removeItem(at: jsonFile)
        
        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        try idSync.write()

        // Test synching a second time, are the UIDs still the same?
        var didThrowAsExpected = false
        let overrideId = IdUid(string: "0:1") // Simulate empty "uid" tag.
        let schemaData2 = multiPropertyClassSchema()
        var thrownEntity: String = ""
        var thrownProperty: String = ""
        var thrownFound: Int64 = 0
        var thrownUnique: Int64 = 0
        
        schemaData2.entities[0].properties[1].modelId = overrideId
        do {
            let idSync2 = try IdSync.IdSync(jsonFile: jsonFile)
            try idSync2.sync(schema: schemaData2)
        } catch IdSync.Error.PrintPropertyUid(let entity, let property, let found, let unique) {
            thrownEntity = entity
            thrownProperty = property
            thrownFound = found
            thrownUnique = unique
            didThrowAsExpected = true
        } catch {
            print("error: \(error)")
        }
        XCTAssertTrue(didThrowAsExpected)
        XCTAssertEqual(thrownEntity, "FirstEntity")
        XCTAssertEqual(thrownProperty, "name")
        XCTAssertGreaterThan(thrownFound, 0)
        XCTAssertGreaterThan(thrownUnique, 0)
        XCTAssertNotEqual(thrownFound, thrownUnique)
    }
}
