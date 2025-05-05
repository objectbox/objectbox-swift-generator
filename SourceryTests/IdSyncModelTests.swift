import Foundation
import Quick
import Nimble
@testable import SourceryLib
@testable import SourceryRuntime
import PathKit

class IdSyncSpec: QuickSpec {
    override func spec() {
        describe("IdSync") {
            let tmpPath = URL(fileURLWithPath: "/tmp")
            let jsonFilePath = tmpPath.appendingPathComponent("model.json")
            
            func createTestProperty(_ entity: SchemaEntity, _ name: String, _ type: String) -> SchemaProperty {
                let prop = SchemaProperty()
                // Note: for this test just set the database name based on the field name
                prop.propertyName = name
                prop.name = prop.propertyName
                prop.propertySwiftType = type
                prop.entityName = entity.className
                return prop
            }

            beforeEach {
                try? FileManager.default.removeItem(at: jsonFilePath)
            }
            
            it("handles empty schema") {
                let schemaData = Schema()
                
                expect {
                    let idSync = try IdSync.IdSync(jsonFile: jsonFilePath)
                    try idSync.sync(schema: schemaData)
                    try idSync.write()
                    
                    return schemaData.entities.count
                }.toNot(throwError())
                expect(schemaData.entities.count).to(equal(0))
                
                let data = try? Data(contentsOf: jsonFilePath)
                expect(data).toNot(beNil())
                
                if let data = data {
                    let decoder = JSONDecoder()
                    let jsonContents = try? decoder.decode(IdSync.IdSyncModel.self, from: data)
                    expect(jsonContents).toNot(beNil())
                    expect(jsonContents?.entities?.count ?? 0).to(equal(0))
                }
            }
            
            it("handles one empty class") {
                let schemaData = Schema()
                let entity = SchemaEntity()
                entity.className = "FirstEntity"
                schemaData.entities.append(entity)
                
                expect {
                    let idSync = try IdSync.IdSync(jsonFile: jsonFilePath)
                    try idSync.sync(schema: schemaData)
                    try idSync.write()
                    
                    return schemaData.entities.count
                }.toNot(throwError())
                expect(schemaData.entities.count).to(equal(1))
                
                let data = try? Data(contentsOf: jsonFilePath)
                expect(data).toNot(beNil())
                
                if let data = data {
                    let decoder = JSONDecoder()
                    let jsonContents = try? decoder.decode(IdSync.IdSyncModel.self, from: data)
                    expect(jsonContents).toNot(beNil())
                    
                    let entity = jsonContents?.entities?.first
                    expect(entity).toNot(beNil())
                    expect(entity?.name).to(equal("FirstEntity"))
                    expect(entity!.id.id).to(beGreaterThanOrEqualTo(0))
                    expect(entity!.id.uid & ~0xff).to(beGreaterThanOrEqualTo(0))
                    expect(entity?.properties?.count ?? 0).to(equal(0))
                    expect(entity?.relations?.count ?? 0).to(equal(0))
                }
            }
            
            it("handles one minimal class with a property") {
                let schemaData = Schema()
                let entity = SchemaEntity()
                entity.className = "FirstEntity"
                entity.properties.append(createTestProperty(entity, "identifikationsNummer", "EntityId<FirstEntity>"))
                schemaData.entities.append(entity)
                
                expect {
                    let idSync = try IdSync.IdSync(jsonFile: jsonFilePath)
                    try idSync.sync(schema: schemaData)
                    try idSync.write()
                    
                    return schemaData.entities.count
                }.toNot(throwError())
                expect(schemaData.entities.count).to(equal(1))
                
                let data = try? Data(contentsOf: jsonFilePath)
                expect(data).toNot(beNil())
                
                if let data = data {
                    let decoder = JSONDecoder()
                    let jsonContents = try? decoder.decode(IdSync.IdSyncModel.self, from: data)
                    expect(jsonContents).toNot(beNil())
                    
                    let entity = jsonContents?.entities?.first
                    expect(entity).toNot(beNil())
                    expect(entity?.name).to(equal("FirstEntity"))
                    expect(entity!.id.id).to(beGreaterThan(0))
                    expect(entity!.id.uid & ~0xff).to(beGreaterThan(0))
                    
                    expect(entity?.properties?.count ?? 0).to(equal(1))
                    let onlyProperty = entity?.properties?.first
                    expect(onlyProperty).toNot(beNil())
                    expect(onlyProperty?.name).to(equal("identifikationsNummer"))
                    expect(onlyProperty?.id.id).to(beGreaterThan(0))
                    expect(onlyProperty?.id.uid).to(beGreaterThan(0))
                    
                    expect(entity?.relations?.count ?? 0).to(equal(0))
                }
            }
            
            context("with multiple classes and properties") {

                func multiPropertyClassSchema() -> Schema {
                    let schemaData = Schema()
                    
                    let entity = SchemaEntity()
                    entity.className = "FirstEntity"
                    entity.properties.append(createTestProperty(entity, "id", "EntityId<FirstEntity>"))
                    entity.properties.append(createTestProperty(entity, "name", "String"))
                    schemaData.entities.append(entity)
                    
                    let entity2 = SchemaEntity()
                    entity2.className = "SecondEntity"
                    entity2.properties.append(createTestProperty(entity2, "id", "EntityId<SecondEntity>"))
                    entity2.properties.append(createTestProperty(entity2, "name", "String"))
                    schemaData.entities.append(entity2)
                    
                    return schemaData
                }
                
                it("properly syncs multiple classes with multiple properties") {
                    let schemaData = multiPropertyClassSchema()
                    
                    expect {
                        let idSync = try IdSync.IdSync(jsonFile: jsonFilePath)
                        try idSync.sync(schema: schemaData)
                        try idSync.write()
                        
                        return schemaData.entities.count
                    }.toNot(throwError())
                    expect(schemaData.entities.count).to(equal(2))
                    
                    let data = try? Data(contentsOf: jsonFilePath)
                    expect(data).toNot(beNil())
                    
                    var entityUid = IdUid()
                    var entityProp1Uid = IdUid()
                    var entityProp2Uid = IdUid()
                    var entity2Uid = IdUid()
                    var entity2Prop1Uid = IdUid()
                    var entity2Prop2Uid = IdUid()
                    
                    if let data = data {
                        let decoder = JSONDecoder()
                        let jsonContents = try? decoder.decode(IdSync.IdSyncModel.self, from: data)
                        expect(jsonContents).toNot(beNil())
                        expect(jsonContents?.entities?.count ?? 0).to(equal(2))
                        
                        let entity = jsonContents?.entities?.first
                        expect(entity).toNot(beNil())
                        expect(entity?.name).to(equal("FirstEntity"))
                        entityUid = entity!.id
                        expect(entity!.id.id).to(equal(1))
                        expect(entity!.id.uid & ~0xff).to(beGreaterThan(0))
                        
                        expect(entity?.properties?.count ?? 0).to(equal(2))
                        let firstProperty = entity?.properties?.first
                        expect(firstProperty).toNot(beNil())
                        expect(firstProperty?.name).to(equal("id"))
                        expect(firstProperty?.id.id).to(equal(1))
                        expect(firstProperty?.id.uid).to(beGreaterThan(0))
                        entityProp1Uid = firstProperty!.id
                        
                        let secondProperty = entity?.properties?[1]
                        expect(secondProperty).toNot(beNil())
                        expect(secondProperty?.name).to(equal("name"))
                        expect(secondProperty?.id.id).to(equal(2))
                        expect(secondProperty?.id.uid).to(beGreaterThan(0))
                        entityProp2Uid = secondProperty!.id
                        
                        expect(entity?.relations?.count ?? 0).to(equal(0))
                        
                        let entity2 = jsonContents?.entities?[1]
                        expect(entity2).toNot(beNil())
                        expect(entity2?.name).to(equal("SecondEntity"))
                        entity2Uid = entity2!.id
                        expect(entity2!.id.id).to(equal(2))
                        expect(entity2!.id.uid & ~0xff).to(beGreaterThan(0))
                        
                        expect(entity2?.properties?.count ?? 0).to(equal(2))
                        let firstProperty2 = entity2?.properties?.first
                        expect(firstProperty2).toNot(beNil())
                        expect(firstProperty2?.name).to(equal("id"))
                        expect(firstProperty2?.id.id).to(equal(1))
                        expect(firstProperty2?.id.uid).to(beGreaterThan(0))
                        entity2Prop1Uid = firstProperty2!.id
                        
                        let secondProperty2 = entity2?.properties?[1]
                        expect(secondProperty2).toNot(beNil())
                        expect(secondProperty2?.name).to(equal("name"))
                        expect(secondProperty2?.id.id).to(equal(2))
                        expect(secondProperty2?.id.uid).to(beGreaterThan(0))
                        entity2Prop2Uid = secondProperty2!.id
                        
                        expect(entity2?.relations?.count ?? 0).to(equal(0))
                    }
                    
                    // Test synching a second time, are the UIDs still the same?
                    let schemaData2 = multiPropertyClassSchema()
                    expect {
                        let idSync2 = try IdSync.IdSync(jsonFile: jsonFilePath)
                        try idSync2.sync(schema: schemaData2)
                        return true
                    }.toNot(throwError())
                    
                    expect(schemaData2.entities[0].modelUid).to(equal(entityUid.uid))
                    expect(schemaData2.entities[0].properties[0].modelId?.uid).to(equal(entityProp1Uid.uid))
                    expect(schemaData2.entities[0].properties[1].modelId?.uid).to(equal(entityProp2Uid.uid))
                    expect(schemaData2.entities[1].modelUid).to(equal(entity2Uid.uid))
                    expect(schemaData2.entities[1].properties[0].modelId?.uid).to(equal(entity2Prop1Uid.uid))
                    expect(schemaData2.entities[1].properties[1].modelId?.uid).to(equal(entity2Prop2Uid.uid))
                }
                
                it("throws an error when property ID overrides occur") {
                    let schemaData = multiPropertyClassSchema()
                    
                    expect {
                        let idSync = try IdSync.IdSync(jsonFile: jsonFilePath)
                        try idSync.sync(schema: schemaData)
                        try idSync.write()
                        return true
                    }.toNot(throwError())
                    
                    // Override ID and check for expected error
                    let overrideId = IdUid(string: "0:1") // Simulate empty "uid" tag
                    let schemaData2 = multiPropertyClassSchema()
                    schemaData2.entities[0].properties[1].modelId = overrideId
                    
                    var thrownError: Error?
                    do {
                        let idSync2 = try IdSync.IdSync(jsonFile: jsonFilePath)
                        try idSync2.sync(schema: schemaData2)
                    } catch {
                        thrownError = error
                    }
                    
                    expect(thrownError).toNot(beNil())
                    
                    if case let IdSync.Error.PrintPropertyUid(entity, property, found, unique)? = thrownError {
                        expect(entity).to(equal("FirstEntity"))
                        expect(property).to(equal("name"))
                        expect(found).to(beGreaterThan(0))
                        expect(unique).to(beGreaterThan(0))
                        expect(found).toNot(equal(unique))
                    } else {
                        fail("Expected IdSync.Error.PrintPropertyUid but got \(String(describing: thrownError))")
                    }
                }
            }
        }
    }
}
