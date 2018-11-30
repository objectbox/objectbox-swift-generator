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
}

enum ObjectBoxFilters {
    
    class HasIdUid: Codable {
        var id: IdUid
        
        var uid: Int64 {
            get {
                return id.uid
            }
            set(new) {
                id.uid = new
            }
        }
        
        var modelId: Int32 {
            get {
                return id.id
            }
            set(new) {
                id.id = new
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case id
        }
    }
    
    class Property: HasIdUid {
        var name = ""
        var indexId = IdUid()
        
        private enum CodingKeys: String, CodingKey {
            case name
            case indexId
        }
    }
    
    class Relation: HasIdUid {
        var name = ""
        
        private enum CodingKeys: String, CodingKey {
            case name
        }
    }
    
    class Entity: HasIdUid {
        var name = ""
        var lastPropertyId = IdUid()
        var properties: Array<Property> = []
        var relations: Array<Relation> = []
        
        private enum CodingKeys: String, CodingKey {
            case name
            case lastPropertyId
            case properties
            case relations
        }
    }
    
    class IdSyncModel: Codable {
    
        static let modelVersion: Int64 = 4 // !! When upgrading always check modelVersionParserMinimum !!
        static let modelVersionParserMinimum: Int64 = 4
        
        /** "Comments" in the JSON file */
        var _note1: String = "KEEP THIS FILE! Check it into a version control system (VCS) like git."
        var _note2: String = "ObjectBox manages crucial IDs for your object model. See docs for details."
        var _note3: String = "If you have VCS merge conflicts, you must resolve them according to ObjectBox docs."
        
        var version: Int64 = 0
        var modelVersion: Int64 = IdSyncModel.modelVersion
        /** Specify backward compatibility with older parsers.*/
        var modelVersionParserMinimum: Int64 = modelVersion
        var lastEntityId: IdUid
        var lastIndexId: IdUid
        var lastRelationId: IdUid
        // TODO use this once we support sequences
        var lastSequenceId: IdUid
        
        var entities: Array<Entity> = []
        
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
    }
    
    /* The following two functyions and this error type are copied from SourcerySwiftKit because that doesn't
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

    /* Process the parsed syntax tree, possibly annotating or otherwise
        extending it. */
    static func process(parsingResult result: inout Sourcery.ParsingResult) {
        result.types.all.forEach { currClass in
            print("\(currClass.name): \(currClass.annotations)");
            currClass.variables.forEach { currVariable in
                print("\(currVariable.name): \(currVariable.annotations)");
            }
        }
        
        var newTypes: [Type] = result.types.all
        newTypes.append(Type(name: "InjectedType", annotations: ["Entity": NSNumber(value: 1)]))
        
        result = (types: Types(types: newTypes), inlineRanges: result.inlineRanges)
    }
    
    /* Modify the dictionary of global objects that Stencil sees. */
    static func exposeObjects(to objectsDictionary: inout [String:Any]) {
        objectsDictionary["obxes"] = ["date": Date().description, "name": NSUserName()]
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
