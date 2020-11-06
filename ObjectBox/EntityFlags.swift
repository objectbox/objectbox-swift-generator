/*
 * Copyright 2020 ObjectBox Ltd. All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// automatically generated by the FlatBuffers compiler, do not modify
// swiftlint:disable all



///  Not really an enum, but binary flags to use across languages
public enum EntityFlags: UInt32 {
    public typealias T = UInt32
    public static var byteSize: Int { return MemoryLayout<UInt32>.size }
    public var value: UInt32 { return self.rawValue }
    ///  Use the default (no arguments) constructor to create entities
    case useNoArgConstructor = 1
    ///  Enable "data synchronization" for this entity type: objects will be synced with other stores over the network.
    ///  It's possible to have local-only (non-synced) types and synced types in the same store (schema/data model).
    case syncEnabled = 2
    

    public static var max: EntityFlags { return .syncEnabled }
    public static var min: EntityFlags { return .useNoArgConstructor }
}

