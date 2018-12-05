//
//  IdSyncModel.swift
//  Sourcery
//
//  Created by Uli Kusterer on 03.12.18.
//  Copyright © 2018 ObjectBox. All rights reserved.
//

import Foundation


enum IdSync {
    
    // Todo: Unify ID/Id spelling. Swift usually does ID.
    
    enum Error: Swift.Error {
        case IncompatibleVersion(found: Int64, expected: Int64)
        case DuplicateEntityName(String)
        case DuplicateEntityID(name: String, id: Int32)
        case MissingLastEntityID
        case LastEntityIdUIDMismatch(name: String, id: Int32, found: Int64, expected: Int64)
        case EntityIdGreatherThanLast(name: String, found: Int32, last: Int32)
        case MissingLastPropertyID
        case DuplicatePropertyID(entity: String, name: String, id: Int32)
        case LastPropertyIdUIDMismatch(entity: String, name: String, id: Int32, found: Int64, expected: Int64)
        case PropertyIdGreatherThanLast(entity: String, name: String, found: Int32, last: Int32)
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
    }
    
    class Property: Codable {
        var id = IdUid()
        var name = ""
        var indexId: IdUid?
        
        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case indexId
        }
        
        init(name: String, id: IdUid, indexId: IdUid?) {
            self.id = id
            self.name = name
            self.indexId = indexId
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
        
        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case lastPropertyId
            case properties
            case relations
        }
        
