//
//  ObjectBoxGenerator.swift
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


enum ObjectBoxGenerator {
        
    enum Error: Swift.Error {
        case DuplicateIdAnnotation(entity: String, found: String, existing: String)
        case MissingIdOnEntity(entity: String)
        case AmbiguousIdOnEntity(entity: String, properties: [String])
        case MissingBacklinkOnToManyRelation(entity: String, relation: String)
        case convertAnnotationMissingType(name: String, entity: String)
        case convertAnnotationMissingConverterOrDefault(name: String, entity: String)
    }

    static var modelJsonFile: URL?
    static var classVisibility = "internal"
    static var debugDataURL: URL?
    static var verbose: Bool = false
    
    static let builtInTypes = ["Bool", "Int8", "Int16", "Int32", "Int64", "Int", "Float", "Double", "Date", "NSDate",
                               "TimeInterval", "NSTimeInterval", "Data", "NSData", "Array<UInt8>", "[UInt8]"]
    static let builtInUnsignedTypes = ["UInt8", "UInt16", "UInt32", "UInt64", "UInt"]
    static let builtInStringTypes = ["String", "NSString"]
    static let builtInByteVectorTypes = ["Data", "NSData", "[UInt8]", "Array<UInt8>"]
    static let typeMappings: [String: EntityPropertyType] = [
        "Bool": .bool,
        "UInt8": .byte,
        "Int8": .byte,
        "Int16": .short,
        "UInt16": .short,
        "Int32": .int,
        "UInt32": .int,
        "Int64": .long,
        "UInt64": .long,
        "Id": .long,
        "Int": .long,
        "UInt": .long,
        "Float": .float,
        "Double": .double,
        "String": .string,
        "Date": .date,
        "NSDate": .date,
        "NSTimeInterval": .double,
        "TimeInterval": .double,
        "Data": .byteVector,
        "NSData": .byteVector,
        "Array<UInt8>": .byteVector,
        "[UInt8]": .byteVector,
    ]
    private static let validPropertyAnnotationNames = Set([
        "uid",
        "backlink",
        "name",
        "convert",
        "index",
        "unique",
        "id",
        "transient"
    ])
    private static let validTypeAnnotationNames = Set([
        "uid",
        "name",
        "entity",
        "Entity"
    ])

    private static var entities = [IdSync.SchemaEntity]()
    private static var lastEntityId = IdSync.IdUid()
    private static var lastIndexId = IdSync.IdUid()
    private static var lastRelationId = IdSync.IdUid()
    
