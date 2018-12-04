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
        
        func contains(uid: Int64) -> Bool {
            if id.uid == uid { return true }
            
            return false
        }
    }
    
    class Entity: Codable {
        var id = IdUid()
        var name = ""
        var lastPropertyId: IdUid!
        var properties: Array<Property>?
        var relations: Array<Relation>?
        
        private enum CodingKeys: String, CodingKey {
            case id
            case name
            case lastPropertyId
            case properties
            case relations
        }
        
        func contains(uid: Int64) -> Bool {
            if id.uid == uid { return true }
            if lastPropertyId.uid == uid { return true }
            
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
    }
}
