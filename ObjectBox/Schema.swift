//
// Copyright 2020-2024 ObjectBox Ltd. All rights reserved.
//

import Foundation
import SourceryRuntime

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
        self.id += 1
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
    var properties = [SchemaProperty]()
    var indexes = [SchemaIndex]()
    var relations = [SchemaRelation]()
    var toManyRelations = [SchemaToManyRelation]()
    var lastPropertyId: IdUid?
    var isEntitySubclass = false
    var isValueType = false
    var hasStringProperties = false // transient properties are ignored for this.
    var hasByteVectorProperties = false // transient properties are ignored for this.
    var idProperty: SchemaProperty?
    var idCandidates = [SchemaProperty]()
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
            if flagsList.isEmpty {
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
    /// Typically the name of the Swift type of the property (like `String`), but for some
    /// properties the name of a special ObjectBox property type (like `FloatArrayPropertyType`).
    var propertySwiftType: String = ""
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
    var isScalarVectorType: Bool = false
    var isDateNanoType: Bool = false
    /// If this is a to-one relation property.
    ///
    /// See also ``isToManyRelation``.
    var isRelation: Bool = false
    /// If this is a to-many relation property.
    ///
    /// See also ``isRelation``.
    var isToManyRelation: Bool = false
    var toManyRelation: SchemaToManyRelation?
    var isUniqueIndex: Bool = false
    var isUnsignedType: Bool = false
    /// The ObjectBox database ``PropertyType``.
    var propertyType = PropertyType.unknown
    /// One or more ``PropertyFlags``.
    var propertyFlags: [PropertyFlags] = []
    /// Optional parameters to configure an HNSW index for this property.
    var hnswParams: SchemaHnswParams?
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
        isDateNanoType = propertyType == PropertyType.dateNano
        if(propertyType != PropertyType.unknown) {
            propertyTypeQualifiedName = propertyTypeQualifiedNameDyn
        } else {
            // this is some odd workaround for Sourcery not being able to resolve type aliases (go via a type extension)
            propertyTypeQualifiedName = unwrappedPropertyType + ".entityPropertyType"
        }
    }

    public var propertyTypeQualifiedNameDyn: String {
        get {
            "PropertyType.\(propertyType)"
        }
    }

    public static func == (lhs: SchemaProperty, rhs: SchemaProperty) -> Bool {
        return lhs.entityName == rhs.entityName && lhs.name == rhs.name && lhs.propertySwiftType == rhs.propertySwiftType
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
        propertySwiftType.hash(into: &hasher)
        entityName.hash(into: &hasher)
    }

    public var debugDescription: String {
        get {
            var moreData = ""
            if (isUniqueIndex) { moreData += "\n\t\t\tisUniqueIndex = \(isUniqueIndex)" }
            if (isUnsignedType) { moreData += "\n\t\t\tisUnsignedType = \(isUnsignedType)" }
            if (indexType != .none) { moreData += "\n\t\t\tindexType = \(indexType)" }
            if (isByteVectorType) { moreData += "\n\t\t\tisByteVectorType = \(isByteVectorType)" }
            if (isScalarVectorType) { moreData += "\n\t\t\tisScalarVectorType = \(isScalarVectorType)" }
            if (hnswParams != nil) { moreData += "\n\t\t\thnswParams = \(hnswParams!)" }
            return "SchemaProperty {\n\t\t\tmodelId = \(String(describing: modelId))\n\t\t\tpropertyName = \(propertyName)\n\t\t\tpropertyType = \(propertyType)\n\t\t\tpropertyFlags = \(propertyFlags)\n\t\t\tpropertySwiftType = \(propertySwiftType)\n\t\t\tentityName = \(entityName)\n\t\t\tunwrappedPropertyType = \(unwrappedPropertyType)\n\t\t\tdbName = \(String(describing: dbName))\n\t\t\tmodelIndexId = \(String(describing: modelIndexId))\n\t\t\tbacklinkName = \(String(describing: backlinkName))\n\t\t\tbacklinkType = \(String(describing: backlinkType))\n\t\t\tisObjectId = \(isObjectId)\n\t\t\tisBuiltInType = \(isBuiltInType)\n\t\t\tisStringType = \(isStringType)\n\t\t\tisRelation = \(isRelation)\(moreData)\n\t\t}\n"
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
    var properties = [String]()

    public var debugDescription: String {
        get {
            return "SchemaIndex {\n\t\t\tmodelId = \(modelId)\n\t\t\tproperties = \(properties)\n\t\t}\n"
        }
    }
}

class SchemaHnswParams: CustomDebugStringConvertible {

    var dimensions: Int
    var neighborsPerNode: UInt32?
    var indexingSearchCount: UInt32?
    /// An array code string of HnswFlags as defined in the ObjectBox Swift library.
    var flags: String?
    /// The name of a HnswDistanceType as defined in the ObjectBox Swift library.
    var distanceType: String?
    var reparationBacklinkProbability: Float?
    var vectorCacheHintSizeKB: Int?

    init(dimensions: Int) {
        self.dimensions = dimensions
    }

    static func fromAnnotation(propertyVar: SourceryVariable, hnswAnnotation: Any?) throws -> SchemaHnswParams? {
        let hnswDict = hnswAnnotation as? [String: Any] // Note: null check as part of dimensions check
        // Example:
        // objectbox:hnswIndex: dimensions=2, neighborsPerNode=30, indexingSearchCount=100, flags="debugLogs,debugLogsDetailed,reparationLimitCandidates,vectorCacheSimdPaddingOff", distanceType="euclidean", reparationBacklinkProbability=0.95, vectorCacheHintSizeKB=2097152
        let dimensions: Int
        if let dimensionsOpt = hnswDict?["dimensions"] as? Int {
            try check({dimensionsOpt > 0}, property: propertyVar, message: "hnswIndex dimensions must be > 0.")
            dimensions = dimensionsOpt
        } else {
            throw ObjectBoxGenerator.Error.BadPropertyAnnotation(property: propertyVar.description, message: "hnswIndex requires at least the parameter dimensions.")
        }
        let hnswParams = SchemaHnswParams(dimensions: dimensions)

        if let neighborsPerNode = hnswDict!["neighborsPerNode"] as? UInt32 {
            try check({neighborsPerNode > 0}, property: propertyVar, message: "hnswIndex neighborsPerNode must be > 0.")
            hnswParams.neighborsPerNode = neighborsPerNode
        }
        if let indexingSearchCount = hnswDict!["indexingSearchCount"] as? UInt32 {
            try check({indexingSearchCount > 0}, property: propertyVar, message: "hnswIndex indexingSearchCount must be > 0.")
            hnswParams.indexingSearchCount = indexingSearchCount
        }
        if let flagsString = hnswDict!["flags"] as? String {
            let flags = flagsString.components(separatedBy: ",")
            var flagsList: [String] = []
            if flags.contains("debugLogs") {
                flagsList.append("HnswFlags.debugLogs")
            }
            if flags.contains("debugLogsDetailed") {
                flagsList.append("HnswFlags.debugLogsDetailed")
            }
            if flags.contains("reparationLimitCandidates") {
                flagsList.append("HnswFlags.reparationLimitCandidates")
            }
            if flags.contains("vectorCacheSimdPaddingOff") {
                flagsList.append("HnswFlags.vectorCacheSimdPaddingOff")
            }
            hnswParams.flags = "[" + flagsList.joined(separator: ", ") + "]"
        }
        if let distanceType = hnswDict!["distanceType"] as? String {
            hnswParams.distanceType = mapDistanceType(distanceType)
        }
        if let repairProb = hnswDict!["reparationBacklinkProbability"] as? Float {
            try check({repairProb > 0 && repairProb <= 1.0}, property: propertyVar, message: "hnswIndex reparationBacklinkProbability must be > 0.0 and <= 1.0.")
            hnswParams.reparationBacklinkProbability = repairProb
        }
        if let cacheHintSize = hnswDict!["vectorCacheHintSizeKB"] as? Int {
            try check({cacheHintSize > 0}, property: propertyVar, message: "hnswIndex vectorCacheHintSizeKB must be > 0.")
            hnswParams.vectorCacheHintSizeKB = cacheHintSize
        }

        return hnswParams
    }

    static func mapDistanceType(_ name: String) -> String? {
        // As defined in ios-framework/CommonSource/Entities/HnswParams.swift
        switch name {
        case "euclidean":
            return "HnswDistanceType.euclidean"
        case "cosine":
            return "HnswDistanceType.cosine"
        case "dotProduct":
            return "HnswDistanceType.dotProduct"
        case "dotProductNonNormalized":
            return "HnswDistanceType.dotProductNonNormalized"
        default:
            return nil
        }
    }

    static func check(_ condition: () -> Bool, property: SourceryVariable, message: String) throws {
        guard condition() else {
            throw ObjectBoxGenerator.Error.BadPropertyAnnotation(property: property.description, message: message)
        }
    }

    public var debugDescription: String {
        get {
            let indent = "\t\t\t\t"
            return "SchemaHnswParams {\n"
            + "\(indent)dimensions = \(dimensions)\n"
            + "\(indent)neighborsPerNode = \(String(describing: neighborsPerNode))\n"
            + "\(indent)indexingSearchCount = \(String(describing: indexingSearchCount))\n"
            + "\(indent)flags = \(String(describing: flags?.description))\n"
            + "\(indent)distanceType = \(String(describing: distanceType))\n"
            + "\(indent)reparationBacklinkProbability = \(String(describing: reparationBacklinkProbability))\n"
            + "\(indent)vectorCacheHintSizeKB = \(String(describing: vectorCacheHintSizeKB))\n"
            + "\t\t\t}"
        }
    }
}
