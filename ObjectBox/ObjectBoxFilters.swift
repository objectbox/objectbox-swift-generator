//
//  ObjectBoxFilters.swift
//  Sourcery
//
//  Created by Uli Kusterer on 29.11.18.
//  Copyright © 2018 ObjectBox. All rights reserved.
//

import Foundation
import PathKit
import Stencil
import StencilSwiftKit
import StencilSwiftKit.Swift
import SourceryRuntime


/* Model classes that get populated from our model.json file using Codable protocol. */
typealias IdUid = String

extension IdUid {
    init() {
        self = "0:0"
    }
    
    var uid: Int64 {
        get {
            if let uidStr = self.components(separatedBy: ":").last, let uid = Int64(uidStr) {
                return uid
            } else {
                return 0
            }
        }
        
        set(new) {
            let uidStr = String(new)
            let firstValue = Int(self.components(separatedBy: ":").first ?? "0") ?? 0
            self = "\(firstValue):\(uidStr)"
        }
    }
    
    var id: Int32 {
        get {
            if let idStr = self.components(separatedBy: ":").first, let id = Int32(idStr) {
                return id
            } else {
                return 0
            }
        }
        
        set(new) {
            let idStr = String(new)
            let secondValue = Int(self.components(separatedBy: ":").last ?? "0") ?? 0
            self = "\(idStr):\(secondValue)"
        }
    }
    
    mutating func incId(uid: Int64) -> IdUid {
        self.id = self.id + 1
        self.uid = uid
        return self
    }
}


enum ObjectBoxFilters {
        
    /* The following two functions and this error type are copied from SourcerySwiftKit because that doesn't
        export them. */
    enum Error: Swift.Error {
        case invalidInputType
        case invalidOption(option: String)
    }

    /// Parses filter input value for a string value, where accepted objects must conform to
    /// `CustomStringConvertible`
    ///
    /// - Parameters:
    ///   - value: an input value, may be nil
    /// - Throws: Filters.Error.invalidInputType
    static func parseString(from value: Any?) throws -> String {
        if let losslessString = value as? LosslessStringConvertible {
            return String(describing: losslessString)
        }
        if let string = value as? String {
            return string
        }
        #if os(Linux)
        if let string = value as? NSString {
            return String(describing: string)
        }
        #endif
        
        throw Error.invalidInputType
    }
    
    /// Parses filter arguments for a string value, where accepted objects must conform to
    /// `CustomStringConvertible`
    ///
    /// - Parameters:
    ///   - arguments: an array of argument values, may be empty
    ///   - index: the index in the arguments array
    /// - Throws: Filters.Error.invalidInputType
    static func parseStringArgument(from arguments: [Any?], at index: Int = 0) throws -> String {
        guard index < arguments.count else {
            throw Error.invalidInputType
        }
        if let losslessString = arguments[index] as? LosslessStringConvertible {
            return String(describing: losslessString)
        }
        if let string = arguments[index] as? String {
            return string
        }
        throw Error.invalidInputType
    }

    static var modelJsonFile: URL?
    private static var entities = Array<IdSync.SchemaEntity>()
    
