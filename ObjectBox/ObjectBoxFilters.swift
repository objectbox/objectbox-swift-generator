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
struct IdUid: Codable {
    var id: Int32 = 0
    var uid: Int64 = 0
    
    init() {}
    
    init(string: String) {
        let parts = string.components(separatedBy: ":")
        id = Int32(parts[0]) ?? 0
        uid = Int64(parts[1]) ?? 0
    }
    
    init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        self.init(string: string)
    }
    
    func toString() -> String {
        return "\(id):\(uid)"
    }
    
    mutating func incId(uid: Int64) -> IdUid {
        self.id = self.id + 1
        self.uid = uid
        return self
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toString())
    }
}


enum ObjectBoxFilters {
        
    enum Error: Swift.Error {
        case DuplicateIdAnnotation(entity: String, found: String, existing: String)
        case MissingIdOnEntity(entity: String)
        case AmbiguousIdOnEntity(entity: String, properties: [String])
        case MissingBacklinkOnToManyRelation(entity: String, relation: String)
    }

    static var modelJsonFile: URL?
    static var builtInTypes = ["Bool", "Int8", "Int16", "Int32", "Int64", "Int", "Float", "Double", "Date", "NSDate", "TimeInterval", "NSTimeInterval"]
    private static var entities = Array<IdSync.SchemaEntity>()
    
    static func printError(_ error: Swift.Error) {
        if let obxError = error as? IdSync.Error {
            switch(obxError) {
            case .IncompatibleVersion(let found, let expected):
                Log.error("Model version \(expected) expected, but \(found) found.")
            case .DuplicateEntityName(let name):
                Log.error("More than one entity with name \(name) found.")
            case .DuplicateEntityID(let name, let id):
                Log.error("More than one entity with ID \(id) found (\"\(name)\").")
            case .MissingLastEntityID:
                Log.error("No lastEntityId entry in model JSON file.")
            case .LastEntityIdUIDMismatch(let name, let id, let found, let expected):
                Log.error("lastEntityId UID \(found) in model JSON does not actually match the highest entity ID found, \(expected). (\(name)/\(id))")
            case .EntityIdGreaterThanLast(let name, let found, let last):
                Log.error("Entity \(name) has an ID of \(found), which is higher than the model JSON's entry for the lastEntityId, \(last)")
            case .MissingLastPropertyID(let name):
                Log.error("Entity \(name) has no lastPropertyId entry in the model JSON.")
            case .DuplicatePropertyID(let entity, let name, let id):
                Log.error("The ID \(id) of property \(name) in entity \(entity) is already in use for another property.")
            case .LastPropertyIdUIDMismatch(let entity, let name, let id, let found, let expected):
                Log.error("The ID \(id) of last property \(name) in entity \(entity) should have UID \(expected), but actually has \(found).")
            case .PropertyIdGreaterThanLast(let entity, let name, let found, let last):
                Log.error("Property \(name) of entity \(entity) has an ID of \(found), which is higher than the model JSON's entry for that class's lastPropertyId, \(last)")
            case .DuplicateUID(let uid):
                Log.error("UID \(uid) exists twice in this model. Possibly as a code annotation and in the model JSON on different classes.")
            case .UIDOutOfRange(let uid):
                Log.error("UID \(uid) is not within the valid range for UIDs (>= 0).")
            case .OutOfUIDs:
                Log.error("Could not generate a unique UID in reasonable time.")
            case .SyncMayOnlyBeCalledOnce:
                Log.error("sync() may only be called once.")
            case .NonUniqueModelUID(let uid, let entity):
                Log.error("UID \(uid) that entity \(entity) has is already in use for another entity.")
            case .NoSuchEntity(let entity):
                Log.error("No entity with UID \(entity) exists.")
            case .PrintUid(let entity, let found, let unique):
                Log.error("No UID given for entity \(entity). You can do the following:\n" +
                    "\t[Rename] Apply the current UID using // objectbox: entityId \(found)\n" +
                    "\t[Change/Reset] Apply a new UID using // objectbox: entityId \(unique)")
            case .UIDTagNeedsValue(let entity):
                Log.error("No UID given for entity \(entity).")
            case .CandidateUIDNotInPool(let uid):
                Log.error("Candidate UID \(uid) was not in new UID pool.")
            case .NonUniqueModelPropertyUID(let uid, let entity, let property):
                Log.error("UID \(uid) of property \(property) of entity \(entity) is already in use.")
            case .NoSuchProperty(let entity, let uid):
                Log.error("No property with UID \(uid) in entity \(entity).")
            case .MultiplePropertiesForUID(let uids, let names):
                Log.error("Multiple matches between UIDs: \(uids.map { String($0) }.joined(separator: ", ")) and properties: \(names.joined(separator: ", ")).")
            case .PrintPropertyUid(let entity, let property, let found, let unique):
                Log.error("No UID given for property \(property) of entity \(entity). You can do the following:\n" +
                    "\t[Rename] Apply the current UID using // objectbox: uid \(found)\n" +
                    "\t[Change/Reset] Apply a new UID using // objectbox: uid \(unique)")
            case .PropertyUIDTagNeedsValue(let entity, let property):
                Log.error("Property \(property) of entity \(entity) has an \"// objectbox: uid n\" annotation missing the number n.")
            case .PropertyCollision(let entity, let new, let old):
                Log.error("Properties \(new) and \(old) of entity \(entity) both map to the same property of the same class.")
            case .NonUniqueModelRelationUID(let uid, let entity, let relation):
                Log.error("UID \(uid) of relation \(relation) of entity \(entity) is already being used by another relation.")
            case .NoSuchRelation(let entity, let uid):
                Log.error("No relation with UID \(uid) in entity \(entity).")
            case .MultipleRelationsForUID(let uids, let names):
                Log.error("Multiple matches between UIDs: \(uids.map { String($0) }.joined(separator: ", ")) and relations: \(names.joined(separator: ", ")).")
            case .PrintRelationUid(let entity, let relation, let found, let unique):
                Log.error("No UID given for relation \(relation) of entity \(entity). You can do the following:\n" +
                    "\t[Rename] Apply the current UID using // objectbox: uid \(found)\n" +
                    "\t[Change/Reset] Apply a new UID using // objectbox: uid \(unique)")
            case .RelationUIDTagNeedsValue(let entity, let relation):
                Log.error("Relation \(relation) of entity \(entity) has an \"// objectbox: uid n\" annotation missing the number n.")
            case .DuplicatePropertyName(let entity, let property):
                Log.error("Property \(property) of entity \(entity) exists twice.")
            }
        } else if let filterError = error as? ObjectBoxFilters.Error {
            switch( filterError ) {
            case .DuplicateIdAnnotation(let entity, let found, let existing):
                Log.error("Entity \(entity) has both \(found) and \(existing) annotated as 'objectId'. There can only be one.")
            case .MissingIdOnEntity(let entity):
                Log.error("Entity \(entity) needs an ID property of type Id<\(entity)>.")
            case .AmbiguousIdOnEntity(let entity, let properties):
                Log.error("Entity \(entity) has several properties of type Id<\(entity)>, but no entity ID. Please designate one as this entity's ID using an '// objectbox: objectId' annotation. Candidates are: \(properties.joined(separator: ", "))")
            case .MissingBacklinkOnToManyRelation(let entity, let relation):
                Log.error("Missing backlink on to-many relation \(relation) of entity \(entity)")
            }
        } else {
            Log.error("\(error)")
            return
        }
    }
    
