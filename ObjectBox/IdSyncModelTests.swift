//
//  IdSyncModelTests.swift
//  SourceryTests
//
//  Created by Uli Kusterer on 07.12.18.
//

import Foundation
import XCTest
import Quick
import Nimble
@testable import Sourcery
@testable import SourceryRuntime
import PathKit


class IdSyncTests: XCTestCase {
    func testEmptyFile() throws {
        let schemaData = IdSync.Schema()
        
        let jsonFile = URL(fileURLWithPath: "/tmp").appendingPathComponent("model.json")
        try? FileManager.default.removeItem(at: jsonFile)

        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        
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
        let schemaData = IdSync.Schema()
        let entity = IdSync.SchemaEntity()
        entity.className = "FirstEntity"
        schemaData.entities.append(entity)
        
        let jsonFile = URL(fileURLWithPath: "/tmp").appendingPathComponent("model.json")
        try? FileManager.default.removeItem(at: jsonFile)
        
        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        
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
        let schemaData = IdSync.Schema()
        let entity = IdSync.SchemaEntity()
        entity.className = "FirstEntity"
        let prop = IdSync.SchemaProperty()
        prop.propertyName = "identifikationsNummer"
        prop.propertyType = "Id<FirstEntity>"
        prop.entityName = "FirstEntity"
        entity.properties.append(prop)
        schemaData.entities.append(entity)
        
        let jsonFile = URL(fileURLWithPath: "/tmp").appendingPathComponent("model.json")
        try? FileManager.default.removeItem(at: jsonFile)
        
        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        
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

    
    func testMultiClassMultiPropertyClassFile() throws {
        let schemaData = IdSync.Schema()
        let entity = IdSync.SchemaEntity()
        entity.className = "FirstEntity"
        let prop = IdSync.SchemaProperty()
        prop.propertyName = "id"
        prop.propertyType = "Id<FirstEntity>"
        prop.entityName = "FirstEntity"
        entity.properties.append(prop)
        let prop2 = IdSync.SchemaProperty()
        prop2.propertyName = "name"
        prop2.propertyType = "String"
        prop2.entityName = "FirstEntity"
        entity.properties.append(prop2)
        schemaData.entities.append(entity)
        
        let entity2 = IdSync.SchemaEntity()
        entity2.className = "SecondEntity"
        let prop3 = IdSync.SchemaProperty()
        prop3.propertyName = "id"
        prop3.propertyType = "Id<SecondEntity>"
        prop3.entityName = "SecondEntity"
        entity2.properties.append(prop3)
        let prop4 = IdSync.SchemaProperty()
        prop4.propertyName = "name"
        prop4.propertyType = "String"
        prop4.entityName = "SecondEntity"
        entity2.properties.append(prop4)
        schemaData.entities.append(entity2)

        let jsonFile = URL(fileURLWithPath: "/tmp").appendingPathComponent("model.json")
        try? FileManager.default.removeItem(at: jsonFile)
        
        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        
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
            let entity = jsonContents.entities?.first
            XCTAssertNotNil(entity)
            if let entity = entity {
                XCTAssertEqual(entity.name, "FirstEntity")
                XCTAssertEqual(entity.id.id, 1)
                XCTAssertGreaterThan(entity.id.uid & ~0xff, 0)
                XCTAssertEqual(entity.properties?.count ?? 0, 2)
                let firstProperty = entity.properties?.first
                XCTAssertNotNil(firstProperty)
                if let firstProperty = firstProperty {
                    XCTAssertEqual(firstProperty.name, "id")
                    XCTAssertEqual(firstProperty.id.id, 1)
                    XCTAssertGreaterThan(firstProperty.id.uid, 0)
                }
                let secondProperty = entity.properties?[1]
                XCTAssertNotNil(secondProperty)
                if let secondProperty = secondProperty {
                    XCTAssertEqual(secondProperty.name, "name")
                    XCTAssertEqual(secondProperty.id.id, 2)
                    XCTAssertGreaterThan(secondProperty.id.uid, 0)
                }
                XCTAssertEqual(entity.relations?.count ?? 0, 0)
            }
            
            let entity2 = jsonContents.entities?[1]
            XCTAssertNotNil(entity2)
            if let entity2 = entity2 {
                XCTAssertEqual(entity2.name, "SecondEntity")
                XCTAssertEqual(entity2.id.id, 2)
                XCTAssertGreaterThan(entity2.id.uid & ~0xff, 0)
                XCTAssertEqual(entity2.properties?.count ?? 0, 2)
                let firstProperty = entity2.properties?.first
                XCTAssertNotNil(firstProperty)
                if let firstProperty = firstProperty {
                    XCTAssertEqual(firstProperty.name, "id")
                    XCTAssertEqual(firstProperty.id.id, 1)
                    XCTAssertGreaterThan(firstProperty.id.uid, 0)
                }
                let secondProperty = entity2.properties?[1]
                XCTAssertNotNil(secondProperty)
                if let secondProperty = secondProperty {
                    XCTAssertEqual(secondProperty.name, "name")
                    XCTAssertEqual(secondProperty.id.id, 2)
                    XCTAssertGreaterThan(secondProperty.id.uid, 0)
                }
                XCTAssertEqual(entity2.relations?.count ?? 0, 0)
            }
        }
    }
}


//class ObjectBoxSpec: QuickSpec {
//    override func spec() {
//        func update(code: String, in path: Path) { guard (try? path.write(code)) != nil else { fatalError() } }
//
//        describe ("ObjectBox Generator") {
//            var outputDir = Path("/tmp")
//            var output: Output { return Output(outputDir) }
//
//            beforeEach {
//                outputDir = Stubs.cleanTemporarySourceryDir()
//            }
//
//            context("with already generated files") {
//                let templatePath = Stubs.templateDirectory + Path("Other.stencil")
//                let sourcePath = outputDir + Path("Source.swift")
//                var generatedFileModificationDate: Date!
//                var newGeneratedFileModificationDate: Date!
//
//                func fileModificationDate(url: URL) -> Date? {
//                    guard let attr = try? FileManager.default.attributesOfItem(atPath: url.path) else {
//                        return nil
//                    }
//                    return attr[FileAttributeKey.modificationDate] as? Date
//                }
//
//                beforeEach {
//                }
//
//                context("with a one-entity file") {
//                    it("produces one entity ID") {
//                        update(code: """
//                        class Foo: Entity {
//                        }
//                        """, in: sourcePath)
//
//                        let generatedFilePath = outputDir + Sourcery().generatedPath(for: templatePath)
//                        generatedFileModificationDate = fileModificationDate(url: generatedFilePath.url)
//                        DispatchQueue.main.asyncAfter ( deadline: DispatchTime.now() + Double(Int64(0.5 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
//                            _ = try? Sourcery(watcherEnabled: false, cacheDisabled: true).processFiles(.sources(Paths(include: [sourcePath])), usingTemplates: Paths(include: [templatePath]), output: output)
//                            newGeneratedFileModificationDate = fileModificationDate(url: generatedFilePath.url)
//                        }
//                        expect(newGeneratedFileModificationDate).toEventually(beGreaterThan(generatedFileModificationDate))
//                    }
//                }
//            }
//        }
//    }
//}