    static func printError(_ error: Swift.Error) {
        guard let obxError = error as? IdSync.Error else {
            print("Error: \(error)")
            return
        }
        switch(obxError) {
        case .IncompatibleVersion(let found, let expected):
            print("Error: Model version \(expected) expected, but \(found) found.")
        case .DuplicateEntityName(let name):
            print("Error: More than one entity with name \(name) found.")
        case .DuplicateEntityID(let name, let id):
            print("Error: More than one entity with ID \(id) found (\"\(name)\").")
        case .MissingLastEntityID:
            print("Error: No lastEntityId entry in model JSON file.")
        case .LastEntityIdUIDMismatch(let name, let id, let found, let expected):
            print("Error: lastEntityId UID \(found) in model JSON does not actually match the highest entity ID found, \(expected). (\(name)/\(id))")
        case .EntityIdGreaterThanLast(let name, let found, let last):
            print("Error: Entity \(name) has an ID of \(found), which is higher than the model JSON's entry for the lastEntityId, \(last)")
        case .MissingLastPropertyID(let name):
            print("Error: Entity \(name) has no lastPropertyId entry in the model JSON.")
        case .DuplicatePropertyID(let entity, let name, let id):
            print("Error: The ID \(id) of property \(name) in entity \(entity) is already in use for another property.")
        case .LastPropertyIdUIDMismatch(let entity, let name, let id, let found, let expected):
            print("Error: The ID \(id) of last property \(name) in entity \(entity) should have UID \(expected), but actually has \(found).")
        case .PropertyIdGreaterThanLast(let entity, let name, let found, let last):
            print("Error: Property \(name) of entity \(entity) has an ID of \(found), which is higher than the model JSON's entry for that class's lastPropertyId, \(last)")
        case .DuplicateUID(let uid):
            print("Error: UID \(uid) exists twice in this model. Possibly as a code annotation and in the model JSON on different classes.")
        case .UIDOutOfRange(let uid):
            print("Error: UID \(uid) is not within the valid range for UIDs (>= 0).")
        case .OutOfUIDs:
            print("Internal Error: Could not generate a unique UID in reasonable time.")
        case .SyncMayOnlyBeCalledOnce:
            print("Internal Error: sync() may only be called once.")
        case .NonUniqueModelUID(let uid, let entity):
            print("Error: UID \(uid) that entity \(entity) has is already in use for another entity.")
        case .NoSuchEntity(let entity):
            print("Error: No entity with UID \(entity) exists.")
        case .PrintUid(let entity, let found, let unique):
            print("error: No UID given for entity \(entity). You can do the following:\n",
                "error:\t[Rename] Apply the current UID using // objectbox: entityId \(found)\n",
                "error:\t[Change/Reset] Apply a new UID using // objectbox: entityId \(unique)")
        case .UIDTagNeedsValue(let entity):
            print("Error: No UID given for entity \(entity).")
        case .CandidateUIDNotInPool(let uid):
            print("Internal Error: Candidate UID \(uid) was not in new UID pool.")
        case .NonUniqueModelPropertyUID(let uid, let entity, let property):
            print("Error: UID \(uid) of property \(property) of entity \(entity) is already in use.")
        case .NoSuchProperty(let entity, let uid):
            print("Error: No property with UID \(uid) in entity \(entity).")
        case .MultiplePropertiesForUID(let uids, let names):
            print("Error: Multiple matches between UIDs: \(uids.map { String($0) }.joined(separator: ", ")) and properties: \(names.joined(separator: ", ")).")
        case .PrintPropertyUid(let entity, let property, let found, let unique):
            print("error: No UID given for property \(property) of entity \(entity). You can do the following:\n",
                "error:\t[Rename] Apply the current UID using // objectbox: uid \(found)\n",
                "error:\t[Change/Reset] Apply a new UID using // objectbox: uid \(unique)")
        case .PropertyUIDTagNeedsValue(let entity, let property):
            print("Error: Property \(property) of entity \(entity) has an \"// objectbox: uid n\" annotation missing the number n.")
        case .PropertyCollision(let entity, let new, let old):
            print("Error: Properties \(new) and \(old) of entity \(entity) both map to the same property of the same class.")
        case .NonUniqueModelRelationUID(let uid, let entity, let relation):
            print("Error: UID \(uid) of relation \(relation) of entity \(entity) is already being used by another relation.")
        case .NoSuchRelation(let entity, let uid):
            print("Error: No relation with UID \(uid) in entity \(entity).")
        case .MultipleRelationsForUID(let uids, let names):
            print("Error: Multiple matches between UIDs: \(uids.map { String($0) }.joined(separator: ", ")) and relations: \(names.joined(separator: ", ")).")
        case .PrintRelationUid(let entity, let relation, let found, let unique):
            print("error: No UID given for relation \(relation) of entity \(entity). You can do the following:\n",
                "error:\t[Rename] Apply the current UID using // objectbox: uid \(found)\n",
                "error:\t[Change/Reset] Apply a new UID using // objectbox: uid \(unique)")
        case .RelationUIDTagNeedsValue(let entity, let relation):
            print("Error: Relation \(relation) of entity \(entity) has an \"// objectbox: uid n\" annotation missing the number n.")
        case .DuplicatePropertyName(let entity, let property):
            print("Error: Property \(property) of entity \(entity) exists twice.")
        }
    }
    