    /// UUID as string identifying this installation.
    private static let installationIDDefaultsKey = "OBXInstallationID"
    /// Number of builds since last successful send.
    private static let buildCountDefaultsKey = "OBXBuildCount"
    /// Number of builds since last successful send.
    private static let lastSuccessfulSendTimeDefaultsKey = "OBXLastSuccessfulSendTime"
    /// Token to include with all events:
    private static let eventToken = "46d62a7c8def175e66900b3da09d698c"

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
                    "\t[Rename] Apply the current UID using // objectbox: uid = \(found)\n" +
                    "\t[Change/Reset] Apply a new UID using // objectbox: uid = \(unique)")
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
                    "\t[Rename] Apply the current UID using // objectbox: uid = \(found)\n" +
                    "\t[Change/Reset] Apply a new UID using // objectbox: uid = \(unique)")
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
                    "\t[Rename] Apply the current UID using // objectbox: uid = \(found)\n" +
                    "\t[Change/Reset] Apply a new UID using // objectbox: uid = \(unique)")
            case .RelationUIDTagNeedsValue(let entity, let relation):
                Log.error("Relation \(relation) of entity \(entity) has an \"// objectbox: uid n\" annotation missing the number n.")
            case .DuplicatePropertyName(let entity, let property):
                Log.error("Property \(property) of entity \(entity) exists twice.")
            }
        } else if let filterError = error as? ObjectBoxGenerator.Error {
            switch( filterError ) {
            case .DuplicateIdAnnotation(let entity, let found, let existing):
                Log.error("Entity \(entity) has both \(found) and \(existing) annotated as '// objectbox: id'. "
                    + "There can only be one.")
            case .MissingIdOnEntity(let entity):
                Log.error("Entity \(entity) needs an ID property of type Id or EntityId<\(entity)>, "
                    + "or an annotated ID property of type Int64 or UInt64.")
            case .AmbiguousIdOnEntity(let entity, let properties):
                Log.error("Entity \(entity) has several properties of type EntityId<\(entity)>, but no entity ID. "
                    + "Please designate one as this entity's ID using an '// objectbox: id' annotation. "
                    + "Candidates are: \(properties.joined(separator: ", "))")
            case .MissingBacklinkOnToManyRelation(let entity, let relation):
                Log.error("Missing backlink on to-many relation \(relation) of entity \(entity)")
            case .convertAnnotationMissingType(let name, let entity):
                Log.error("Must specify a dbType in '// objectbox: convert = { \"dbType\": \"TYPE HERE\" }' annotation"
                    + " of property \(name) of entity \(entity)")
            case .convertAnnotationMissingConverterOrDefault(let name, let entity):
                Log.error("Must specify a converter or default in '// objectbox: convert = { "
                    + "\"dbType\": \"TYPE HERE\", \"default\": \"DEFAULT HERE\" }' annotation of "
                    + "property \(name) of entity \(entity)")
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
            isBuiltIn = (builtInTypes + builtInUnsignedTypes).firstIndex(of: currPropTypeReadOnly.unwrappedTypeName) != nil
            if !isBuiltIn && currPropTypeReadOnly.unwrappedTypeName.hasPrefix("EntityId<") {
                isBuiltIn = true
            }
            currPropType = currPropTypeReadOnly.actualTypeName
        }
        
        return isBuiltIn
    }
    
    static func isUnsignedTypeOrAlias( _ typeName: TypeName? ) -> Bool {
        var isUnsigned: Bool = false
        var currPropType = typeName
        
        while let currPropTypeReadOnly = currPropType, !isUnsigned {
            isUnsigned = builtInUnsignedTypes.firstIndex(of: currPropTypeReadOnly.name) != nil
            currPropType = currPropTypeReadOnly.actualTypeName
        }
        
        return isUnsigned
    }
    
    /* Is this a string ivar that we need to save separately from the fixed-size types? */
    static func isStringTypeOrAlias( _ typeName: TypeName? ) -> Bool {
        var isStringType: Bool = false
        var currPropType = typeName
        
        while let currPropTypeReadOnly = currPropType, !isStringType {
            isStringType = builtInStringTypes.firstIndex(of: currPropTypeReadOnly.unwrappedTypeName) != nil
            currPropType = currPropTypeReadOnly.actualTypeName
        }
        
        return isStringType
    }
    
    static func isByteVectorTypeOrAlias( _ typeName: TypeName? ) -> Bool {
        var isByteVectorType: Bool = false
        var currPropType = typeName
        
        while let currPropTypeReadOnly = currPropType, !isByteVectorType {
            isByteVectorType = builtInByteVectorTypes.firstIndex(of: currPropTypeReadOnly.unwrappedTypeName) != nil
            currPropType = currPropTypeReadOnly.actualTypeName
        }
        
        return isByteVectorType
    }
    
    static func entityType(for typeName: TypeName?) -> EntityPropertyType {
        var currPropType = typeName
        
        while let currPropTypeReadOnly = currPropType {
            if let entityType = typeMappings[currPropTypeReadOnly.unwrappedTypeName] {
                return entityType
            } else if currPropTypeReadOnly.name.hasPrefix("EntityId<") {
                return .long
            } else if currPropTypeReadOnly.name.hasPrefix("Id") {
                return .long
            } else if currPropTypeReadOnly.name.hasPrefix("ToOne<") {
                return .relation
            }
            currPropType = currPropTypeReadOnly.actualTypeName
        }
        return .unknown
    }
    
    static func extractConvertAnnotation(_ annotation: Any?) -> [String: String]? {
        if let dict = annotation as? [String: String] {
            return dict
        }
        if let string = annotation as? String {
            return ["dbType": string]
        }
        
        return nil
    }
    
    static func processOneEntityProperty(_ currIVar: SourceryVariable, in currType: Type, into schemaProperties: inout [IdSync.SchemaProperty], entity schemaEntity: IdSync.SchemaEntity, schema schemaData: IdSync.Schema) throws {
        let fullTypeName = currIVar.typeName.name;
        var tmRelation: IdSync.SchemaToManyRelation? = nil
        if fullTypeName.hasPrefix("ToMany<") {
            if fullTypeName.hasSuffix(">") {
                let templateTypesString = fullTypeName.drop(first: "ToMany<".count, last: 1)
                let templateTypes = templateTypesString.split(separator: ",")
                let destinationType = templateTypes[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                let myType = currType.name
                
                let relation = IdSync.SchemaToManyRelation(name: currIVar.name, type: fullTypeName, targetType: String(destinationType), ownerType: String(myType))
                if let propertyUid = currIVar.annotations["uid"] as? Int64 {
                    relation.modelId = IdSync.IdUid(id: 0, uid: propertyUid)
                }
                if let backlinkProperty = currIVar.annotations["backlink"] as? String {
                    relation.backlinkProperty = backlinkProperty
                }
                tmRelation = relation
                schemaEntity.toManyRelations.append(relation)
            }
        }
        
        let schemaProperty = IdSync.SchemaProperty()
        schemaProperty.entityName = currType.localName
        schemaProperty.propertyName = currIVar.name
        schemaProperty.propertyType = fullTypeName
        schemaProperty.entityType = entityType(for: currIVar.typeName)
        schemaProperty.isBuiltInType = isBuiltInTypeOrAlias(currIVar.typeName)
        schemaProperty.isUnsignedType = isUnsignedTypeOrAlias(currIVar.typeName)
        schemaProperty.isStringType = isStringTypeOrAlias(currIVar.typeName)
        schemaProperty.isByteVectorType = isByteVectorTypeOrAlias(currIVar.typeName)
        schemaProperty.isRelation = fullTypeName.hasPrefix("ToOne<")
        schemaProperty.isToManyRelation = fullTypeName.hasPrefix("ToMany<")
        schemaProperty.toManyRelation = tmRelation
        schemaProperty.isFirst = schemaProperties.isEmpty
        if schemaProperty.isStringType {
            schemaEntity.hasStringProperties = true
        }
        if schemaProperty.isByteVectorType {
            schemaEntity.hasByteVectorProperties = true
        }
        schemaProperty.unwrappedPropertyType = currIVar.unwrappedTypeName
        schemaProperty.dbName = currIVar.annotations["name"] as? String
        if let dbNameIsEmpty = schemaProperty.dbName?.isEmpty, dbNameIsEmpty { schemaProperty.dbName = nil }
        schemaProperty.name = schemaProperty.dbName ?? schemaProperty.propertyName
        if let propertyUidObject = currIVar.annotations["uid"], let propertyUid = (propertyUidObject as? NSNumber)?.int64Value {
            var propId = IdSync.IdUid()
            propId.uid = propertyUid
            schemaProperty.modelId = propId
        }
        
        if let convertDict = extractConvertAnnotation(currIVar.annotations["convert"]) {
            guard let dbType = convertDict["dbType"] else {
                throw Error.convertAnnotationMissingType(name: schemaProperty.propertyName, entity: schemaProperty.entityName)
            }
            if let typeName = convertDict["converter"] {
                schemaProperty.converterName = typeName
                schemaProperty.conversionPrefix = "\(typeName).convert("
                schemaProperty.conversionSuffix = ")"
                schemaProperty.unConversionPrefix = "\(typeName).convert("
                schemaProperty.unConversionSuffix = ")"
            } else {
                schemaProperty.converterName = schemaProperty.unwrappedPropertyType
                schemaProperty.conversionPrefix = "optConstruct(\(schemaProperty.unwrappedPropertyType).self, rawValue: "
                schemaProperty.unConversionPrefix = ""
                schemaProperty.unConversionSuffix = ".rawValue"
                if let defaultValue = convertDict["default"] {
                    schemaProperty.conversionSuffix = ") ?? \(defaultValue)"
                } else if schemaProperty.propertyType.hasSuffix("?") {
                    schemaProperty.conversionSuffix = ")"
                } else {
                    throw Error.convertAnnotationMissingConverterOrDefault(name: schemaProperty.propertyName, entity: schemaProperty.entityName)
                }
            }
            
            schemaProperty.typeBeforeConversion = schemaProperty.propertyType
            schemaProperty.propertyType = dbType
            schemaProperty.unwrappedPropertyType = dbType.trimmingCharacters(in: CharacterSet(charactersIn: "?"))
            
            if let entityType = typeMappings[schemaProperty.unwrappedPropertyType] {
                schemaProperty.entityType = entityType
            }
            schemaProperty.isUnsignedType = builtInUnsignedTypes.firstIndex(of: schemaProperty.unwrappedPropertyType) != nil
            schemaProperty.isStringType = builtInStringTypes.firstIndex(of: schemaProperty.unwrappedPropertyType) != nil
            schemaProperty.isByteVectorType = builtInByteVectorTypes.firstIndex(of: schemaProperty.unwrappedPropertyType) != nil
        }
        
        if currIVar.annotations["index"] as? Int64 == 1 {
            schemaProperty.indexType = schemaProperty.isStringType ? .hashIndex : .valueIndex
        } else if let indexType = currIVar.annotations["index"] as? String {
            if (indexType == "hash") {
                schemaProperty.indexType = .hashIndex
            } else if (indexType == "hash64") {
                schemaProperty.indexType = .hash64Index
            } else if (indexType == "value") {
                schemaProperty.indexType = .valueIndex
            }
        }
        if currIVar.annotations["unique"] as? Int64 == 1 {
            schemaProperty.isUniqueIndex = true
            if (schemaProperty.indexType == .none) {
                schemaProperty.indexType = schemaProperty.isStringType ? .hashIndex : .valueIndex
            }
        }

        if let objectIdAnnotationValue = currIVar.annotations["id"] {
            if let existingIdProperty = schemaEntity.idProperty {
                throw Error.DuplicateIdAnnotation(entity: schemaEntity.className, found: currIVar.name,
                                                  existing: existingIdProperty.propertyName)
            }
            schemaProperty.isObjectId = true
            schemaEntity.idProperty = schemaProperty
            if let objectAnnotationDict = objectIdAnnotationValue as? NSDictionary {
                if let assignableBool = objectAnnotationDict["assignable"] as? Bool, assignableBool == true {
                    schemaProperty.entityFlags.insert(.idSelfAssignable)
                }
            }
        } else {
            if fullTypeName == "Id" {
                schemaEntity.idCandidates.append(schemaProperty)
            } else if fullTypeName.hasPrefix("EntityId<") && fullTypeName.hasSuffix(">") {
                let templateTypesString = fullTypeName.drop(first: "EntityId<".count, last: 1)
                let templateTypes = templateTypesString.split(separator: ",")
                let idType = templateTypes[0]
                if idType == currType.localName {
                    schemaEntity.idCandidates.append(schemaProperty)
                }
            }
        }
        
        if schemaProperty.isObjectId {
            schemaProperty.entityFlags.insert(.id)
        }
        if !schemaProperty.isObjectId && schemaProperty.isUnsignedType {
            schemaProperty.entityFlags.insert(.unsigned)
        }
        if schemaProperty.isUniqueIndex {
            schemaProperty.entityFlags.insert(.unique)
        }
        if schemaProperty.indexType == .hashIndex {
            schemaProperty.entityFlags.insert(.indexHash)
        } else if schemaProperty.indexType == .hash64Index {
            schemaProperty.entityFlags.insert(.indexHash64)
        }
        if schemaProperty.indexType != .none {
            schemaProperty.entityFlags.insert(.indexed)
        }
        if schemaProperty.isRelation && fullTypeName.hasPrefix("ToOne<") && fullTypeName.hasSuffix(">") {
            let templateTypesString = fullTypeName.drop(first: "ToOne<".count, last: 1)
            let templateTypes = templateTypesString.split(separator: ",")
            let destinationType = templateTypes[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let relation = IdSync.SchemaRelation(name: schemaProperty.propertyName, type: schemaProperty.propertyType,
                                                 targetType: destinationType)
            relation.property = schemaProperty
            schemaEntity.relations.append(relation)
            if let backlink = currIVar.annotations["backlink"] as? String {
                print("warning: Found an // objectbox: backlink annotation on ToOne relation "
                    + "\"\(schemaProperty.propertyName)\". Did you mean to put "
                    + "// objectbox: backlink = \"\(currIVar.name)\"  on the ToMany relation \"\(backlink)\" "
                    + "in \"\(destinationType)\"?")
            }
        }
        
        if tmRelation != nil {
            tmRelation?.property = schemaProperty
        }

        schemaProperties.append(schemaProperty)
    }
    
    static func processOneEntityType(_ currType: Type, entityBased isEntityBased: Bool, into schemaData: IdSync.Schema) throws {
        let schemaEntity = IdSync.SchemaEntity()
        schemaEntity.className = currType.localName
        schemaEntity.isValueType = currType.kind == "struct"
        schemaEntity.modelUid = currType.annotations["uid"] as? Int64
        schemaEntity.dbName = currType.annotations["name"] as? String
        if let dbNameIsEmpty = schemaEntity.dbName?.isEmpty, dbNameIsEmpty { schemaEntity.dbName = nil }
        schemaEntity.name = schemaEntity.dbName ?? schemaEntity.className
        schemaEntity.isEntitySubclass = isEntityBased
        
        var schemaProperties = Array<IdSync.SchemaProperty>()
        try currType.variables.forEach { currIVar in
            warnIfAnnotations(otherThan: ObjectBoxGenerator.validPropertyAnnotationNames,
                              in: Set(currIVar.annotations.keys), of: currIVar.name)
            guard !currIVar.annotations.contains(reference: "transient") else { return } // Exits only this iteration of the foreach block
            guard !currIVar.isStatic else { return } // Exits only this iteration of the foreach block
            guard !currIVar.isComputed else { return } // Exits only this iteration of the foreach block
            
            try processOneEntityProperty(currIVar, in: currType, into: &schemaProperties, entity: schemaEntity, schema: schemaData)
        }
        schemaProperties.last?.isLast = true
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
            schemaEntity.idProperty?.entityFlags.insert(.id)
            // No other binding marks IDs as unsigned, so don't break compatibility.
            schemaEntity.idProperty?.entityFlags.remove(.unsigned)
        }
        
        schemaProperties.forEach { schemaProperty in
            var flagsList: [String] = []
            if schemaProperty.entityFlags.contains(.id) { flagsList.append(".id") }
            if schemaProperty.entityFlags.contains(.unsigned) { flagsList.append(".unsigned") }
            if schemaProperty.entityFlags.contains(.unique) { flagsList.append(".unique") }
            if schemaProperty.entityFlags.contains(.indexHash) { flagsList.append(".indexHash") }
            if schemaProperty.entityFlags.contains(.indexHash64) { flagsList.append(".indexHash64") }
            if schemaProperty.entityFlags.contains(.indexed) { flagsList.append(".indexed") }
            if schemaProperty.entityFlags.contains(.idSelfAssignable) { flagsList.append(".idSelfAssignable") }
            if flagsList.count > 0 {
                schemaProperty.flagsList = ", flags: [\(flagsList.joined(separator: ", "))]"
            }
        }
        
        schemaData.entities.append(schemaEntity)
        schemaData.entitiesByName[schemaEntity.className] = schemaEntity
    }
    
    static func warnIfAnnotations(otherThan validAnnotations: Set<String>,
                                  in annotations: Set<String>, of name: String) {
        let unknownAnnotations = annotations.filter {
            !validAnnotations.contains($0)
        }
        if unknownAnnotations.count > 0 {
            print("warning: \(name) has unknown annotations \(unknownAnnotations.joined(separator: ",")).")
        }
    }
    
    static func eventData(name: String, uniqueID: String? = nil, properties: String = "") -> String {
        let locale = Locale.current
        let country = countryMappings[locale.regionCode?.uppercased() ?? "?"] ?? "?"
        let language = languageMappings[locale.languageCode?.lowercased() ?? "?"] ?? "?"
        let uniqueIDJSON = (uniqueID != nil) ? ", \"distinct_id\": \"\(uniqueID!)\"" : ""
        let eventInfo = "{ \"event\": \(quoted(name)), \"properties\": { "
            + "\"token\": \(quoted(ObjectBoxGenerator.eventToken)), \"ip\": true, \"Tool\": \"Sourcery\", "
            + "\"c\": \(quoted(country)), \"lang\": \(quoted(language))"
            + "\(uniqueIDJSON)\((properties.count > 0) ? (", " + properties) : "") } }"
        return eventInfo
    }
    
    static func sendEvent(name: String, uniqueID: String? = nil, properties: String = "") {
        // Attach statistics to URL:
        let eventInfo = eventData(name: name, uniqueID: uniqueID, properties: properties)
        var urlString = "https://api.mixpanel.com/track/?data="
        let base64EncodedProperties = (eventInfo.data(using: .utf8)?.base64EncodedString() ?? "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        guard base64EncodedProperties.count > 0 else {
            print("warning: Couldn't base64-encode statistics. This does not affect your generated code.")
            return
        }
        urlString.append(base64EncodedProperties)
        
        if verbose {
            print("Trying to send statistics: <<\(eventInfo)>>")
        }
        
        // Actually send them off:
        let task = URLSession.shared.dataTask(with: URL(string: urlString)!) { data, response, error in
            guard error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if verbose {
                    print("Couldn't send statistics: \((response as? HTTPURLResponse)?.statusCode ?? 0) "
                        + "\(error?.localizedDescription ?? "<no error description>")")
                }
                return
            }
            
            // Successfully sent? Reset counter and remember when we last sent so we don't call home too often:
            UserDefaults.standard.set(0, forKey: ObjectBoxGenerator.buildCountDefaultsKey)
            UserDefaults.standard.set(Date().timeIntervalSinceReferenceDate, forKey: ObjectBoxGenerator.lastSuccessfulSendTimeDefaultsKey)
            
            if verbose {
                print("Successfully sent statistics.")
            }
        }
        task.resume()
    }
    
    static func checkCI() -> String? {
        // https://docs.travis-ci.com/user/environment-variables/#Default-Environment-Variables
        if ProcessInfo.processInfo.environment["CI"] == "true" {
            return "T"
            // https://wiki.jenkins.io/display/JENKINS/Building+a+software+project#Buildingasoftwareproject-below
        } else if ProcessInfo.processInfo.environment["JENKINS_URL"] != nil {
            return "J"
            // https://docs.gitlab.com/ee/ci/variables/
        } else if ProcessInfo.processInfo.environment["GITLAB_CI"] != nil {
            return "GL"
            // https://circleci.com/docs/1.0/environment-variables/
        } else if ProcessInfo.processInfo.environment["CIRCLECI"] != nil {
            return "C"
            // https://documentation.codeship.com/pro/builds-and-configuration/steps/
        } else if ProcessInfo.processInfo.environment["CI_NAME"]?.lowercased() == "codeship" {
            return "CS"
        } else if ProcessInfo.processInfo.environment["CI"] != nil {
            return "Other"
        }
        
        return nil
    }
    
    static func quoted(_ string: String) -> String {
        return "\"" + string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r").replacingOccurrences(of: "\n", with: "\\n") + "\""
    }
    
    static func startup(statistics: Bool) throws {
        if statistics {
            var buildCount = (UserDefaults.standard.object(forKey: ObjectBoxGenerator.buildCountDefaultsKey) as? Int) ?? 0
            buildCount += 1
            UserDefaults.standard.set(buildCount, forKey: ObjectBoxGenerator.buildCountDefaultsKey)
            
            let lastSuccessfulSendTime = UserDefaults.standard.double(forKey: ObjectBoxGenerator.lastSuccessfulSendTimeDefaultsKey)
            // Send at most once per day, but use 23 hours so we don't skip a day on a DST change or early work start:
            guard (Date().timeIntervalSinceReferenceDate - lastSuccessfulSendTime) > (3600.0 * 23.0) else {
                return
            }
            
            // Give installation a unique identifier so we can get a rough idea of how many people use this:
            let existingInstallationID = UserDefaults.standard.string(forKey: ObjectBoxGenerator.installationIDDefaultsKey)
            let installationUID = existingInstallationID ?? UUID().uuidString
            if existingInstallationID == nil {
                UserDefaults.standard.set(installationUID, forKey: ObjectBoxGenerator.installationIDDefaultsKey)
            }
            
            // Grab some info from Xcode-set environment variables, if available:
            let minSysVersion: String
            if let deploymentTargetVarName = ProcessInfo.processInfo.environment["DEPLOYMENT_TARGET_CLANG_ENV_NAME"] {
                minSysVersion = quoted(ProcessInfo.processInfo.environment[deploymentTargetVarName] ?? "?")
            } else {
                minSysVersion = "\"?\""
            }
            let architectures = quoted(ProcessInfo.processInfo.environment["ARCHS"] ?? "?")
            let moduleName = ProcessInfo.processInfo.environment["PRODUCT_MODULE_NAME"] ?? "?"
            let destPlatform = quoted(ProcessInfo.processInfo.environment["SDK_NAME"] ?? "?")
            let version = ProcessInfo.processInfo.operatingSystemVersion
            let xcodeVersion = quoted(ProcessInfo.processInfo.environment["XCODE_VERSION_ACTUAL"] ?? "?")
            let myVersion = quoted(Sourcery.version)
            var properties = "\"BuildOS\": \"macOS\", "
                + "\"BuildOSVersion\": \"\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)\", "
                + "\"BuildCount\": \(buildCount), \"AppHash\": \"\(moduleName.sha1())\", "
                + "\"Platform\": \(destPlatform), \"Architectures\": \(architectures), "
                + "\"MinimumOSVersion\": \(minSysVersion), \"Xcode\": \(xcodeVersion), "
                + "\"Version\": \(myVersion)"
            if let ci = checkCI() {
                properties.append(", \"CI\": \"\(ci)\"")
            }
            
            sendEvent(name: "Build", uniqueID: installationUID, properties: properties)
        }
    }
    
    /* Process the parsed syntax tree, possibly annotating or otherwise
        extending it. */
    static func process(parsingResult result: inout Sourcery.ParsingResult) throws {
        let schemaData = IdSync.Schema()
        
        try result.types.all.forEach { currType in
            warnIfAnnotations(otherThan: ObjectBoxGenerator.validTypeAnnotationNames,
                              in: Set(currType.annotations.keys), of: currType.name)
            let isEntityBased = currType.inheritedTypes.contains("Entity")
            // The annotation should be lowercase "entity", but given the protocol is uppercase, we allow that too,
            // as a convenience for users who use both and get their case mixed up:
            if isEntityBased || currType.annotations["entity"] != nil || currType.annotations["Entity"] != nil {
                try processOneEntityType(currType, entityBased: isEntityBased, into: schemaData)
            }
        }
        
        let jsonFile = ObjectBoxGenerator.modelJsonFile ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("model.json")
        let idSync = try IdSync.IdSync(jsonFile: jsonFile)
        try idSync.sync(schema: schemaData)
        try idSync.write()
        
        if let debugDataURL = ObjectBoxGenerator.debugDataURL {
            try "\(schemaData)".write(to: debugDataURL, atomically: true, encoding: .utf8)
        }

        ObjectBoxGenerator.entities = schemaData.entities
        ObjectBoxGenerator.lastEntityId = schemaData.lastEntityId
        ObjectBoxGenerator.lastIndexId = schemaData.lastIndexId
        ObjectBoxGenerator.lastRelationId = schemaData.lastRelationId
    }
    
    /* Modify the dictionary of global objects that Stencil sees. */
    static func exposeObjects(to objectsDictionary: inout [String:Any]) {
        objectsDictionary["entities"] = ObjectBoxGenerator.entities
        objectsDictionary["visibility"] = ObjectBoxGenerator.classVisibility;
        objectsDictionary["lastEntityId"] = ObjectBoxGenerator.lastEntityId
        objectsDictionary["lastIndexId"] = ObjectBoxGenerator.lastIndexId
        objectsDictionary["lastRelationId"] = ObjectBoxGenerator.lastRelationId
    }
    
    private static let countryMappings = [
        "AF": "AFG", //  Afghanistan
        "AX": "ALA", //  Åland Islands
        "AL": "ALB", //  Albania
        "DZ": "DZA", //  Algeria
        "AS": "ASM", //  American Samoa
        "AD": "AND", //  Andorra
        "AO": "AGO", //  Angola
        "AI": "AIA", //  Anguilla
        "AQ": "ATA", //  Antarctica
        "AG": "ATG", //  Antigua and Barbuda
        "AR": "ARG", //  Argentina
        "AM": "ARM", //  Armenia
        "AW": "ABW", //  Aruba
        "AU": "AUS", //  Australia
        "AT": "AUT", //  Austria
        "AZ": "AZE", //  Azerbaijan
        "BS": "BHS", //  Bahamas
        "BH": "BHR", //  Bahrain
        "BD": "BGD", //  Bangladesh
        "BB": "BRB", //  Barbados
        "BY": "BLR", //  Belarus
        "BE": "BEL", //  Belgium
        "BZ": "BLZ", //  Belize
        "BJ": "BEN", //  Benin
        "BM": "BMU", //  Bermuda
        "BT": "BTN", //  Bhutan
        "BO": "BOL", //  Bolivia (Plurinational State of)
        "BQ": "BES", //  Bonaire, Sint Eustatius and Saba
        "BA": "BIH", //  Bosnia and Herzegovina
        "BW": "BWA", //  Botswana
        "BV": "BVT", //  Bouvet Island
        "BR": "BRA", //  Brazil
        "IO": "IOT", //  British Indian Ocean Territory
        "BN": "BRN", //  Brunei Darussalam
        "BG": "BGR", //  Bulgaria
        "BF": "BFA", //  Burkina Faso
        "BI": "BDI", //  Burundi
        "CV": "CPV", //  Cabo Verde
        "KH": "KHM", //  Cambodia
        "CM": "CMR", //  Cameroon
        "CA": "CAN", //  Canada
        "KY": "CYM", //  Cayman Islands
        "CF": "CAF", //  Central African Republic
        "TD": "TCD", //  Chad
        "CL": "CHL", //  Chile
        "CN": "CHN", //  China
        "CX": "CXR", //  Christmas Island
        "CC": "CCK", //  Cocos (Keeling) Islands
        "CO": "COL", //  Colombia
        "KM": "COM", //  Comoros
        "CG": "COG", //  Congo
        "CD": "COD", //  Congo, Democratic Republic of the
        "CK": "COK", //  Cook Islands
        "CR": "CRI", //  Costa Rica
        "CI": "CIV", //  Côte d'Ivoire
        "HR": "HRV", //  Croatia
        "CU": "CUB", //  Cuba
        "CW": "CUW", //  Curaçao
        "CY": "CYP", //  Cyprus
        "CZ": "CZE", //  Czechia
        "DK": "DNK", //  Denmark
        "DJ": "DJI", //  Djibouti
        "DM": "DMA", //  Dominica
        "DO": "DOM", //  Dominican Republic
        "EC": "ECU", //  Ecuador
        "EG": "EGY", //  Egypt
        "SV": "SLV", //  El Salvador
        "GQ": "GNQ", //  Equatorial Guinea
        "ER": "ERI", //  Eritrea
        "EE": "EST", //  Estonia
        "SZ": "SWZ", //  Eswatini
        "ET": "ETH", //  Ethiopia
        "FK": "FLK", //  Falkland Islands (Malvinas)
        "FO": "FRO", //  Faroe Islands
        "FJ": "FJI", //  Fiji
        "FI": "FIN", //  Finland
        "FR": "FRA", //  France
        "GF": "GUF", //  French Guiana
        "PF": "PYF", //  French Polynesia
        "TF": "ATF", //  French Southern Territories
        "GA": "GAB", //  Gabon
        "GM": "GMB", //  Gambia
        "GE": "GEO", //  Georgia
        "DE": "DEU", //  Germany
        "GH": "GHA", //  Ghana
        "GI": "GIB", //  Gibraltar
        "GR": "GRC", //  Greece
        "GL": "GRL", //  Greenland
        "GD": "GRD", //  Grenada
        "GP": "GLP", //  Guadeloupe
        "GU": "GUM", //  Guam
        "GT": "GTM", //  Guatemala
        "GG": "GGY", //  Guernsey
        "GN": "GIN", //  Guinea
        "GW": "GNB", //  Guinea-Bissau
        "GY": "GUY", //  Guyana
        "HT": "HTI", //  Haiti
        "HM": "HMD", //  Heard Island and McDonald Islands
        "VA": "VAT", //  Holy See
        "HN": "HND", //  Honduras
        "HK": "HKG", //  Hong Kong
        "HU": "HUN", //  Hungary
        "IS": "ISL", //  Iceland
        "IN": "IND", //  India
        "ID": "IDN", //  Indonesia
        "IR": "IRN", //  Iran (Islamic Republic of)
        "IQ": "IRQ", //  Iraq
        "IE": "IRL", //  Ireland
        "IM": "IMN", //  Isle of Man
        "IL": "ISR", //  Israel
        "IT": "ITA", //  Italy
        "JM": "JAM", //  Jamaica
        "JP": "JPN", //  Japan
        "JE": "JEY", //  Jersey
        "JO": "JOR", //  Jordan
        "KZ": "KAZ", //  Kazakhstan
        "KE": "KEN", //  Kenya
        "KI": "KIR", //  Kiribati
        "KP": "PRK", //  Korea (Democratic People's Republic of)
        "KR": "KOR", //  Korea, Republic of
        "KW": "KWT", //  Kuwait
        "KG": "KGZ", //  Kyrgyzstan
        "LA": "LAO", //  Lao People's Democratic Republic
        "LV": "LVA", //  Latvia
        "LB": "LBN", //  Lebanon
        "LS": "LSO", //  Lesotho
        "LR": "LBR", //  Liberia
        "LY": "LBY", //  Libya
        "LI": "LIE", //  Liechtenstein
        "LT": "LTU", //  Lithuania
        "LU": "LUX", //  Luxembourg
        "MO": "MAC", //  Macao
        "MG": "MDG", //  Madagascar
        "MW": "MWI", //  Malawi
        "MY": "MYS", //  Malaysia
        "MV": "MDV", //  Maldives
        "ML": "MLI", //  Mali
        "MT": "MLT", //  Malta
        "MH": "MHL", //  Marshall Islands
        "MQ": "MTQ", //  Martinique
        "MR": "MRT", //  Mauritania
        "MU": "MUS", //  Mauritius
        "YT": "MYT", //  Mayotte
        "MX": "MEX", //  Mexico
        "FM": "FSM", //  Micronesia (Federated States of)
        "MD": "MDA", //  Moldova, Republic of
        "MC": "MCO", //  Monaco
        "MN": "MNG", //  Mongolia
        "ME": "MNE", //  Montenegro
        "MS": "MSR", //  Montserrat
        "MA": "MAR", //  Morocco
        "MZ": "MOZ", //  Mozambique
        "MM": "MMR", //  Myanmar
        "NA": "NAM", //  Namibia
        "NR": "NRU", //  Nauru
        "NP": "NPL", //  Nepal
        "NL": "NLD", //  Netherlands
        "NC": "NCL", //  New Caledonia
        "NZ": "NZL", //  New Zealand
        "NI": "NIC", //  Nicaragua
        "NE": "NER", //  Niger
        "NG": "NGA", //  Nigeria
        "NU": "NIU", //  Niue
        "NF": "NFK", //  Norfolk Island
        "MK": "MKD", //  North Macedonia
        "MP": "MNP", //  Northern Mariana Islands
        "NO": "NOR", //  Norway
        "OM": "OMN", //  Oman
        "PK": "PAK", //  Pakistan
        "PW": "PLW", //  Palau
        "PS": "PSE", //  Palestine, State of
        "PA": "PAN", //  Panama
        "PG": "PNG", //  Papua New Guinea
        "PY": "PRY", //  Paraguay
        "PE": "PER", //  Peru
        "PH": "PHL", //  Philippines
        "PN": "PCN", //  Pitcairn
        "PL": "POL", //  Poland
        "PT": "PRT", //  Portugal
        "PR": "PRI", //  Puerto Rico
        "QA": "QAT", //  Qatar
        "RE": "REU", //  Réunion
        "RO": "ROU", //  Romania
        "RU": "RUS", //  Russian Federation
        "RW": "RWA", //  Rwanda
        "BL": "BLM", //  Saint Barthélemy
        "SH": "SHN", //  Saint Helena, Ascension and Tristan da Cunha
        "KN": "KNA", //  Saint Kitts and Nevis
        "LC": "LCA", //  Saint Lucia
        "MF": "MAF", //  Saint Martin (French part)
        "PM": "SPM", //  Saint Pierre and Miquelon
        "VC": "VCT", //  Saint Vincent and the Grenadines
        "WS": "WSM", //  Samoa
        "SM": "SMR", //  San Marino
        "ST": "STP", //  Sao Tome and Principe
        "SA": "SAU", //  Saudi Arabia
        "SN": "SEN", //  Senegal
        "RS": "SRB", //  Serbia
        "SC": "SYC", //  Seychelles
        "SL": "SLE", //  Sierra Leone
        "SG": "SGP", //  Singapore
        "SX": "SXM", //  Sint Maarten (Dutch part)
        "SK": "SVK", //  Slovakia
        "SI": "SVN", //  Slovenia
        "SB": "SLB", //  Solomon Islands
        "SO": "SOM", //  Somalia
        "ZA": "ZAF", //  South Africa
        "GS": "SGS", //  South Georgia and the South Sandwich Islands
        "SS": "SSD", //  South Sudan
        "ES": "ESP", //  Spain
        "LK": "LKA", //  Sri Lanka
        "SD": "SDN", //  Sudan
        "SR": "SUR", //  Suriname
        "SJ": "SJM", //  Svalbard and Jan Mayen
        "SE": "SWE", //  Sweden
        "CH": "CHE", //  Switzerland
        "SY": "SYR", //  Syrian Arab Republic
        "TW": "TWN", //  Taiwan, Province of China[a]
        "TJ": "TJK", //  Tajikistan
        "TZ": "TZA", //  Tanzania, United Republic of
        "TH": "THA", //  Thailand
        "TL": "TLS", //  Timor-Leste
        "TG": "TGO", //  Togo
        "TK": "TKL", //  Tokelau
        "TO": "TON", //  Tonga
        "TT": "TTO", //  Trinidad and Tobago
        "TN": "TUN", //  Tunisia
        "TR": "TUR", //  Turkey
        "TM": "TKM", //  Turkmenistan
        "TC": "TCA", //  Turks and Caicos Islands
        "TV": "TUV", //  Tuvalu
        "UG": "UGA", //  Uganda
        "UA": "UKR", //  Ukraine
        "AE": "ARE", //  United Arab Emirates
        "GB": "GBR", //  United Kingdom of Great Britain and Northern Ireland
        "US": "USA", //  United States of America
        "UM": "UMI", //  United States Minor Outlying Islands
        "UY": "URY", //  Uruguay
        "UZ": "UZB", //  Uzbekistan
        "VU": "VUT", //  Vanuatu
        "VE": "VEN", //  Venezuela (Bolivarian Republic of)
        "VN": "VNM", //  Viet Nam
        "VG": "VGB", //  Virgin Islands (British)
        "VI": "VIR", //  Virgin Islands (U.S.)
        "WF": "WLF", //  Wallis and Futuna
        "EH": "ESH", //  Western Sahara
        "YE": "YEM", //  Yemen
        "ZM": "ZMB", //  Zambia
        "ZW": "ZWE", //  Zimbabwe        "?": "?"
    ]
    private static let languageMappings = [
        "ab": "abk", // Abkhazian
        "aa": "aar", // Afar
        "af": "afr", // Afrikaans
        "ak": "aka", // Akan
        "sq": "sqi", // Albanian
        "am": "amh", // Amharic
        "ar": "ara", // Arabic
        "an": "arg", // Aragonese
        "hy": "hye", // Armenian
        "as": "asm", // Assamese
        "av": "ava", // Avaric
        "ae": "ave", // Avestan
        "ay": "aym", // Aymara
        "az": "aze", // Azerbaijani
        "bm": "bam", // Bambara
        "ba": "bak", // Bashkir
        "eu": "eus", // Basque
        "be": "bel", // Belarusian
        "bn": "ben", // Bengali
        "bh": "bih", // Bihari languages
        "bi": "bis", // Bislama
        "bs": "bos", // Bosnian
        "br": "bre", // Breton
        "bg": "bul", // Bulgarian
        "my": "mya", // Burmese
        "ca": "cat", // Catalan, Valencian
        "ch": "cha", // Chamorro
        "ce": "che", // Chechen
        "ny": "nya", // Chichewa, Chewa, Nyanja
        "zh": "zho", // Chinese
        "cv": "chv", // Chuvash
        "kw": "cor", // Cornish
        "co": "cos", // Corsican
        "cr": "cre", // Cree
        "hr": "hrv", // Croatian
        "cs": "ces", // Czech
        "da": "dan", // Danish
        "dv": "div", // Divehi, Dhivehi, Maldivian
        "nl": "nld", // Dutch, Flemish
        "dz": "dzo", // Dzongkha
        "en": "eng", // English
        "eo": "epo", // Esperanto
        "et": "est", // Estonian
        "ee": "ewe", // Ewe
        "fo": "fao", // Faroese
        "fj": "fij", // Fijian
        "fi": "fin", // Finnish
        "fr": "fra", // French
        "ff": "ful", // Fulah
        "gl": "glg", // Galician
        "ka": "kat", // Georgian
        "de": "deu", // German
        "el": "ell", // Greek, Modern (1453-)
        "gn": "grn", // Guarani
        "gu": "guj", // Gujarati
        "ht": "hat", // Haitian, Haitian Creole
        "ha": "hau", // Hausa
        "he": "heb", // Hebrew
        "hz": "her", // Herero
        "hi": "hin", // Hindi
        "ho": "hmo", // Hiri Motu
        "hu": "hun", // Hungarian
        "ia": "ina", // Interlingua (International Auxiliary Language Association)
        "id": "ind", // Indonesian
        "ie": "ile", // Interlingue, Occidental
        "ga": "gle", // Irish
        "ig": "ibo", // Igbo
        "ik": "ipk", // Inupiaq
        "io": "ido", // Ido
        "is": "isl", // Icelandic
        "it": "ita", // Italian
        "iu": "iku", // Inuktitut
        "ja": "jpn", // Japanese
        "jv": "jav", // Javanese
        "kl": "kal", // Kalaallisut, Greenlandic
        "kn": "kan", // Kannada
        "kr": "kau", // Kanuri
        "ks": "kas", // Kashmiri
        "kk": "kaz", // Kazakh
        "km": "khm", // Central Khmer
        "ki": "kik", // Kikuyu, Gikuyu
        "rw": "kin", // Kinyarwanda
        "ky": "kir", // Kirghiz, Kyrgyz
        "kv": "kom", // Komi
        "kg": "kon", // Kongo
        "ko": "kor", // Korean
        "ku": "kur", // Kurdish
        "kj": "kua", // Kuanyama, Kwanyama
        "la": "lat", // Latin
        "lb": "ltz", // Luxembourgish, Letzeburgesch
        "lg": "lug", // Ganda
        "li": "lim", // Limburgan, Limburger, Limburgish
        "ln": "lin", // Lingala
        "lo": "lao", // Lao
        "lt": "lit", // Lithuanian
        "lu": "lub", // Luba-Katanga
        "lv": "lav", // Latvian
        "gv": "glv", // Manx
        "mk": "mkd", // Macedonian
        "mg": "mlg", // Malagasy
        "ms": "msa", // Malay
        "ml": "mal", // Malayalam
        "mt": "mlt", // Maltese
        "mi": "mri", // Maori
        "mr": "mar", // Marathi
        "mh": "mah", // Marshallese
        "mn": "mon", // Mongolian
        "na": "nau", // Nauru
        "nv": "nav", // Navajo, Navaho
        "nd": "nde", // North Ndebele
        "ne": "nep", // Nepali
        "ng": "ndo", // Ndonga
        "nb": "nob", // Norwegian Bokml
        "nn": "nno", // Norwegian Nynorsk
        "no": "nor", // Norwegian
        "ii": "iii", // Sichuan Yi, Nuosu
        "nr": "nbl", // South Ndebele
        "oc": "oci", // Occitan
        "oj": "oji", // Ojibwa
        "cu": "chu", // Church Slavic, Old Slavonic, Church Slavonic, Old Bulgarian, Old Church Slavonic
        "om": "orm", // Oromo
        "or": "ori", // Oriya
        "os": "oss", // Ossetian, Ossetic
        "pa": "pan", // Punjabi, Panjabi
        "pi": "pli", // Pali
        "fa": "fas", // Persian
        "pl": "pol", // Polish
        "ps": "pus", // Pashto, Pushto
        "pt": "por", // Portuguese
        "qu": "que", // Quechua
        "rm": "roh", // Romansh
        "rn": "run", // Rundi
        "ro": "ron", // Romanian, Moldavian, Moldovan
        "ru": "rus", // Russian
        "sa": "san", // Sanskrit
        "sc": "srd", // Sardinian
        "sd": "snd", // Sindhi
        "se": "sme", // Northern Sami
        "sm": "smo", // Samoan
        "sg": "sag", // Sango
        "sr": "srp", // Serbian
        "gd": "gla", // Gaelic, Scottish Gaelic
        "sn": "sna", // Shona
        "si": "sin", // Sinhala, Sinhalese
        "sk": "slk", // Slovak
        "sl": "slv", // Slovenian
        "so": "som", // Somali
        "st": "sot", // Southern Sotho
        "es": "spa", // Spanish, Castilian
        "su": "sun", // Sundanese
        "sw": "swa", // Swahili
        "ss": "ssw", // Swati
        "sv": "swe", // Swedish
        "ta": "tam", // Tamil
        "te": "tel", // Telugu
        "tg": "tgk", // Tajik
        "th": "tha", // Thai
        "ti": "tir", // Tigrinya
        "bo": "bod", // Tibetan
        "tk": "tuk", // Turkmen
        "tl": "tgl", // Tagalog
        "tn": "tsn", // Tswana
        "to": "ton", // Tonga (Tonga Islands)
        "tr": "tur", // Turkish
        "ts": "tso", // Tsonga
        "tt": "tat", // Tatar
        "tw": "twi", // Twi
        "ty": "tah", // Tahitian
        "ug": "uig", // Uighur, Uyghur
        "uk": "ukr", // Ukrainian
        "ur": "urd", // Urdu
        "uz": "uzb", // Uzbek
        "ve": "ven", // Venda
        "vi": "vie", // Vietnamese
        "vo": "vol", // Volapk
        "wa": "wln", // Walloon
        "cy": "cym", // Welsh
        "wo": "wol", // Wolof
        "fy": "fry", // Western Frisian
        "xh": "xho", // Xhosa
        "yi": "yid", // Yiddish
        "yo": "yor", // Yoruba
        "za": "zha", // Zhuang, Chuang
        "zu": "zul", // Zulu
        "?": "?"
    ]
}
