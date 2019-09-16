//
//  ObjectBoxAnnotations.swift
//  Sourcery
//
//  Created by Uli Kusterer on 16.09.19.
//

import Foundation

/// uid: Force this property/class to have this UID (used when renaming)
struct UidAnnotation {
    var uid: Int64 = 0
}

/// backlink: This property is a backlink, and linked to the property with the given name.
struct BacklinkAnnotation {
    var backlink = ""
}

/// nameInDb: Name to use for this property in database model.
struct NameInDbAnnotation {
    var nameInDb = ""
}

/// convert: Tells ObjectBox how to write/read a non-primitive-type property.
struct ConvertAnnotation {
    var converterTypeName = ""
    var defaultValue = ""
    var dbTypeName = ""
}

/// index: Marks the type of index to use for a property.
struct IndexAnnotation {
    var indexType: IdSync.SchemaIndexType = .valueIndex
}

/// unique: Marks a property as having to be unique in the database.
struct UniqueAnnotation {
    var isUniqueIndex = false
}

/// objectId: marks the property to use for the ID.
struct ObjectIdAnnotation {
    var isUniqueIndex = false
    var isAssignable = false ///< These IDs should not be auto-assigned in sequence by ObjectBox.
}

/// transient: This property shouldn't be serialized.
struct TransientAnnotation {
    var isTransient = false
}

// entity: This type is an entity type that should be processed despite not conforming to Entity.
struct EntityAnnotation {
    var isEntity = false
}

