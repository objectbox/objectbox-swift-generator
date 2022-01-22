//  Copyright © 2018-2019 ObjectBox. All rights reserved.

import Foundation
import PathKit
import Stencil
import StencilSwiftKit
import StencilSwiftKit.Swift
import SourceryRuntime

/// Builds the ObjectBox model in process() and exposes the model via exposeObjects()
enum ObjectBoxGenerator {

    enum Error: Swift.Error {
        case DuplicateIdAnnotation(entity: String, found: String, existing: String)
        case MissingIdOnEntity(entity: String)
        case AmbiguousIdOnEntity(entity: String, properties: [String])
        case MissingBacklinkOnToManyRelation(entity: String, relation: String)
        case convertAnnotationMissingType(name: String, entity: String)
        case convertAnnotationMissingConverterOrDefault(name: String, entity: String)
        case IllegalDictionaryElements(entity: String, message: String)
    }

    static var modelJsonFile: URL?
    static var classVisibility = "internal"
    static var debugDataURL: URL?
    static var buildTracker = BuildTracker()

    static let builtInTypes = ["Bool", "Int8", "Int16", "Int32", "Int64", "Int", "Float", "Double", "Date", "NSDate",
                               "TimeInterval", "NSTimeInterval", "Data", "NSData", "Array<UInt8>", "[UInt8]"]
    static let builtInUnsignedTypes = ["UInt8", "UInt16", "UInt32", "UInt64", "UInt"]
    static let builtInStringTypes = ["String", "NSString"]
    static let builtInByteVectorTypes = ["Data", "NSData", "[UInt8]", "Array<UInt8>"]
    static let typeMappings: [String: PropertyType] = [
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
        "backlink",
        "convert",
        "date-nano",
        "flex",
        "name",
        "id",
        "index",
        "transient",
        "uid",
        "unique",
    ])
    private static let validTypeAnnotationNames = Set([
        "entity",
        "Entity",
        "name",
        "sync",
        "uid"
    ])

    // TODO why static?
    private static var entities = [SchemaEntity]()
    private static var lastEntityId = IdUid()
    private static var lastIndexId = IdUid()
    private static var lastRelationId = IdUid()

    static func printError(_ error: Swift.Error) {
        if let obxError = error as? IdSync.Error {
            switch (obxError) {
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
            switch (filterError) {
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
                    + " of property \(name) of entity \(entity), or put it on a RawRepresentable enum.")
            case .convertAnnotationMissingConverterOrDefault(let name, let entity):
                Log.error("Must specify a converter or default in '// objectbox: convert = { "
                    + "\"dbType\": \"TYPE HERE\", \"default\": \"DEFAULT HERE\" }' annotation of "
                    + "property \(name) of entity \(entity)")
            case .IllegalDictionaryElements(let entity, let message):
                Log.error("Illegal dictionary elements found in entity \(entity): \(message)")
            }
        } else {
            Log.error("\(error)")
            return
        }
    }

    static func isBuiltInTypeOrAlias(_ typeName: TypeName?) -> Bool {
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

    static func isUnsignedTypeOrAlias(_ typeName: TypeName?) -> Bool {
        var isUnsigned: Bool = false
        var currPropType = typeName

        while let currPropTypeReadOnly = currPropType, !isUnsigned {
            isUnsigned = builtInUnsignedTypes.firstIndex(of: currPropTypeReadOnly.name) != nil
            currPropType = currPropTypeReadOnly.actualTypeName
        }

        return isUnsigned
    }

    /* Is this a string ivar that we need to save separately from the fixed-size types? */
    static func isStringTypeOrAlias(_ typeName: TypeName?) -> Bool {
        var isStringType: Bool = false
        var currPropType = typeName

        while let currPropTypeReadOnly = currPropType, !isStringType {
            isStringType = builtInStringTypes.firstIndex(of: currPropTypeReadOnly.unwrappedTypeName) != nil
            currPropType = currPropTypeReadOnly.actualTypeName
        }

        return isStringType
    }

    static func isByteVectorTypeOrAlias(_ typeName: TypeName?) -> Bool {
        var isByteVectorType: Bool = false
        var currPropType = typeName

        while let currPropTypeReadOnly = currPropType, !isByteVectorType {
            isByteVectorType = builtInByteVectorTypes.firstIndex(of: currPropTypeReadOnly.unwrappedTypeName) != nil
            currPropType = currPropTypeReadOnly.actualTypeName
        }

        return isByteVectorType
    }

    static func mapPropertyType(_ propertyVar: SourceryVariable) -> PropertyType {
        let defaultType = mapDefaultPropertyType(propertyVar.typeName)
        if !propertyVar.annotations.isEmpty {
            if propertyVar.annotations.contains(reference: "date-nano") {
                if (defaultType == PropertyType.date) {  // TODO double-check
                    return PropertyType.dateNano
                } else {
                    // TODO log location info and abort
                    Log.error("Annotation \"data-nano\" may only be placed only at types compatible with date")
                }
            }
            if propertyVar.annotations.contains(reference: "flex") {
                if (defaultType == PropertyType.byteVector) {
                    return PropertyType.flex
                } else {
                    Log.error("Annotation \"flex\" may be placed only at bytes (for now)")
                }
            }
        }

        return defaultType
    }

    /// Default mapping just considering the type (not considering annotations)
    static func mapDefaultPropertyType(_ typeName: TypeName?) -> PropertyType {
        var typeCandidateNullable = typeName
        while let typeCandidate = typeCandidateNullable {
            if let entityType = typeMappings[typeCandidate.unwrappedTypeName] {
                return entityType
            } else if typeCandidate.name.hasPrefix("EntityId<") {
                return .long
            } else if typeCandidate.name.hasPrefix("Id") {  // TODO check full type name!
                return .long
            } else if typeCandidate.name.hasPrefix("ToOne<") {
                return .relation
            }
            print("Mapping not found: ", typeName as Any, typeCandidate, typeCandidate.name,
                    typeCandidate.actualTypeName as Any)
            typeCandidateNullable = typeCandidate.actualTypeName  // TODO does not seem to work; update Sourcery
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

    static func processProperty(_ propertyVar: SourceryVariable, in propertyType: Type,
                                into schemaProperties: inout [SchemaProperty],
                                entity schemaEntity: SchemaEntity, schema schemaData: Schema,
                                enums: [String: TypeName]) throws {
        let fullTypeName = propertyVar.typeName.name;
        var tmRelation: SchemaToManyRelation? = nil
        if fullTypeName.hasPrefix("ToMany<") && fullTypeName.hasSuffix(">") {
            let templateTypesString = fullTypeName.drop(first: "ToMany<".count, last: 1)
            let templateTypes = templateTypesString.split(separator: ",")
            let destinationType = templateTypes[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let myType = propertyType.name

            let relation = SchemaToManyRelation(name: propertyVar.name, type: fullTypeName, targetType: String(destinationType), ownerType: String(myType))
            if let propertyUid = propertyVar.annotations["uid"] as? Int64 {
                relation.modelId = IdUid(id: 0, uid: propertyUid)
            }
            if let backlinkProperty = propertyVar.annotations["backlink"] as? String {
                relation.backlinkProperty = backlinkProperty
            }
            tmRelation = relation
            schemaEntity.toManyRelations.append(relation)
        }

        let schemaProperty = SchemaProperty()
        schemaProperty.entityName = propertyType.localName
        schemaProperty.propertyName = propertyVar.name
        schemaProperty.isMutable = propertyVar.isMutable
        schemaProperty.propertyType = fullTypeName
        schemaProperty.entityType = mapPropertyType(propertyVar)
        schemaProperty.isBuiltInType = isBuiltInTypeOrAlias(propertyVar.typeName)
        schemaProperty.isUnsignedType = isUnsignedTypeOrAlias(propertyVar.typeName)
        schemaProperty.isStringType = isStringTypeOrAlias(propertyVar.typeName)
        schemaProperty.isByteVectorType = isByteVectorTypeOrAlias(propertyVar.typeName)
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
        schemaProperty.unwrappedPropertyType = propertyVar.unwrappedTypeName
        schemaProperty.dbName = propertyVar.annotations["name"] as? String
        if let dbNameIsEmpty = schemaProperty.dbName?.isEmpty, dbNameIsEmpty { schemaProperty.dbName = nil }
        schemaProperty.name = schemaProperty.dbName ?? schemaProperty.propertyName
        if let propertyUidObject = propertyVar.annotations["uid"], let propertyUid = (propertyUidObject as? NSNumber)?.int64Value {
            var propId = IdUid()
            propId.uid = propertyUid
            schemaProperty.modelId = propId
        }

        if let convertDict = extractConvertAnnotation(propertyVar.annotations["convert"]) {
            let dbType: String
            if let firstDbType = convertDict["dbType"] {
                dbType = firstDbType
            } else if let secondDbType = enums[schemaProperty.unwrappedPropertyType]?.name {
                dbType = secondDbType
            } else {
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
        schemaProperty.initPropertyTypeQualifiedName()  // depends on PropertyType and unwrappedPropertyType

        if propertyVar.annotations["index"] as? Int64 == 1 {
            schemaProperty.indexType = schemaProperty.isStringType ? .hashIndex : .valueIndex
        } else if let indexType = propertyVar.annotations["index"] as? String {
            if (indexType == "hash") {
                schemaProperty.indexType = .hashIndex
            } else if (indexType == "hash64") {
                schemaProperty.indexType = .hash64Index
            } else if (indexType == "value") {
                schemaProperty.indexType = .valueIndex
            }
        }
        if propertyVar.annotations["unique"] as? Int64 == 1 {
            schemaProperty.isUniqueIndex = true
            if (schemaProperty.indexType == .none) {
                schemaProperty.indexType = schemaProperty.isStringType ? .hashIndex : .valueIndex
            }
        }

        if let objectIdAnnotationValue = propertyVar.annotations["id"] {
            if let existingIdProperty = schemaEntity.idProperty {
                throw Error.DuplicateIdAnnotation(entity: schemaEntity.className, found: propertyVar.name,
                                                  existing: existingIdProperty.propertyName)
            }
            schemaProperty.isObjectId = true
            schemaEntity.idProperty = schemaProperty
            if let objectAnnotationDict = objectIdAnnotationValue as? NSDictionary {
                if let assignableBool = objectAnnotationDict["assignable"] as? Bool, assignableBool == true {
                    schemaProperty.entityFlags.append(.idSelfAssignable)
                }
            }
        } else {
            if fullTypeName == "Id" {
                schemaEntity.idCandidates.append(schemaProperty)
            } else if fullTypeName.hasPrefix("EntityId<") && fullTypeName.hasSuffix(">") {
                let templateTypesString = fullTypeName.drop(first: "EntityId<".count, last: 1)
                let templateTypes = templateTypesString.split(separator: ",")
                let idType = templateTypes[0]
                if idType == propertyType.localName {
                    schemaEntity.idCandidates.append(schemaProperty)
                }
            }
        }

        if schemaProperty.isObjectId {
            schemaProperty.entityFlags.append(.id)
        }
        if !schemaProperty.isObjectId && schemaProperty.isUnsignedType {
            schemaProperty.entityFlags.append(.unsigned)
        }
        if schemaProperty.isUniqueIndex {
            schemaProperty.entityFlags.append(.unique)
        }
        if schemaProperty.indexType == .hashIndex {
            schemaProperty.entityFlags.append(.indexHash)
        } else if schemaProperty.indexType == .hash64Index {
            schemaProperty.entityFlags.append(.indexHash64)
        }
        if schemaProperty.indexType != .none {
            schemaProperty.entityFlags.append(.indexed)
        }
        if schemaProperty.isRelation && fullTypeName.hasPrefix("ToOne<") && fullTypeName.hasSuffix(">") {
            let templateTypesString = fullTypeName.drop(first: "ToOne<".count, last: 1)
            let templateTypes = templateTypesString.split(separator: ",")
            let destinationType = templateTypes[0].trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let relation = SchemaRelation(name: schemaProperty.propertyName, type: schemaProperty.propertyType,
                                                 targetType: destinationType)
            relation.property = schemaProperty
            schemaEntity.relations.append(relation)
            if let backlink = propertyVar.annotations["backlink"] as? String {
                print("warning: Found an // objectbox: backlink annotation on ToOne relation "
                    + "\"\(schemaProperty.propertyName)\". Did you mean to put "
                    + "// objectbox: backlink = \"\(propertyVar.name)\"  on the ToMany relation \"\(backlink)\" "
                    + "in \"\(destinationType)\"?")
            }
        }

        if tmRelation != nil {
            tmRelation?.property = schemaProperty
        }

        schemaProperties.append(schemaProperty)
    }

    static func processEntityType(_ entityType: Type, entityBased isEntityBased: Bool, enums: [String: TypeName], into schemaData: Schema) throws {
        let schemaEntity = SchemaEntity()
        schemaEntity.className = entityType.localName
        schemaEntity.isValueType = entityType.kind == "struct"
        schemaEntity.modelUid = entityType.annotations["uid"] as? Int64
        schemaEntity.dbName = entityType.annotations["name"] as? String
        let syncAnnotation = entityType.annotations["sync"]
        if syncAnnotation != nil {
            schemaEntity.flags.append(.syncEnabled)

            if let syncDict = syncAnnotation as? NSDictionary {
                // These are critical: do strict checks to ensure nothing goes bad because of an typo
                for (key, value) in syncDict {
                    guard let keyString = key as? String else {
                        throw Error.IllegalDictionaryElements(entity: schemaEntity.className,
                                message: "the sync annotation contains a non-string key")
                    }
                    if keyString == "sharedGlobalIds" {
                        guard let valueBool = value as? Bool else {
                            throw Error.IllegalDictionaryElements(entity: schemaEntity.className,
                                    message: "the sync annotation has a non-boolean value for key: \(keyString)")
                        }
                        if valueBool {
                            schemaEntity.flags.append(.sharedGlobalIds)
                        }
                    } else {
                        throw Error.IllegalDictionaryElements(entity: schemaEntity.className,
                                message: "the sync annotation contains an unknown key: \(keyString)")
                    }
                }
            } // else TODO verify syncAnnotation is expected
        }

        // Not sure why, but Sourcery has trouble with "computed" properties,
        // help it by "materializing" to a plain String property
        schemaEntity.flagsStringList = schemaEntity.flagsStringListDynamic

        if let dbNameIsEmpty = schemaEntity.dbName?.isEmpty, dbNameIsEmpty { schemaEntity.dbName = nil }
        schemaEntity.name = schemaEntity.dbName ?? schemaEntity.className
        schemaEntity.isEntitySubclass = isEntityBased

        var schemaProperties = Array<SchemaProperty>()
        try entityType.variables.forEach { propertyVar in
            warnIfAnnotations(otherThan: ObjectBoxGenerator.validPropertyAnnotationNames,
                              in: Set(propertyVar.annotations.keys), of: propertyVar.name)
            guard !propertyVar.annotations.contains(reference: "transient") else { return } // Exits only this iteration of the foreach block
            guard !propertyVar.isStatic else { return } // Exits only this iteration of the foreach block
            guard !propertyVar.isComputed else { return } // Exits only this iteration of the foreach block

            try processProperty(propertyVar, in: entityType, into: &schemaProperties, entity: schemaEntity, schema: schemaData, enums: enums)
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
            schemaEntity.idProperty?.entityFlags.append(.id)
            // No other binding marks IDs as unsigned, so don't break compatibility.
            schemaEntity.idProperty?.entityFlags.removeAll(where: { $0 == .unsigned })
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
            print("error: \(name) has unknown annotations \(unknownAnnotations.joined(separator: ",")).")
        }
    }

    static func startup(statistics: Bool, verbose: Bool) throws {
        buildTracker.statistics = statistics
        buildTracker.verbose = verbose
        try buildTracker.startup()
    }

    /* Process the parsed syntax tree, possibly annotating or otherwise
        extending it. */
    // Called by Sourcery class, which is called by main
    static func process(parsingResult result: inout Sourcery.ParsingResult) throws {
        let schemaData = Schema()

        var enums = [String: TypeName]()
        result.types.all.forEach { currType in
            if let enumType = currType as? Enum, let rawTypeName = enumType.rawTypeName {
                enums[currType.name] = rawTypeName
            }
        }

        try result.types.all.forEach { entityType in
            warnIfAnnotations(otherThan: ObjectBoxGenerator.validTypeAnnotationNames,
                              in: Set(entityType.annotations.keys), of: entityType.name)
            let isEntityBased = entityType.inheritedTypes.contains("Entity")
            // The annotation should be lowercase "entity", but given the protocol is uppercase, we allow that too,
            // as a convenience for users who use both and get their case mixed up:
            if isEntityBased || entityType.annotations["entity"] != nil || entityType.annotations["Entity"] != nil {
                try processEntityType(entityType, entityBased: isEntityBased, enums: enums, into: schemaData)
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
    // Called by StencilTemplate to expose our ObjectBox model to templates
    static func exposeObjects(to objectsDictionary: inout [String: Any]) {
        objectsDictionary["entities"] = ObjectBoxGenerator.entities
        objectsDictionary["visibility"] = ObjectBoxGenerator.classVisibility;
        objectsDictionary["lastEntityId"] = ObjectBoxGenerator.lastEntityId
        objectsDictionary["lastIndexId"] = ObjectBoxGenerator.lastIndexId
        objectsDictionary["lastRelationId"] = ObjectBoxGenerator.lastRelationId
    }
}
