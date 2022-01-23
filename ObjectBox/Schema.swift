//
// Copyright 2020 ObjectBox Ltd. All rights reserved.
//

import Foundation

struct IdUid: Codable, CustomDebugStringConvertible {
    var id: Int32 = 0
    var uid: Int64 = 0

    init(id: Int32 = 0, uid: Int64 = 0) {
        self.id = id
        self.uid = uid
    }

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

    public var debugDescription: String {
        get {
            return "IdUid(\(id):\(uid))"
        }
    }
}

/// The parsed schema model used for the template (stencil) and as input for ID sync
class Schema: CustomDebugStringConvertible {
    var entities: [SchemaEntity] = []
    var entitiesByName: [String: SchemaEntity] = [:]

    var lastEntityId = IdUid()
    var lastRelationId = IdUid()
    var lastIndexId = IdUid()

    public var debugDescription: String {
        get {
            return "Schema {\n\tentities = \(entities)\nlastEntityId = \(lastEntityId)\n\tlastRelationId = \(lastRelationId)\n\tlastIndexId = \(lastIndexId)\n}\n"
        }
    }
}

/// The parsed entity model used for the template (stencil) and as input for ID sync
class SchemaEntity: Hashable, Equatable, CustomDebugStringConvertible {
    var modelId: Int32?
    var modelUid: Int64?
    var className: String = ""
    var dbName: String?
    var properties = Array<SchemaProperty>()
    var indexes = Array<SchemaIndex>()
    var relations = Array<SchemaRelation>()
    var toManyRelations = Array<SchemaToManyRelation>()
    var lastPropertyId: IdUid?
    var isEntitySubclass = false
    var isValueType = false
    var hasStringProperties = false // transient properties are ignored for this.
    var hasByteVectorProperties = false // transient properties are ignored for this.
    var idProperty: SchemaProperty?
    var idCandidates = Array<SchemaProperty>()
    var name: String = ""
    var flags: [EntityFlags] = []
    var flagsStringList: String = ""

    public static func == (lhs: SchemaEntity, rhs: SchemaEntity) -> Bool { lhs.name == rhs.name }

    public var hashValue: Int {
        get {
            var hasher = Hasher()
            self.hash(into: &hasher)
            return hasher.finalize()
        }
    }

    public func hash(into hasher: inout Hasher) {
        name.hash(into: &hasher)
    }

    public var flagsStringListDynamic: String {
        get {
            var flagsList: [String] = []
            if flags.contains(.useNoArgConstructor) { flagsList.append(".useNoArgConstructor") }  // Not used in Swift
            if flags.contains(.syncEnabled) { flagsList.append(".syncEnabled") }
            if flags.contains(.sharedGlobalIds) { flagsList.append(".sharedGlobalIds") }
            if flagsList.count == 0 {
                return ""
            } else if flagsList.count == 1 {
                return flagsList[0]
            } else {
                return "[" + flagsList.joined(separator: ", ") + "]"
            }
        }
    }

    public var debugDescription: String {
        get {
            return "SchemaEntity {\n\t\tmodelId = \(String(describing: modelId))\n\t\tmodelUid = \(String(describing: modelUid))\n\t\tclassName = \(className)\n\t\tdbName = \(String(describing: dbName))\n\t\tproperties = \(properties)\n\t\tindexes = \(indexes)\n\t\trelations = \(relations)\n\t\ttoManyRelations = \(toManyRelations)\n\t\tlastPropertyId = \(String(describing: lastPropertyId))\n\t\tisEntitySubclass = \(isEntitySubclass)\n\t\tisValueType = \(isValueType)\n\t\thasStringProperties = \(hasStringProperties)\n\t\tidProperty = \(String(describing: idProperty))\n\t\tidCandidates = \(idCandidates)\n\t}\n"
        }
    }
}

enum SchemaIndexType {
    case none
    case valueIndex
    case hashIndex
    case hash64Index
}

class SchemaProperty: Hashable, Equatable, CustomDebugStringConvertible {
    var modelId: IdUid?
    var propertyName: String = ""
    var propertyType: String = ""
    var entityName: String = ""
    var unwrappedPropertyType: String = ""
    var dbName: String?
    var modelIndexId: IdUid?
    var indexType: SchemaIndexType = .none
    var backlinkName: String?
    var backlinkType: String?
    var isObjectId: Bool = false
    var isBuiltInType: Bool = false
    var isStringType: Bool = false
    var isByteVectorType: Bool = false
    var isDateNanoType: Bool = false
    var isRelation: Bool = false
    var isToManyRelation: Bool = false
    var toManyRelation: SchemaToManyRelation? = nil
    var isUniqueIndex: Bool = false
    var isUnsignedType: Bool = false
    // TODO rename to propertyType
    var entityType = PropertyType.unknown
    // TODO rename to propertyFlags
    var entityFlags: [PropertyFlags] = []
    var name: String = ""
    var isMutable = true
    var flagsList: String = ""
    var converterName: String = ""
    var conversionPrefix: String = "" // If converting, "converterName.convert(", but if you don't give a converter it's "converterName(rawValue: "
    var conversionSuffix: String = "" // If converting ")". If you don't give a converter and the type is not an optional, this is ") ?? default" (where "default" is given in the annotation).
    var unConversionPrefix: String = "" // If converting, "converterName.convert(", but if you don't give a converter it's ""
    var unConversionSuffix: String = "" // If converting, ")", but if you don't give a converter it's ".rawValue"
    var typeBeforeConversion: String = "" // Type in Swift, whereas propertyType is ObjectBox type. Used with convert annotation.
    var isFirst = false // Helper for generating comma-separated lists in source code.
    var isLast = false // Helper for generating comma-separated lists in source code.

