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


enum ObjectBoxFilters {
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
    
    static func exposeObjects(to objectsDictionary: inout [String:Any]) {
        objectsDictionary["obxes"] = ["date": Date().description, "name": NSUserName()]
    }
    
    static func addExtensions(_ ext: Stencil.Extension) {
        ext.registerFilter("idForProperty", filter: ObjectBoxFilters.idForProperty)
    }
    
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
