//
//  IdSyncModel.swift
//  Sourcery
//
//  Created by Uli Kusterer on 03.12.18.
//  Copyright © 2018 ObjectBox. All rights reserved.
//

import Foundation


enum IdSync {
    
    /* Model classes that get populated from our model.json file using Codable protocol. */
    struct IdUid: Codable, CustomDebugStringConvertible {
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
        
        public var debugDescription: String {
            get {
                return "IdUid(\(id):\(uid))"
            }
        }
    }
    
    // Todo: Unify ID/Id spelling. Swift usually does ID.
    
    enum Error: Swift.Error {
        case IncompatibleVersion(found: Int64, expected: Int64)
        case DuplicateEntityName(String)
        case DuplicateEntityID(name: String, id: Int32)
        case MissingLastEntityID
        case LastEntityIdUIDMismatch(name: String, id: Int32, found: Int64, expected: Int64)
        case EntityIdGreaterThanLast(name: String, found: Int32, last: Int32)
        case MissingLastPropertyID(entity: String)
        case DuplicatePropertyID(entity: String, name: String, id: Int32)
        case LastPropertyIdUIDMismatch(entity: String, name: String, id: Int32, found: Int64, expected: Int64)
        case PropertyIdGreaterThanLast(entity: String, name: String, found: Int32, last: Int32)
        case DuplicateUID(Int64)
        case UIDOutOfRange(Int64)
        case OutOfUIDs
        case SyncMayOnlyBeCalledOnce
        case NonUniqueModelUID(uid: Int64, entity: String)
        case NoSuchEntity(Int64)
        case PrintUid(entity: String, found: Int64, unique: Int64)
        case UIDTagNeedsValue(entity: String)
        case CandidateUIDNotInPool(Int64)
        case NonUniqueModelPropertyUID(uid: Int64, entity: String, property: String)
        case NoSuchProperty(entity: String, uid: Int64)
        case MultiplePropertiesForUID(uids: [Int64], names: [String])
        case PrintPropertyUid(entity: String, property: String, found: Int64, unique: Int64)
        case PropertyUIDTagNeedsValue(entity: String, property: String)
        case PropertyCollision(entity: String, new: String, old: String)
        case NonUniqueModelRelationUID(uid: Int64, entity: String, relation: String)
        case NoSuchRelation(entity: String, uid: Int64)
        case MultipleRelationsForUID(uids: [Int64], names: [String])
        case PrintRelationUid(entity: String, relation: String, found: Int64, unique: Int64)
        case RelationUIDTagNeedsValue(entity: String, relation: String)
        case DuplicatePropertyName(entity: String, property: String)
    }
    
    class Property: Codable {
        var id = IdUid()
        var name = ""
        var indexId: IdUid?
        var type: UInt?
        var flags: UInt?
        var relationTarget: String? // dbName or if not explicitly specified, name of Swift class
        var relationTargetUnresolved: String? // Name of Swift class

        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case indexId
            case type
            case flags
            case relationTarget
        }
        
        init(name: String, id: IdUid, indexId: IdUid?, relationTargetUnresolved: String?, type: UInt, flags: UInt) {
            self.id = id
            self.name = name
            self.indexId = indexId
            self.relationTargetUnresolved = relationTargetUnresolved
            self.type = type != 0 ? type : nil
            self.flags = flags != 0 ? flags : nil
        }
        
