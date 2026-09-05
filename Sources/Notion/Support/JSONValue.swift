//
//  JSONValue.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//
//  A loosely-typed JSON value.
//
//  Needed because Notion's properties are open-ended: the keys are whatever
//  the user named their columns, and the value's shape depends on a `type`
//  tag inside it. There is no fixed `Codable` struct that describes a page's
//  properties — only a walk. This is that walk's currency.
//
//  Deliberately small and `Sendable`, so a decoded page can cross a
//  concurrency boundary and be re-encoded without `Any` anywhere.
//

import Foundation

/// Any JSON value.
public indirect enum JSONValue: Sendable, Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        // Bool before Double: JSONDecoder will read `true` as 1 otherwise.
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        self = .null
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    // MARK: - Reading

    public var string: String? { if case .string(let value) = self { return value }; return nil }
    public var number: Double? { if case .number(let value) = self { return value }; return nil }
    public var bool: Bool? { if case .bool(let value) = self { return value }; return nil }
    public var object: [String: JSONValue]? { if case .object(let value) = self { return value }; return nil }
    public var array: [JSONValue]? { if case .array(let value) = self { return value }; return nil }
    public var isNull: Bool { self == .null }

    /// A value by key path — `value["properties"]?["Name"]`.
    public subscript(key: String) -> JSONValue? { object?[key] }
}
