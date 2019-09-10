import Foundation

internal func escapeName(_ string: String) -> String {
    return string.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\r", with: "\\r")
}

class PrettyJSON {
    struct KeyValue {
        var key: String
        var value: String
        var quoteValue: Bool
        
        func toString(indent: Int) -> String {
            let indent = String(repeating: " ", count: indent)
            if quoteValue {
                return "\(indent)\"\(escapeName(key))\": \"\(escapeName(value))\""
            } else {
                return "\(indent)\"\(escapeName(key))\": \(value)"
            }
        }
    }
    
    internal func keyValueString(_ keyValues: [KeyValue], indent: Int) -> String {
        return keyValues.map({ return $0.toString(indent: indent) }).joined(separator: ",\n")
    }
    
    internal func arrayString(_ array: [String]?, indent: Int) -> String {
        guard let array = array, !array.isEmpty else { return "[]" }
        
        let outerIndent = String(repeating: " ", count: indent)
        let indent = String(repeating: " ", count: indent + 2)
        
        let list = array.map({ return ",\n\(indent)\($0)" }).joined().dropFirst()
        return "[\(list)\n\(outerIndent)]"
    }
    
    func encode(_ model: IdSync.IdSyncModel) -> Data {
        var output = """
{
  "_note1": "\(escapeName(model._note1 ?? "KEEP THIS FILE! Check it into a version control system (VCS) like git."))",
  "_note2": "\(escapeName(model._note2 ?? "ObjectBox manages crucial IDs for your object model. See docs for details."))",
  "_note3": "\(escapeName(model._note3 ?? "If you have VCS merge conflicts, you must resolve them according to ObjectBox docs."))",
  "entities": [
"""
        let modelEntities = model.entities ?? []
        if modelEntities.isEmpty {
            output.append("],")
        } else {
            var entitiesToGo = modelEntities.count
            for entity in modelEntities {
                output.append("\n    {\n      \"id\": \"\(entity.id.toString())\",")
                if let lastPropertyId = entity.lastPropertyId {
                    output.append("\n      \"lastPropertyId\": \"\(lastPropertyId.toString())\",")
                }
                output.append("\n      \"name\": \"\(escapeName(entity.name))\",\n      \"properties\": [")
                let entityProperties = entity.properties ?? []
                if entityProperties.isEmpty {
                    output.append("],")
                } else {
                    var propertiesToGo = entityProperties.count
                    for property in entityProperties {
                        var keyValues = [KeyValue]()
                        output.append("\n        {\n")
                        if let flags = property.flags {
                            keyValues.append(KeyValue(key: "flags", value: "\(flags)", quoteValue: false))
                        }
                        keyValues.append(KeyValue(key: "id", value: property.id.toString(), quoteValue: true))
                        if let indexId = property.indexId {
                            keyValues.append(KeyValue(key: "indexId", value: indexId.toString(), quoteValue: true))
                        }
                        keyValues.append(KeyValue(key: "name", value: property.name, quoteValue: true))
                        if let relationTarget = property.relationTarget {
                            keyValues.append(KeyValue(key: "relationTarget", value: relationTarget, quoteValue: true))
                        }
                        if let type = property.type {
                            keyValues.append(KeyValue(key: "type", value: "\(type)", quoteValue: false))
                        }
                        propertiesToGo -= 1
                        output.append("\(keyValueString(keyValues, indent: 10))\n        }\(propertiesToGo > 0 ? "," : "")")
                    }
                    output.append("\n      ],")
                }
                output.append("\n      \"relations\": [")
                let entityRelations = entity.relations ?? []
                if entityRelations.isEmpty {
                    output.append("]")
                } else {
                    var relationsToGo = entityRelations.count
                    for relation in entityRelations {
                        var keyValues = [KeyValue]()
                        output.append("\n        {")
                        keyValues.append(KeyValue(key: "id", value: relation.id.toString(), quoteValue: true))
                        keyValues.append(KeyValue(key: "name", value: relation.name, quoteValue: true))
                        if let targetId = relation.targetId {
                            keyValues.append(KeyValue(key: "targetId", value: targetId.toString(), quoteValue: true))
                        }
                        relationsToGo -= 1
                        output.append("\n\(keyValueString(keyValues, indent: 10))\n        }\(relationsToGo > 0 ? "," : "")")
                    }
                    output.append("\n      ]")
                }
                
                entitiesToGo -= 1
                output.append("\n    }\(entitiesToGo > 0 ? "," : "")")
            }
            
            output.append("\n  ],")
        }

        var keyValues = [KeyValue]()
        if let lastEntityId = model.lastEntityId {
            keyValues.append(KeyValue(key: "lastEntityId", value: lastEntityId.toString(), quoteValue: true))
        }
        if let lastIndexId = model.lastIndexId {
            keyValues.append(KeyValue(key: "lastIndexId", value: lastIndexId.toString(), quoteValue: true))
        }
        if let lastRelationId = model.lastRelationId {
            keyValues.append(KeyValue(key: "lastRelationId", value: lastRelationId.toString(), quoteValue: true))
        }
        if let lastSequenceId = model.lastSequenceId {
            keyValues.append(KeyValue(key: "lastSequenceId", value: lastSequenceId.toString(), quoteValue: true))
        }
        keyValues.append(KeyValue(key: "modelVersion", value: "\(model.modelVersion)", quoteValue: false))
        keyValues.append(KeyValue(key: "modelVersionParserMinimum", value: "\(model.modelVersionParserMinimum)", quoteValue: false))
        
        if let newUidPool = model.newUidPool {
            keyValues.append(KeyValue(key: "newUidPool", value: arrayString(newUidPool.map({ return "\($0)" }), indent: 2), quoteValue: false))
        }
        if let retiredEntityUids = model.retiredEntityUids {
            keyValues.append(KeyValue(key: "retiredEntityUids", value: arrayString(retiredEntityUids.map({ return "\($0)" }), indent: 2), quoteValue: false))
        }
        if let retiredIndexUids = model.retiredIndexUids {
            keyValues.append(KeyValue(key: "retiredIndexUids", value: arrayString(retiredIndexUids.map({ return "\($0)" }), indent: 2), quoteValue: false))
        }
        if let retiredPropertyUids = model.retiredPropertyUids {
            keyValues.append(KeyValue(key: "retiredPropertyUids", value: arrayString(retiredPropertyUids.map({ return "\($0)" }), indent: 2), quoteValue: false))
        }
        if let retiredRelationUids = model.retiredRelationUids {
            keyValues.append(KeyValue(key: "retiredRelationUids", value: arrayString(retiredRelationUids.map({ return "\($0)" }), indent: 2), quoteValue: false))
        }
        keyValues.append(KeyValue(key: "version", value: "\(model.version)", quoteValue: false))
        output.append("\n\(keyValueString(keyValues, indent: 2))\n}")
        
        return output.data(using: .utf8)!
    }
}