        func contains(uid: Int64) -> Bool {
            if id.uid == uid { return true }
            if let indexId = indexId, indexId.uid == uid { return true }
            
            return false
        }
    }
    
    class Relation: Codable {
        var id = IdUid()
        var name = ""
        
        private enum CodingKeys: String, CodingKey {
            case id
            case name
        }
        
        init(name: String, id: IdUid) {
            self.name = name
            self.id = id
        }
        
        func contains(uid: Int64) -> Bool {
            if id.uid == uid { return true }
            
            return false
        }
    }
    
    class Entity: Codable, Hashable, Equatable {
        var id = IdUid()
        var name = ""
        var lastPropertyId: IdUid?
        var properties: Array<Property>?
        var relations: Array<Relation>?
        var isEntitySubclass = false
        
        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case lastPropertyId
            case properties
            case relations
        }
        
        init(name: String, id: IdUid, properties: [Property], relations: [Relation], lastPropertyId: IdUid, isEntitySubclass: Bool) {
            self.name = name
            self.id = id
            self.properties = properties
            self.relations = relations
            self.lastPropertyId = lastPropertyId
            self.isEntitySubclass = isEntitySubclass
        }
        
        func contains(uid: Int64) -> Bool {
            if id.uid == uid { return true }
            if lastPropertyId?.uid == uid { return true }
            
            if let properties = properties {
                for currProperty in properties {
                    if currProperty.contains(uid: uid) { return true }
                }
            }

            if let relations = relations {
                for currRelation in relations {
                    if currRelation.contains(uid: uid) { return true }
                }
            }

            return false
        }

        public static func == (lhs: Entity, rhs: Entity) -> Bool {
            return lhs.name == rhs.name
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
        }
    }
    
    // Our file format that gets serialized to JSON and back:
    class IdSyncModel: Codable {
        
        static let modelVersion: Int64 = 5 // !! When upgrading always check modelVersionParserMinimum !!
        static let modelVersionParserMinimum: Int64 = 5
        
        /** "Comments" in the JSON file */
        var _note1: String? = "KEEP THIS FILE! Check it into a version control system (VCS) like git."
        var _note2: String? = "ObjectBox manages crucial IDs for your object model. See docs for details."
        var _note3: String? = "If you have VCS merge conflicts, you must resolve them according to ObjectBox docs."
        
        var version: Int64 = 1
        var modelVersion: Int64 = IdSyncModel.modelVersion
        /** Specify backward compatibility with older parsers.*/
        var modelVersionParserMinimum: Int64 = IdSyncModel.modelVersionParserMinimum
        var lastEntityId: IdUid?
        var lastIndexId: IdUid?
        var lastRelationId: IdUid?
        // TODO use this once we support sequences
        var lastSequenceId: IdUid?
        
        var entities: [Entity]? = []
        
        /**
         * Previously allocated UIDs (e.g. via "@Uid" without value) to use to provide UIDs for new entities,
         * properties, or relations.
         */
        var newUidPool: Array<Int64>?
        
        /** Previously used UIDs, which are now deleted. Archived to ensure no collisions. */
        var retiredEntityUids: Array<Int64>?
        
        /** Previously used UIDs, which are now deleted. Archived to ensure no collisions. */
        var retiredPropertyUids: Array<Int64>?
        
        /** Previously used UIDs, which are now deleted. Archived to ensure no collisions. */
        var retiredIndexUids: Array<Int64>?
        
        /** Previously used UIDs, which are now deleted. Archived to ensure no collisions. */
        var retiredRelationUids: Array<Int64>?
        
        private enum CodingKeys: String, CodingKey {
            case _note1
            case _note2
            case _note3
            case version
            case modelVersion
            case modelVersionParserMinimum
            case lastEntityId
            case lastIndexId
            case lastRelationId
            case lastSequenceId
            case entities
            case newUidPool
            case retiredEntityUids
            case retiredPropertyUids
            case retiredIndexUids
            case retiredRelationUids
        }
        
        init(lastEntityId: IdUid? = nil, lastIndexId: IdUid? = nil, lastRelationId: IdUid? = nil, lastSequenceId: IdUid? = nil, entities: Array<Entity>? = nil, retiredEntityUids: Array<Int64>? = nil, retiredPropertyUids: Array<Int64>? = nil, retiredIndexUids: Array<Int64>? = nil, retiredRelationUids: Array<Int64>? = nil) {
            self.lastEntityId = lastEntityId
            self.lastIndexId = lastIndexId
            self.lastRelationId = lastRelationId
            self.lastSequenceId = lastSequenceId
            self.entities = entities
            self.retiredEntityUids = retiredEntityUids
            self.retiredPropertyUids = retiredPropertyUids
            self.retiredIndexUids = retiredIndexUids
            self.retiredRelationUids = retiredRelationUids
        }
        
        func contains(uid: Int64) -> Bool {
            if let lastEntityId = lastEntityId, lastEntityId.uid == uid {
                return true
            }
            if let lastIndexId = lastIndexId, lastIndexId.uid == uid {
                return true
            }
            if let lastRelationId = lastRelationId, lastRelationId.uid == uid {
                return true
            }

            if let retiredEntityUids = retiredEntityUids {
                if retiredEntityUids.contains(uid) { return true }
            }
            if let retiredPropertyUids = retiredPropertyUids {
                if retiredPropertyUids.contains(uid) { return true }
            }
            if let retiredIndexUids = retiredIndexUids {
                if retiredIndexUids.contains(uid) { return true }
            }
            if let retiredRelationUids = retiredRelationUids {
                if retiredRelationUids.contains(uid) { return true }
            }
            if let entities = entities {
                for currEntity in entities {
                    if currEntity.contains(uid: uid) { return true }
                }
            }

            return false
        }
    }
    
    class UidHelper {
        weak var model: IdSyncModel? = nil
        var existingUids = Set<Int64>()
        
        static var randomNumberStart: Int64 = 0
        
        func addExistingIds(_ newIds: [Int64]) throws {
            try newIds.forEach { try addExistingId($0) }
        }
        
        func addExistingId(_ inID: Int64) throws {
            try verify(inID)
            guard !existingUids.contains(inID) else {
                throw Error.DuplicateUID(inID)
            }
            existingUids.insert(inID)
        }
        
        static func random_int64() -> Int64 {
            if UidHelper.randomNumberStart > 0 {
                UidHelper.randomNumberStart += 999
                if UidHelper.randomNumberStart == 0 {
                    UidHelper.randomNumberStart = 1
                }
                return UidHelper.randomNumberStart
            } else {
                return Int64.random(in: 1 ... Int64.max)
            }
        }
        
        func create() throws -> Int64 {
            var newId: Int64
            for _ in 1 ... 1000 {
                newId = UidHelper.random_int64() & 0x7FFFFFFFFFFFFF00
                if !existingUids.contains(newId) {
                    existingUids.insert(newId)
                    return newId
                }
            }
            
            throw Error.OutOfUIDs
        }
        
        func verify(_ inID: Int64) throws  {
            guard inID >= 0 else {
                throw Error.UIDOutOfRange(inID)
            }
            let randomPart = inID & 0x7FFFFFFFFFFFFF00
            guard randomPart != 0 else {
                throw Error.UIDOutOfRange(inID)
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
        
        public static func == (lhs: SchemaEntity, rhs: SchemaEntity) -> Bool {
            return lhs.name == rhs.name
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
        var isRelation: Bool = false
        var isToManyRelation: Bool = false
        var toManyRelation: SchemaToManyRelation? = nil
        var isUniqueIndex: Bool = false
        var isUnsignedType: Bool = false
        var entityType = EntityPropertyType.unknown
        var entityFlags: EntityPropertyFlag = []
        var name: String = ""
        var flagsList: String = ""
        var isFirst = false // Helper for generating comma-separated lists in source code.
        var isLast = false // Helper for generating comma-separated lists in source code.

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
        var dbName: String?

        init(name: String, type: String, targetType: String)
        {
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
        var backlinkProperty: String?
        
        init(name: String, type: String, targetType: String, ownerType: String)
        {
            self.relationOwnerType = ownerType
            super.init(name: name, type: type, targetType: targetType)
        }
        
        override public var debugDescription: String {
            get {
                return "SchemaToManyRelation {\n\t\t\tmodelId = \(String(describing: modelId))\n\t\t\trelationName = \(relationName)\n\t\t\trelationType = \(relationType)\n\t\t\trelationTargetType = \(relationTargetType)\n\t\t\tdbName = \(String(describing: dbName))\n\t\t\trelationOwnerType = \(relationOwnerType)\n\t\t\tbacklinkProperty = \(String(describing: backlinkProperty))\n\t\t}\n"
            }
        }
    }
    
    // Main class used for performing the sync between our JSON file and the AST:
    class IdSync {
        let modelRead: IdSyncModel
        
        var lastEntityId: IdUid
        var lastRelationId: IdUid
        var lastIndexId: IdUid
        var lastSequenceId: IdUid
        
        var retiredEntityUids: [Int64]
        var retiredPropertyUids: [Int64]
        var retiredIndexUids: [Int64]
        var retiredRelationUids: [Int64]
        
        var newUidPool = Set<Int64>()
        
        var jsonFile: URL
        
        let uidHelper = UidHelper()
        
        private var entitiesReadByUid = Dictionary<Int64, Entity>()
        private var entitiesReadByName = Dictionary<String, Entity>()
        private var parsedUids = Set<Int64>()

        private var entitiesBySchemaEntity = Dictionary<SchemaEntity, Entity>()
        private var propertiesBySchemaProperty = Dictionary<SchemaProperty, Property>()

        init(jsonFile: URL) throws {
            self.jsonFile = jsonFile
            
            var model: IdSyncModel?
            if let data = try? Data(contentsOf: jsonFile) {
                let decoder = JSONDecoder()
                model = try? decoder.decode(IdSyncModel.self, from: data)
            }
            
            modelRead = model ?? IdSyncModel()
            
            if modelRead.modelVersion < IdSyncModel.modelVersionParserMinimum {
                throw Error.IncompatibleVersion(found: modelRead.modelVersion, expected: IdSyncModel.modelVersionParserMinimum)
            } else if modelRead.modelVersion < IdSyncModel.modelVersion {
                throw Error.IncompatibleVersion(found: modelRead.modelVersion, expected: IdSyncModel.modelVersionParserMinimum)
            }
            
            lastEntityId = modelRead.lastEntityId ?? IdUid()
            lastRelationId = modelRead.lastRelationId ?? IdUid()
            lastIndexId = modelRead.lastIndexId ?? IdUid()
            lastSequenceId = modelRead.lastSequenceId ?? IdUid()
            
            retiredEntityUids = modelRead.retiredEntityUids ?? []
            retiredPropertyUids = modelRead.retiredPropertyUids ?? []
            retiredIndexUids = modelRead.retiredIndexUids ?? []
            retiredRelationUids = modelRead.retiredRelationUids ?? []

            newUidPool.formUnion(modelRead.newUidPool ?? [])
            
            try uidHelper.addExistingIds( modelRead.retiredEntityUids ?? [] )
            try uidHelper.addExistingIds( modelRead.retiredPropertyUids ?? [] )
            try uidHelper.addExistingIds( modelRead.retiredIndexUids ?? [] )
            try uidHelper.addExistingIds( modelRead.retiredRelationUids ?? [] )

            try validateIds(modelRead)
            
            uidHelper.model = modelRead
            
            try modelRead.entities?.forEach { entity in
                try uidHelper.addExistingId(entity.id.uid)
                try entity.properties?.forEach { try uidHelper.addExistingId($0.id.uid) }
                entitiesReadByUid[entity.id.uid] = entity
                let loweredEntityName = entity.name.lowercased()
                guard !entitiesReadByName.contains(reference: loweredEntityName) else {
                    throw Error.DuplicateEntityName(entity.name)
                }
                entitiesReadByName[loweredEntityName] = entity
            }
        }
        
        func validateIds(_ model: IdSyncModel) throws {
            var entityIds = Set<Int32>()
            try model.entities?.forEach { entity in
                guard !entityIds.contains(entity.id.id) else {
                    throw Error.DuplicateEntityID(name: entity.name, id: entity.id.id)
                }
                entityIds.insert(entity.id.id)
                
                guard let lastEntityId = model.lastEntityId else {
                    throw Error.MissingLastEntityID
                }
                
                if entity.id.id == lastEntityId.id {
                    if entity.id.uid != lastEntityId.uid {
                        throw Error.LastEntityIdUIDMismatch(name: entity.name, id: entity.id.id, found: entity.id.uid, expected: lastEntityId.uid)
                    }
                } else if entity.id.id > lastEntityId.id {
                    throw Error.EntityIdGreaterThanLast(name: entity.name, found:entity.id.id, last: lastEntityId.id)
                }
                
                var propertyIds = Set<Int32>()
                try entity.properties?.forEach { property in
                    guard propertyIds.insert(property.id.id).inserted else {
                        throw Error.DuplicatePropertyID(entity: entity.name, name: property.name, id: property.id.id)
                    }
                    
                    guard let lastPropertyId = entity.lastPropertyId else {
                        throw Error.MissingLastPropertyID(entity: entity.name)
                    }
                    
                    if property.id.id == lastPropertyId.id {
                        if property.id.uid != lastPropertyId.uid {
                            throw Error.LastPropertyIdUIDMismatch(entity: entity.name, name: property.name, id: property.id.id, found: property.id.uid, expected: lastPropertyId.uid)
                        }
                    } else if property.id.id > lastPropertyId.id {
                        throw Error.PropertyIdGreaterThanLast(entity: entity.name, name: property.name, found: property.id.id, last: lastPropertyId.id)
                    }
                }
            }
        }
        
        func updateRetiredUids(_ entities: [Entity]) {
            var oldEntityUids = Set<Int64>(entitiesReadByUid.keys)
            oldEntityUids.subtract(entities.map { $0.id.uid })
            retiredEntityUids.append(contentsOf: oldEntityUids)
            
            var oldPropertyUids = collectPropertyUids(Array<Entity>(entitiesReadByUid.values))
            let newPropertyUids = collectPropertyUids(entities)
            
            oldPropertyUids.propertyUids.subtract(newPropertyUids.propertyUids)
            retiredPropertyUids.append(contentsOf: oldPropertyUids.propertyUids)

            oldPropertyUids.indexUids.subtract(newPropertyUids.indexUids)
            retiredIndexUids.append(contentsOf: oldPropertyUids.indexUids)

            oldPropertyUids.relationUids.subtract(newPropertyUids.relationUids)
            retiredRelationUids.append(contentsOf: oldPropertyUids.relationUids)
        }
        
        func collectPropertyUids(_ entities: Array<Entity>) -> (propertyUids: Set<Int64>, indexUids: Set<Int64>, relationUids: Set<Int64>) {
            var propertyUids = Set<Int64>()
            var indexUids = Set<Int64>()
            var relationUids = Set<Int64>()
            
            entities.forEach { currEntity in
                currEntity.properties?.forEach { currProperty in
                    propertyUids.insert(currProperty.id.uid)
                    if let indexId = currProperty.indexId {
                        indexUids.insert(indexId.uid)
                    }
                }
                currEntity.relations?.forEach { relationUids.insert($0.id.uid) }
            }
            
            return (propertyUids: propertyUids, indexUids: indexUids, relationUids: relationUids)
        }
        
        func writeModel(_ entities: [Entity]) throws {
            let model = IdSyncModel(lastEntityId: lastEntityId, lastIndexId: lastIndexId, lastRelationId: lastRelationId, lastSequenceId: lastSequenceId, entities: entities, retiredEntityUids: retiredEntityUids, retiredPropertyUids: retiredPropertyUids, retiredIndexUids: retiredIndexUids, retiredRelationUids: retiredRelationUids)
            try writeModel(model)
            try validateIds(model)
        }
        
        func writeModel(_ model: IdSyncModel) throws {
            try validateBeforeWrite(model)
            model.modelVersion = IdSyncModel.modelVersion
            model.modelVersionParserMinimum = IdSyncModel.modelVersionParserMinimum
            
//            let encoder = JSONEncoder()
//            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
//            let jsonData = try encoder.encode(model)
            let encoder = PrettyJSON()
            let jsonData = encoder.encode(model)
            if FileManager.default.fileExists(atPath: jsonFile.path) {
                let backupData = try? Data(contentsOf: jsonFile)
                if backupData == jsonData {
                    print("note: ObjectBox ID Model file unchanged: \(FileManager.default.displayName(atPath: jsonFile.path)).")
                    return
                } else {
                    let backupFile = jsonFile.appendingPathExtension("bak")
                    print("note: ObjectBox ID Model file changed: \(FileManager.default.displayName(atPath: jsonFile.path)), creating backup file (.bak).")
                    try backupData?.write(to: backupFile)
                }
            } else {
                print("note: ObjectBox ID Model file created: \(FileManager.default.displayName(atPath: jsonFile.path)).")
            }
            try jsonData.write(to: jsonFile)
        }
        
        func validateBeforeWrite(_ model: IdSyncModel) throws {
            var entityNames = Set<String>()
            try model.entities?.forEach { currEntity in
                if !entityNames.insert(currEntity.name.lowercased()).inserted {
                    throw Error.DuplicateEntityName(currEntity.name)
                }
                
                var propertyNames = Set<String>()
                try currEntity.properties?.forEach { currProperty in
                    if !propertyNames.insert(currProperty.name.lowercased()).inserted {
                        throw Error.DuplicatePropertyName(entity: currEntity.name, property:currProperty.name)
                    }
                }
           }
        }
        
        func sync(schema: Schema) throws {
            guard entitiesBySchemaEntity.isEmpty && propertiesBySchemaProperty.isEmpty else {
                throw Error.SyncMayOnlyBeCalledOnce
            }
            
            let entities = (try schema.entities.map { try syncEntity($0) }).sorted { $0.id.id < $1.id.id }
            try updateRelatedTargetsOfProperties(entities: entities, schema: schema)
            updateRetiredUids(entities)
            try writeModel(entities)
            
            schema.lastEntityId = lastEntityId
            schema.lastIndexId = lastIndexId
            schema.lastRelationId = lastRelationId
        }
        
        func updateRelatedTargetsOfProperties(entities: [Entity], schema: Schema) throws {
            try entities.forEach { entity in
                if let properties = entity.properties {
                    try properties.forEach { property in
                        try updateRelatedTargetsOfProperty(property: property, schema: schema)
                    }
                }
            }
        }

        func updateRelatedTargetsOfProperty(property: Property, schema: Schema) throws {
            if let relationTargetUnresolved = property.relationTargetUnresolved, let entity = schema.entitiesByName[relationTargetUnresolved] {
                property.relationTarget = entity.dbName ?? entity.name
            }
        }

        
        func findEntity(name: String, uid: Int64?) throws -> Entity? {
            if let uid = uid, uid != 0, uid != 1 {
                if let foundEntity = entitiesReadByUid[uid] {
                    return foundEntity
                } else if newUidPool.contains(uid) {
                    return nil
                } else {
                    throw Error.NoSuchEntity(uid)
                }
            } else {
                return entitiesReadByName[name.lowercased()]
            }
        }
        
        func findProperty(entity: Entity, name: String, uid: Int64?) throws -> Property? {
            if let uid = uid, uid != 0, uid != 1 {
                let filtered = entity.properties?.filter { $0.id.uid == uid } ?? []
                if filtered.isEmpty {
                    if newUidPool.contains(uid) {
                        return nil
                    }
                    throw Error.NoSuchProperty(entity: entity.name, uid: uid)
                }
                if filtered.count != 1 {
                    throw Error.MultiplePropertiesForUID(uids: [uid], names: filtered.map { $0.name })
                }
                return filtered.first
            } else {
                let nameLowercased = name.lowercased()
                let filtered = entity.properties?.filter { $0.name.lowercased() == nameLowercased } ?? []
                if filtered.count > 1 {
                    throw Error.MultiplePropertiesForUID(uids: filtered.map { $0.id.uid }, names: [name])
                }
                return filtered.first
            }
        }
        
        func findRelation(entity: Entity, name: String, uid: Int64?) throws -> Relation? {
            guard entity.relations != nil else { return nil }
            
            if let uid = uid, uid != 0, uid != 1 {
                let filtered = entity.relations?.filter { $0.id.uid == uid } ?? []
                if filtered.isEmpty {
                    if newUidPool.contains(uid) {
                        return nil
                    }
                    throw Error.NoSuchRelation(entity: entity.name, uid: uid)
                }
                if filtered.count != 1 {
                    throw Error.MultipleRelationsForUID(uids: [uid], names: filtered.map { $0.name })
                }
                return filtered.first
            } else {
                let nameLowercased = name.lowercased()
                let filtered = entity.relations?.filter { $0.name.lowercased() == nameLowercased } ?? []
                if filtered.count > 1 {
                    throw Error.MultipleRelationsForUID(uids: filtered.map { $0.id.uid }, names: [name])
                }
                return filtered.first
            }
        }
        
        func syncEntity(_ schemaEntity: SchemaEntity) throws -> Entity {
            let entityName = schemaEntity.dbName ?? schemaEntity.className
            let entityUid = schemaEntity.modelUid
            let printUid = entityUid == 1
            if let entityUid = entityUid, !printUid && !parsedUids.insert(entityUid).inserted {
                throw Error.NonUniqueModelUID(uid: entityUid, entity: schemaEntity.className)
            }
            let existingEntity = try findEntity(name: entityName, uid: printUid ? nil : entityUid)
            if let existingEntity = existingEntity, let properties = existingEntity.properties {
                schemaEntity.indexes = properties.compactMap { prop in
                    if let indexId = prop.indexId {
                        let idx = SchemaIndex()
                        idx.modelId = indexId
                        idx.properties = [prop.name]
                        return idx
                    }
                    return nil
                }
            }
            if printUid {
                /* When renaming entities, we let users specify an empty UID
                 annotation. That's this case. If this entity already existed
                 in the model, we print it out as a convenience to our users,
                 who can then write it in the empty spot before renaming the entity. */
                if let existingEntity = existingEntity {
                    let uniqueUID = try uidHelper.create()
                    if modelRead.newUidPool == nil { modelRead.newUidPool = [] }
                    modelRead.newUidPool?.append(uniqueUID)
                    try writeModel(modelRead)
                    throw Error.PrintUid(entity: entityName, found: existingEntity.id.uid, unique: uniqueUID)
                } else {
                    throw Error.UIDTagNeedsValue(entity: entityName)
                }
            }
            
            var lastPropertyId: IdUid
            if let existingEntity = existingEntity, let lastExistingEntityPropertyId = existingEntity.lastPropertyId {
                lastPropertyId = lastExistingEntityPropertyId
            } else {
                lastPropertyId = IdUid()
            }
            let properties = try syncProperties(schemaEntity: schemaEntity, existingEntity: existingEntity, lastPropertyId: &lastPropertyId)
            let relations = try syncRelations(schemaEntity: schemaEntity, existingEntity: existingEntity)
            
            var sourceId: IdUid
            if let existingEntity = existingEntity {
                sourceId = existingEntity.id
            } else {
                sourceId = lastEntityId.incId(uid: try newUid(entityUid)) // Create new id
            }
            
            let entity = Entity(name: entityName, id: sourceId, properties: properties, relations: relations, lastPropertyId: lastPropertyId, isEntitySubclass: schemaEntity.isEntitySubclass)
            
            schemaEntity.modelUid = entity.id.uid
            schemaEntity.modelId = entity.id.id
            schemaEntity.lastPropertyId = entity.lastPropertyId
            
            entitiesBySchemaEntity[schemaEntity] = entity
            
            return entity
        }
        
        func syncProperties(schemaEntity: SchemaEntity, existingEntity: Entity?, lastPropertyId: inout IdUid) throws -> [Property] {
            
            var properties = Array<Property>()
            for parsedProperty in schemaEntity.properties {
                // Don't write a typeless property entry for a to-many backlink into the model.json.
                //  We need an entry for each ToMany for codegen for a struct's init() call in the schema entity, but
                //  it shouldn't be forwarded to the IdSyncModel.
                if !parsedProperty.isToManyRelation {
                    let property = try syncProperty(existingEntity: existingEntity, schemaEntity: schemaEntity, schemaProperty: parsedProperty, lastPropertyId: &lastPropertyId)
                    if property.id.id > lastPropertyId.id {
                        lastPropertyId.id = property.id.id
                    }
                    properties.append(property)
                }
            }
            properties.sort { $0.id.id < $1.id.id }
            
            return properties
        }
        
        func syncProperty(existingEntity: Entity?, schemaEntity: SchemaEntity, schemaProperty: SchemaProperty, lastPropertyId: inout IdUid) throws -> Property {
            let propertyUid = schemaProperty.modelId?.uid
            let printUid = propertyUid == 1
            var existingProperty: Property?
            if let existingEntity = existingEntity {
                if let propertyUid = propertyUid, !printUid, !parsedUids.insert(propertyUid).inserted {
                    throw Error.NonUniqueModelPropertyUID(uid: propertyUid, entity: schemaEntity.className, property: schemaProperty.propertyName)
                }
                existingProperty = try findProperty(entity: existingEntity, name: schemaProperty.name, uid: propertyUid)
            }
            
            if printUid {
                if let existingProperty = existingProperty {
                    let uniqueUID = try uidHelper.create()
                    if modelRead.newUidPool == nil { modelRead.newUidPool = [] }
                    modelRead.newUidPool?.append(uniqueUID)
                    try writeModel(modelRead)
                    throw Error.PrintPropertyUid(entity: schemaEntity.className, property: schemaProperty.propertyName, found: existingProperty.id.uid, unique: uniqueUID)
                } else {
                    throw Error.PropertyUIDTagNeedsValue(entity: schemaEntity.className, property: schemaProperty.propertyName)
                }
            }
            
            let shouldHaveIndex = schemaProperty.indexType != .none || schemaProperty.isRelation
            var sourceIndexId: IdUid? = shouldHaveIndex ? existingProperty?.indexId : nil
            // check entity for index as Property.Index is only auto-set for to-ones
            let foundIndex = schemaEntity.indexes.filter({ $0.properties.count == 1 && $0.properties.first == schemaProperty.name }).first
            if let foundIndex = foundIndex, shouldHaveIndex {
                existingProperty?.indexId = foundIndex.modelId
                sourceIndexId = try existingProperty?.indexId ?? lastIndexId.incId(uid: uidHelper.create())
            } else if existingProperty?.indexId == nil && shouldHaveIndex {
                sourceIndexId = try existingProperty?.indexId ?? lastIndexId.incId(uid: uidHelper.create())
            }
            
            if shouldHaveIndex {
                schemaProperty.entityFlags.insert(.indexed)
            }
            
            // No entry for this index yet? Add one!
            if shouldHaveIndex,
                let existingEntryIndexId = sourceIndexId,
                foundIndex == nil {
                let schemaIndex = SchemaIndex()
                schemaIndex.modelId = existingEntryIndexId
                schemaIndex.properties = [schemaProperty.name]
                schemaEntity.indexes.append(schemaIndex)
                sourceIndexId = existingEntryIndexId
            }
            
            if schemaProperty.isRelation && sourceIndexId == nil {
                let newId = try lastIndexId.incId(uid: uidHelper.create())
                sourceIndexId = newId
                let newIndex = SchemaIndex()
                newIndex.modelId = newId
                newIndex.properties = [schemaProperty.name]
                schemaEntity.indexes.append(newIndex)
            }
            var relationTargetUnresolved: String? = nil
            if schemaProperty.isRelation && schemaProperty.propertyType.hasPrefix("ToOne<") {
                let templateTypeString = schemaProperty.propertyType.drop(first: "ToOne<".count, last: 1)
                relationTargetUnresolved = templateTypeString
            }

            let sourceId: IdUid
            if let existingPropertyId = existingProperty?.id {
                sourceId = existingPropertyId
            } else {
                sourceId = try lastPropertyId.incId(uid: newUid(propertyUid))
            }
            
            let property = Property(name: schemaProperty.name, id: sourceId, indexId: sourceIndexId,
                                    relationTargetUnresolved: relationTargetUnresolved,
                                    type: schemaProperty.entityType.rawValue, flags: schemaProperty.entityFlags.rawValue)
            
            schemaProperty.modelId = property.id
            schemaProperty.modelIndexId = property.indexId
            
            let collision = propertiesBySchemaProperty.updateValue(property, forKey: schemaProperty)
            if let collision = collision {
                throw Error.PropertyCollision(entity: schemaEntity.className, new: property.name, old: collision.name)
            }
            
            return property
        }
        
        func syncRelations(schemaEntity: SchemaEntity, existingEntity: Entity?) throws -> [Relation] {
            var relations = Array<Relation>()
            
            try schemaEntity.relations.forEach { schemaRelation in
                let relation = try syncRelation(existingEntity: existingEntity, schemaEntity: schemaEntity, schemaRelation: schemaRelation)
                if relation.id.id > lastRelationId.id {
                    lastRelationId.id = relation.id.id
                }
                
                relations.append(relation)
            }
            relations.sort { $0.id.id < $1.id.id }

            return relations
        }

        func syncRelation(existingEntity: Entity?, schemaEntity: SchemaEntity, schemaRelation: SchemaRelation) throws -> Relation {
            let name = schemaRelation.dbName ?? schemaRelation.relationName
            let relationUid = schemaRelation.modelId?.uid
            let printUid = relationUid == 1
            var existingRelation: Relation?
            if let existingEntity = existingEntity {
                if let relationUid = relationUid, !printUid, !parsedUids.insert(relationUid).inserted {
                    throw Error.NonUniqueModelRelationUID(uid: relationUid, entity: schemaEntity.className, relation: schemaRelation.relationName)
                }
                existingRelation = try findRelation(entity: existingEntity, name: name, uid: relationUid)
            }
            
            if printUid {
                if let existingRelation = existingRelation {
                    let uniqueUID = try uidHelper.create()
                    if modelRead.newUidPool == nil { modelRead.newUidPool = [] }
                    modelRead.newUidPool?.append(uniqueUID)
                    try writeModel(modelRead)
                    throw Error.PrintRelationUid(entity: schemaEntity.className, relation: schemaRelation.relationName, found: existingRelation.id.uid, unique: uniqueUID)
                } else {
                    throw Error.RelationUIDTagNeedsValue(entity: schemaEntity.className, relation: schemaRelation.relationName)
                }
            }
            
            let sourceId: IdUid
            if let existingRelationId = existingRelation?.id {
                sourceId = existingRelationId
            } else {
                sourceId = try lastRelationId.incId(uid: newUid(relationUid))
            }
            
            let relation = Relation(name: name, id: sourceId)
            
            schemaRelation.modelId = relation.id
            return relation
        }
        
        func newUid(_ candidate: Int64?) throws -> Int64 {
            if let candidate = candidate,
                newUidPool.remove(candidate) == nil {
                throw Error.CandidateUIDNotInPool(candidate)
            }
            
            return try candidate ?? uidHelper.create()
        }
    }
}