    static func isBuiltInTypeOrAlias( _ typeName: TypeName? ) -> Bool {
        var isBuiltIn: Bool = false
        var currPropType = typeName
        
        while let currPropTypeReadOnly = currPropType, !isBuiltIn {
            isBuiltIn = builtInTypes.firstIndex(of: currPropTypeReadOnly.name) != nil
            currPropType = currPropTypeReadOnly.actualTypeName
        }
        
        return isBuiltIn
    }
    
    /* Is this a string ivar that we need to save separately from the fixed-size types? */
    static func isStringTypeOrAlias( _ typeName: TypeName? ) -> Bool {
        var isStringType: Bool = false
        var currPropType = typeName
        
        while let currPropTypeReadOnly = currPropType, !isStringType {
            isStringType = currPropTypeReadOnly.name == "String"
            currPropType = currPropTypeReadOnly.actualTypeName
        }
        
        return isStringType
    }
    
    /* Process the parsed syntax tree, possibly annotating or otherwise
        extending it. */
    static func process(parsingResult result: inout Sourcery.ParsingResult) throws {
        let schemaData = IdSync.Schema()
        
        try result.types.all.forEach { currType in
            let isEntityBased = currType.inheritedTypes.contains("Entity")
            if isEntityBased || currType.annotations["Entity"] != nil {
                let schemaEntity = IdSync.SchemaEntity()
                schemaEntity.className = currType.localName
                schemaEntity.isValueType = currType.kind == "struct"
                schemaEntity.modelUid = currType.annotations["objectId"] as? Int64
                schemaEntity.dbName = currType.annotations["nameInDb"] as? String
                schemaEntity.isEntitySubclass = isEntityBased
                
                var schemaProperties = Array<IdSync.SchemaProperty>()
                try currType.variables.forEach { currIVar in
                    guard !currIVar.annotations.contains(reference: "transient") else { return } // Exits only the foreach block
                    
                    let fullTypeName = currIVar.typeName.name;
                    if fullTypeName.hasPrefix("ToOne<") {
                        if fullTypeName.hasSuffix(">") {
                            let templateTypesString = fullTypeName.drop(first: "ToOne<".count, last: 1)
                            let templateTypes = templateTypesString.split(separator: ",")
                            let destinationType = templateTypes[0]
                            
                            let relation = IdSync.SchemaToOneRelation(name: currIVar.name, type: fullTypeName, targetType: String(destinationType))
                            if let propertyUid = currIVar.annotations["uid"] as? Int64 {
                                var propId = IdUid()
                                propId.uid = propertyUid
                                relation.modelId = propId
                            }
                            schemaEntity.relations.append(relation)
                            schemaEntity.toOneRelations.append(relation)
                        }
                    } else if fullTypeName.hasPrefix("ToMany<") {
                        if fullTypeName.hasSuffix(">") {
                            let templateTypesString = fullTypeName.drop(first: "ToMany<".count, last: 1)
                            let templateTypes = templateTypesString.split(separator: ",")
                            let destinationType = templateTypes[0]
                            let myType = templateTypes[1]
                            
                            let relation = IdSync.SchemaToManyRelation(name: currIVar.name, type: fullTypeName, targetType: String(destinationType), ownerType: String(myType))
                            if let propertyUid = currIVar.annotations["uid"] as? Int64 {
                                var propId = IdUid()
                                propId.uid = propertyUid
                                relation.modelId = propId
                            }
                            if let backlinkProperty = currIVar.annotations["backlink"] as? String {
                                relation.backlinkProperty = backlinkProperty
                            } else {
                                throw Error.MissingBacklinkOnToManyRelation(entity: schemaEntity.className, relation: relation.relationName)
                            }
                            schemaEntity.relations.append(relation)
                            schemaEntity.toManyRelations.append(relation)
                        }
                    } else {
                        let schemaProperty = IdSync.SchemaProperty()
                        schemaProperty.propertyName = currIVar.name
                        schemaProperty.propertyType = fullTypeName
                        schemaProperty.isBuiltInType = isBuiltInTypeOrAlias(currIVar.typeName)
                        schemaProperty.isStringType = isStringTypeOrAlias(currIVar.typeName)
                        if schemaProperty.isStringType {
                            schemaEntity.hasStringProperties = true
                        }
                        schemaProperty.unwrappedPropertyType = currIVar.unwrappedTypeName
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
                        if currIVar.annotations["objectId"] != nil {
                            if let existingIdProperty = schemaEntity.idProperty {
                                throw Error.DuplicateIdAnnotation(entity: schemaEntity.className, found: currIVar.name, existing: existingIdProperty.propertyName)
                            }
                            schemaProperty.isObjectId = true
                            schemaEntity.idProperty = schemaProperty
                        } else if fullTypeName.hasPrefix("Id<") {
                            if fullTypeName.hasSuffix(">") {
                                let templateTypesString = fullTypeName.drop(first: "Id<".count, last: 1)
                                let templateTypes = templateTypesString.split(separator: ",")
                                let idType = templateTypes[0]
                                if idType == currType.localName {
                                    schemaEntity.idCandidates.append(schemaProperty)
                                }
                            }
                        }
                        schemaProperties.append(schemaProperty)
                    }
                }
                schemaEntity.properties = schemaProperties
                
                if schemaEntity.idProperty == nil { // No explicit annotation?
                    if schemaEntity.idCandidates.count <= 0 {
                        throw Error.MissingIdOnEntity(entity: schemaEntity.className)
                    } else if schemaEntity.idCandidates.count == 1 {
                        schemaEntity.idProperty = schemaEntity.idCandidates[0]
                    } else {
                        schemaEntity.idProperty = schemaEntity.idCandidates.first { $0.propertyName.lowercased() == "id" }
                        if schemaEntity.idProperty == nil {
                            schemaEntity.idProperty = schemaEntity.idCandidates.first { $0.propertyName.lowercased() == "objectid" }
                        }
                        if schemaEntity.idProperty == nil {
                            schemaEntity.idProperty = schemaEntity.idCandidates.first { $0.propertyName.lowercased() == "uniqueid" }
                        }
                        guard schemaEntity.idProperty != nil else {
                            throw Error.AmbiguousIdOnEntity(entity: schemaEntity.className, properties: schemaEntity.idCandidates.map { $0.propertyName })
                        }
                    }
                    schemaEntity.idProperty?.isObjectId = true
                }
                
                schemaData.entities.append(schemaEntity)
            }
        }
        
        let jsonFile = ObjectBoxFilters.modelJsonFile ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("model.json")
        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        
        ObjectBoxFilters.entities = schemaData.entities
    }
    
    /* Modify the dictionary of global objects that Stencil sees. */
    static func exposeObjects(to objectsDictionary: inout [String:Any]) {
        objectsDictionary["entities"] = ObjectBoxFilters.entities
    }
    
    /* Add any filters we define (think function call that receives input data): */
    static func addExtensions(_ ext: Stencil.Extension) {
        
    }
}