    var propertyTypeQualifiedName: String = "n/a"  // Sourcery cannot access dynamic properties!?

    public func initPropertyType() {
        isDateNanoType = entityType == PropertyType.dateNano
        if(entityType != PropertyType.unknown) {
            propertyTypeQualifiedName = propertyTypeQualifiedNameDyn
        } else {
            // this is some odd workaround for Sourcery not being able to resolve type aliases (go via a type extension)
            propertyTypeQualifiedName = unwrappedPropertyType + ".entityPropertyType"
        }
    }

    public var propertyTypeQualifiedNameDyn: String {
        get {
            "PropertyType.\(entityType)"
        }
    }

    public static func == (lhs: SchemaProperty, rhs: SchemaProperty) -> Bool {
        return lhs.entityName == rhs.entityName && lhs.name == rhs.name && lhs.propertyType == rhs.propertyType
    }

    public var hashValue: Int {
        get {
            var hasher = Hasher()
            self.hash(into: &hasher)
            return hasher.finalize()
        }
    }

    public func hash(into hasher: inout Hasher) {
        name.hash(into: &hasher)
        propertyType.hash(into: &hasher)
        entityName.hash(into: &hasher)
    }

    public var debugDescription: String {
        get {
            var moreData = ""
            if (isUniqueIndex) { moreData += "\n\t\t\tisUniqueIndex = \(isUniqueIndex)" }
            if (isUnsignedType) { moreData += "\n\t\t\tisUnsignedType = \(isUnsignedType)" }
            if (indexType != .none) { moreData += "\n\t\t\tindexType = \(indexType)" }
            if (isByteVectorType) { moreData += "\n\t\t\tisByteVectorType = \(isByteVectorType)" }
            return "SchemaProperty {\n\t\t\tmodelId = \(String(describing: modelId))\n\t\t\tpropertyName = \(propertyName)\n\t\t\tpropertyType = \(propertyType)\n\t\t\tentityName = \(entityName)\n\t\t\tunwrappedPropertyType = \(unwrappedPropertyType)\n\t\t\tdbName = \(String(describing: dbName))\n\t\t\tmodelIndexId = \(String(describing: modelIndexId))\n\t\t\tbacklinkName = \(String(describing: backlinkName))\n\t\t\tbacklinkType = \(String(describing: backlinkType))\n\t\t\tisObjectId = \(isObjectId)\n\t\t\tisBuiltInType = \(isBuiltInType)\n\t\t\tisStringType = \(isStringType)\n\t\t\tisRelation = \(isRelation)\(moreData)\n\t\t}\n"
        }
    }
}

class SchemaRelation: CustomDebugStringConvertible {
    var modelId: IdUid?
    var relationName: String = ""
    var relationType: String = ""
    var relationTargetType: String = ""
    var targetId: IdUid?
    var dbName: String?
    var property: SchemaProperty?
    var isToManyBacklink: Bool = false

    init(name: String, type: String, targetType: String) {
        self.relationName = name
        self.relationType = type
        self.relationTargetType = targetType
    }

    public var debugDescription: String {
        get {
            return "SchemaRelation {\n\t\t\tmodelId = \(String(describing: modelId))\n\t\t\trelationName = \(relationName)\n\t\t\trelationType = \(relationType)\n\t\t\trelationTargetType = \(relationTargetType)\n\t\t\tdbName = \(String(describing: dbName))\n\t\t}\n"
        }
    }
}

class SchemaToManyRelation: SchemaRelation {
    var relationOwnerType: String = ""
    var backlinkProperty: String? // Only set on the actual backlink, NIL for the real standalone relation.
    var backlinkPropertyId: IdUid?

    init(name: String, type: String, targetType: String, ownerType: String) {
        self.relationOwnerType = ownerType
        super.init(name: name, type: type, targetType: targetType)
    }

    override public var debugDescription: String {
        get {
            var extraVars = ""
            if let backlinkPropertyId = backlinkPropertyId {
                extraVars.append("\n\t\tbacklinkPropertyId = \(backlinkPropertyId)")
            }
            return "SchemaToManyRelation {\n\t\t\tmodelId = \(String(describing: modelId))\n\t\t\trelationName = \(relationName)\n\t\t\trelationType = \(relationType)\n\t\t\trelationTargetType = \(relationTargetType)\n\t\t\tdbName = \(String(describing: dbName))\n\t\t\trelationOwnerType = \(relationOwnerType)\n\t\t\tbacklinkProperty = \(String(describing: backlinkProperty))\(extraVars)\n\t\t}\n"
        }
    }
}

class SchemaIndex: CustomDebugStringConvertible {
    var modelId = IdUid()
    var properties = Array<String>()

    public var debugDescription: String {
        get {
            return "SchemaIndex {\n\t\t\tmodelId = \(modelId)\n\t\t\tproperties = \(properties)\n\t\t}\n"
        }
    }
}