    /* Process the parsed syntax tree, possibly annotating or otherwise
        extending it. */
    static func process(parsingResult result: inout Sourcery.ParsingResult) throws {
        do {
            let schemaData = IdSync.Schema()
            
            result.types.all.forEach { currType in
                let isEntityBased = currType.inheritedTypes.contains("Entity")
                if isEntityBased || currType.annotations["Entity"] != nil {
                    let schemaEntity = IdSync.SchemaEntity()
                    schemaEntity.className = currType.localName
                    schemaEntity.modelUid = currType.annotations["objectId"] as? Int64
                    schemaEntity.dbName = currType.annotations["nameInDb"] as? String
                    schemaEntity.isEntitySubclass = isEntityBased
                    
                    var schemaProperties = Array<IdSync.SchemaProperty>()
                    currType.variables.forEach { currIVar in
                        guard !currIVar.annotations.contains(reference: "transient") else { return } // Exits only the foreach block
                        
                        let schemaProperty = IdSync.SchemaProperty()
                        schemaProperty.propertyName = currIVar.name
                        schemaProperty.dbName = currIVar.annotations["nameInDb"] as? String
                        if let propertyUid = currIVar.annotations["uid"] as? Int64 {
                            var propId = IdUid()
                            propId.uid = propertyUid
                            schemaProperty.modelId = propId
                        }
                        if let propertyIndexUid = currIVar.annotations["index"] as? Int64 {
                            var indexId = IdUid()
                            indexId.uid = propertyIndexUid
                            schemaProperty.modelIndexId = indexId
                        }
                        schemaProperties.append(schemaProperty)
                    }
                    schemaEntity.properties = schemaProperties
                    schemaData.entities.append(schemaEntity)
                }
            }
            
            let jsonFile = ObjectBoxFilters.modelJsonFile ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("model.json")
            let idSync = try IdSync.IdSync(jsonFile: jsonFile)
            try idSync.sync(schema: schemaData)
            
            ObjectBoxFilters.entities = schemaData.entities
            
        } catch {
            printError(error)
        }
    }
    
    /* Modify the dictionary of global objects that Stencil sees. */
    static func exposeObjects(to objectsDictionary: inout [String:Any]) {
        objectsDictionary["entities"] = ObjectBoxFilters.entities
    }
    
    /* Add any filters we define (think function call that receives input data): */
    static func addExtensions(_ ext: Stencil.Extension) {
        ext.registerFilter("idForProperty", filter: ObjectBoxFilters.idForProperty)
    }
    
    /* Implement a filter registered in addExtensions() above. */
    static func idForProperty(_ value: Any?, arguments: [Any?]) throws -> Any? {
        let entityName = try parseString(from: value)
        let propertyName = try parseStringArgument(from: arguments, at: 0)
        
        var idsDict: Dictionary<String,UInt32> = [:]
        do {
            let jsonData = try Data(contentsOf: URL(fileURLWithPath: "/Users/uli/Downloads/SourceryTest/model.json"));
            idsDict = try JSONSerialization.jsonObject(with: jsonData) as? Dictionary<String,UInt32> ?? [:]
        } catch {
            print("error unpacking Json: \(error)")
        }
        if let currentID = idsDict["\(entityName).\(propertyName)"] {
            return currentID
        } else {
            let newID: UInt32
            if let lastUsedID = idsDict["\(entityName).$lastUsedId"] {
                newID = lastUsedID + 1
            } else {
                newID = 2
            }
            idsDict["\(entityName).$lastUsedId"] = newID
            idsDict["\(entityName).\(propertyName)"] = newID
            let jsonData = try! JSONSerialization.data(withJSONObject: idsDict)
            try! jsonData.write(to: URL(fileURLWithPath: "/Users/uli/Downloads/SourceryTest/model.json"))
            return newID
        }
    }
    
}