        init(name: String, id: IdUid, properties: [Property], relations: [Relation], lastPropertyId: IdUid) {
            self.name = name
            self.id = id
            self.properties = properties
            self.relations = relations
            self.lastPropertyId = lastPropertyId
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
                return name.hashValue
            }
        }
        
        public func hash(into hasher: inout Hasher) {
            name.hash(into: &hasher)
        }
    }
    
    class IdSyncModel: Codable {
        
        static let modelVersion: Int64 = 4 // !! When upgrading always check modelVersionParserMinimum !!
        static let modelVersionParserMinimum: Int64 = 4
        
        /** "Comments" in the JSON file */
        var _note1: String? = "KEEP THIS FILE! Check it into a version control system (VCS) like git."
        var _note2: String? = "ObjectBox manages crucial IDs for your object model. See docs for details."
        var _note3: String? = "If you have VCS merge conflicts, you must resolve them according to ObjectBox docs."
        
        var version: Int64 = 0
        var modelVersion: Int64 = IdSyncModel.modelVersion
        /** Specify backward compatibility with older parsers.*/
        var modelVersionParserMinimum: Int64 = modelVersion
        var lastEntityId: IdUid?
        var lastIndexId: IdUid?
        var lastRelationId: IdUid?
        // TODO use this once we support sequences
        var lastSequenceId: IdUid?
        
        var entities: Array<Entity>? = []
        
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
        
        func create() throws -> Int64 {
            var newId: Int64
            for _ in 1 ... 1000 {
                newId = Int64.random(in: 1 ... Int64.max) & 0x7FFFFFFFFFFFFF00
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
    
    class SchemaIndex {
        var properties = Array<SchemaProperty>()
    }
    
    class Schema {
        var entities: [SchemaEntity] = []
        
        var lastEntityId = IdUid()
        var lastRelationId = IdUid()
        var lastIndexId = IdUid()
    }
    
    class SchemaEntity: Hashable, Equatable {
        var modelId: Int32?
        var modelUid: Int64?
        var className: String = ""
        var dbName: String?
        var properties = Array<SchemaProperty>()
        var indexes = Array<SchemaIndex>()
        var toManyRelations = Array<ToManyStandalone>()
        var lastPropertyId: IdUid?

        public static func == (lhs: SchemaEntity, rhs: SchemaEntity) -> Bool {
            return lhs.className == rhs.className
        }
        
        public var hashValue: Int {
            get {
                return className.hashValue
            }
        }
        
        public func hash(into hasher: inout Hasher) {
            className.hash(into: &hasher)
        }
    }
    
    class SchemaProperty: Hashable, Equatable {
        var modelId: IdUid?
        var propertyName: String = ""
        var dbName: String?
        var modelIndexId: IdUid?

        public static func == (lhs: SchemaProperty, rhs: SchemaProperty) -> Bool {
            return lhs.propertyName == rhs.propertyName
        }
        
        public var hashValue: Int {
            get {
                return propertyName.hashValue
            }
        }
        
        public func hash(into hasher: inout Hasher) {
            propertyName.hash(into: &hasher)
        }
    }
    
    class ToManyStandalone {
        var modelId: IdUid?
        var name: String = ""
        var dbName: String?
    }
    
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
        
        let uidHelper = UidHelper()
        
        private var entitiesReadByUid = Dictionary<Int64, Entity>()
        private var entitiesReadByName = Dictionary<String, Entity>()
        private var parsedUids = Set<Int64>()

        private var entitiesBySchemaEntity = Dictionary<SchemaEntity, Entity>()
        private var propertiesBySchemaProperty = Dictionary<SchemaProperty, Property>()

        init(jsonFile: URL) throws {
            let data = try Data(contentsOf: jsonFile)
            let decoder = JSONDecoder()
            modelRead = try decoder.decode(IdSyncModel.self, from: data)
            
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

            try validateIds()
            
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
        
        func validateIds() throws {
            var entityIds = Set<Int32>()
            try modelRead.entities?.forEach { entity in
                guard !entityIds.contains(entity.id.id) else {
                    throw Error.DuplicateEntityID(name: entity.name, id: entity.id.id)
                }
                entityIds.insert(entity.id.id)
                
                guard let lastEntityId = modelRead.lastEntityId else {
                    throw Error.MissingLastEntityID
                }
                
                if (entity.id.id == lastEntityId.id) {
                    if (entity.id.uid != lastEntityId.uid) {
                        throw Error.LastEntityIdUIDMismatch(name: entity.name, id: entity.id.id, found: entity.id.uid, expected: lastEntityId.uid)
                    }
                } else if (entity.id.id > lastEntityId.id) {
                    throw Error.EntityIdGreatherThanLast(name: entity.name, found:entity.id.id, last: lastEntityId.id)
                }
                
                var propertyIds = Set<Int32>()
                try entity.properties?.forEach { property in
                    guard !propertyIds.contains(property.id.id) else {
                        throw Error.DuplicatePropertyID(entity: entity.name, name: property.name, id: property.id.id)
                    }
                    propertyIds.insert(entity.id.id)
                    
                    guard let lastPropertyId = entity.lastPropertyId else {
                        throw Error.MissingLastPropertyID
                    }
                    
                    if (property.id.id == lastPropertyId.id) {
                        if (property.id.uid != lastPropertyId.uid) {
                            throw Error.LastPropertyIdUIDMismatch(entity: entity.name, name: property.name, id: property.id.id, found: property.id.uid, expected: lastPropertyId.uid)
                        }
                    } else if (property.id.id > lastPropertyId.id) {
                        throw Error.PropertyIdGreatherThanLast(entity: entity.name, name: property.name, found: property.id.id, last: lastPropertyId.id)
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
            retiredPropertyUids.append(contentsOf: oldPropertyUids.indexUids)

            oldPropertyUids.relationUids.subtract(newPropertyUids.relationUids)
            retiredPropertyUids.append(contentsOf: oldPropertyUids.relationUids)
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
        
        func writeModel(_ entities: [Entity]) {
            
        }
        
        func sync(schema: Schema) throws {
            guard entitiesBySchemaEntity.isEmpty && propertiesBySchemaProperty.isEmpty else {
                throw Error.SyncMayOnlyBeCalledOnce
            }
            
            let entities = (try schema.entities.map { try syncEntity($0) }).sorted { $0.id.id < $1.id.id }
            updateRetiredUids(entities)
            writeModel(entities)
            
            schema.lastEntityId = lastEntityId
            schema.lastIndexId = lastIndexId
            schema.lastRelationId = lastRelationId
        }
        
        func findEntity(name: String, uid: Int64?) throws -> Entity? {
            if let uid = uid, uid != 0, uid != -1 {
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
            if let uid = uid, uid != 0, uid != -1 {
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
            
            if let uid = uid, uid != 0, uid != -1 {
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
            let printUid = entityUid == -1
            if let entityUid = entityUid, !printUid && !parsedUids.insert(entityUid).inserted {
                throw Error.NonUniqueModelUID(uid: entityUid, entity: schemaEntity.className)
            }
            let existingEntity = try findEntity(name: entityName, uid: entityUid)
            if printUid {
                /* When renaming entities, we let users specify an empty UID
                 annotation. That's this case. If this entity already existed
                 in the model, we print it out as a convenience to our users,
                 who can then write it in the empty spot before renaming the entity. */
                if let existingEntity = existingEntity {
                    throw Error.PrintUid(entity: entityName, found: existingEntity.id.uid, unique: try uidHelper.create())
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
            
            let entity = Entity(name: entityName, id: sourceId, properties: properties, relations: relations, lastPropertyId: lastPropertyId)
            
            schemaEntity.modelUid = entity.id.uid
            schemaEntity.modelId = entity.id.id
            schemaEntity.lastPropertyId = entity.lastPropertyId
            
            entitiesBySchemaEntity[schemaEntity] = entity
            
            return entity
        }
        
        func syncProperties(schemaEntity: SchemaEntity, existingEntity: Entity?, lastPropertyId: inout IdUid) throws -> [Property] {
            
            var properties = Array<Property>()
            for parsedProperty in schemaEntity.properties {
                let property = try syncProperty(existingEntity: existingEntity, schemaEntity: schemaEntity, schemaProperty: parsedProperty, lastPropertyId: &lastPropertyId)
                if property.id.id > lastPropertyId.id {
                    lastPropertyId.id = property.id.id
                }
                properties.append(property)
            }
            properties.sort { $0.id.id < $1.id.id }
            
            return properties
        }
        
        func syncProperty(existingEntity: Entity?, schemaEntity: SchemaEntity, schemaProperty: SchemaProperty, lastPropertyId: inout IdUid) throws -> Property {
            let name = schemaProperty.dbName ?? schemaProperty.propertyName
            let propertyUid = schemaProperty.modelId?.uid
            let printUid = propertyUid == -1
            var existingProperty: Property?
            if let existingEntity = existingEntity {
                if let propertyUid = propertyUid, !printUid, !parsedUids.insert(propertyUid).inserted {
                    throw Error.NonUniqueModelPropertyUID(uid: propertyUid, entity: schemaEntity.className, property: schemaProperty.propertyName)
                }
                existingProperty = try findProperty(entity: existingEntity, name: name, uid: propertyUid)
            }
            
            if printUid {
                if let existingProperty = existingProperty {
                    throw Error.PrintPropertyUid(entity: schemaEntity.className, property: schemaProperty.propertyName, found: existingProperty.id.uid, unique: try uidHelper.create())
                } else {
                    throw Error.PropertyUIDTagNeedsValue(entity: schemaEntity.className, property: schemaProperty.propertyName)
                }
            }
            
            var sourceIndexId: IdUid?
            // check entity for index as Property.Index is only auto-set for to-ones
            let index = schemaEntity.indexes.firstIndex { $0.properties.count == 1 && $0.properties.first == schemaProperty }
            if index != nil {
                sourceIndexId = try existingProperty?.indexId ?? lastIndexId.incId(uid: uidHelper.create())
            }
            
            let sourceId: IdUid
            if let existingPropertyId = existingProperty?.id {
                sourceId = existingPropertyId
            } else {
                sourceId = try lastPropertyId.incId(uid: newUid(propertyUid))
            }
            
            let property = Property(name: name, id: sourceId, indexId: sourceIndexId)
            
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
            let schemaRelations = schemaEntity.toManyRelations.compactMap { $0 as? ToManyStandalone }
            
            try schemaRelations.forEach { schemaRelation in
                let relation = try syncRelation(existingEntity: existingEntity, schemaEntity: schemaEntity, schemaRelation: schemaRelation)
                if relation.id.id > lastRelationId.id {
                    lastRelationId.id = relation.id.id
                }
                
                relations.append(relation)
            }
            relations.sort { $0.id.id < $1.id.id }

            return relations
        }

        func syncRelation(existingEntity: Entity?, schemaEntity: SchemaEntity, schemaRelation: ToManyStandalone) throws -> Relation {
            let name = schemaRelation.dbName ?? schemaRelation.name
            let relationUid = schemaRelation.modelId?.uid
            let printUid = relationUid == -1
            var existingRelation: Relation?
            if let existingEntity = existingEntity {
                if let relationUid = relationUid, !printUid, !parsedUids.insert(relationUid).inserted {
                    throw Error.NonUniqueModelRelationUID(uid: relationUid, entity: schemaEntity.className, relation: schemaRelation.name)
                }
                existingRelation = try findRelation(entity: existingEntity, name: name, uid: relationUid)
            }
            
            if printUid {
                if let existingRelation = existingRelation {
                    throw Error.PrintRelationUid(entity: schemaEntity.className, relation: schemaRelation.name, found: existingRelation.id.uid, unique: try uidHelper.create())
                } else {
                    throw Error.RelationUIDTagNeedsValue(entity: schemaEntity.className, relation: schemaRelation.name)
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
