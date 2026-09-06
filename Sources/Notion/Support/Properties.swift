//
//  Properties.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//
//  Flattening Notion's property model, which is the whole difficulty of this
//  API.
//
//  Every property is a tagged union nested two or three levels deep, and the
//  nesting differs per type. A page's title is not `properties.Name` — it is
//  `properties.Name.title[0].plain_text`, and the key is whatever the user
//  called that column. A date is `properties.Due.date.start`. A multi-select
//  is an array of objects each with their own `name`.
//
//  So a caller who just wants "what does this page say" has to walk a
//  different path per type, twenty-odd times. This does it once.
//

//

import Foundation

/// Reads Notion's property objects.
enum Properties {

    /// Flattens a whole `properties` block.
    static func flatten(_ raw: [String: JSONValue]?) -> [String: PropertyValue] {
        guard let raw else { return [:] }
        var out: [String: PropertyValue] = [:]
        for (name, value) in raw {
            if let property = flattenOne(value) { out[name] = property }
        }
        return out
    }

    /// The page's title, wherever it lives.
    ///
    /// The title column can be named anything — `Name`, `Task`, `Aa` — so it
    /// is found by TYPE rather than by key. That is the only reliable way.
    static func title(_ raw: [String: JSONValue]?) -> String? {
        guard let raw else { return nil }
        for (_, value) in raw {
            guard value.object?["type"]?.string == "title" else { continue }
            let text = richText(value.object?["title"])
            if !text.isEmpty { return text }
        }
        return nil
    }

    /// One property, by its type tag.
    static func flattenOne(_ value: JSONValue) -> PropertyValue? {
        guard let object = value.object, let type = object["type"]?.string else { return nil }
        let payload = object[type]

        switch type {
        case "title", "rich_text":
            return PropertyValue(type: type, text: richText(payload))

        case "number":
            let number = payload?.number
            return PropertyValue(type: type, text: number.map(Format.number) ?? "", number: number)

        case "checkbox":
            let ticked = payload?.bool ?? false
            return PropertyValue(type: type, text: ticked ? "yes" : "no", checkbox: ticked)

        case "select", "status":
            let name = payload?.object?["name"]?.string ?? ""
            return PropertyValue(type: type, text: name, values: name.isEmpty ? [] : [name])

        case "multi_select":
            let names = (payload?.array ?? []).compactMap { $0.object?["name"]?.string }
            return PropertyValue(type: type, text: names.joined(separator: ", "), values: names)

        case "date":
            // A date may be a range; the end is only present when it is one.
            let start = payload?.object?["start"]?.string
            let end = payload?.object?["end"]?.string
            let text = [start, end].compactMap { $0 }.joined(separator: " → ")
            return PropertyValue(type: type, text: text,
                                 values: [start, end].compactMap { $0 })

        case "people", "created_by", "last_edited_by":
            let names = peopleNames(payload)
            return PropertyValue(type: type, text: names.joined(separator: ", "), values: names)

        case "files":
            let names = (payload?.array ?? []).compactMap {
                $0.object?["name"]?.string
                    ?? $0.object?["external"]?.object?["url"]?.string
                    ?? $0.object?["file"]?.object?["url"]?.string
            }
            return PropertyValue(type: type, text: names.joined(separator: ", "), values: names)

        case "url", "email", "phone_number", "created_time", "last_edited_time":
            return PropertyValue(type: type, text: payload?.string ?? "")

        case "relation":
            let ids = (payload?.array ?? []).compactMap { $0.object?["id"]?.string }
            return PropertyValue(type: type, text: "\(ids.count) linked", values: ids)

        case "unique_id":
            let prefix = payload?.object?["prefix"]?.string
            let number = payload?.object?["number"]?.number
            let text = [prefix, number.map { Format.number($0) }].compactMap { $0 }.joined(separator: "-")
            return PropertyValue(type: type, text: text, number: number)

        case "formula", "rollup":
            // These wrap another typed value; unwrap one level and re-read it.
            guard let inner = payload, let innerType = inner.object?["type"]?.string else {
                return PropertyValue(type: type, text: "")
            }
            let rebuilt = JSONValue.object(["type": .string(innerType),
                                            innerType: inner.object?[innerType] ?? .null])
            guard let nested = flattenOne(rebuilt) else {
                return PropertyValue(type: type, text: "")
            }
            // Keep the outer type so a caller can tell a formula from a number.
            return PropertyValue(type: type, text: nested.text, number: nested.number,
                                 checkbox: nested.checkbox, values: nested.values)

        default:
            return PropertyValue(type: type, text: payload?.string ?? "")
        }
    }

    /// Joins a rich-text array into plain text.
    ///
    /// Notion splits a sentence into runs whenever formatting changes, so
    /// "**bold** word" is two entries that must be concatenated, not the
    /// first one taken.
    static func richText(_ value: JSONValue?) -> String {
        (value?.array ?? [])
            .compactMap { $0.object?["plain_text"]?.string }
            .joined()
    }

    private static func peopleNames(_ value: JSONValue?) -> [String] {
        if let array = value?.array {
            return array.compactMap { $0.object?["name"]?.string ?? $0.object?["id"]?.string }
        }
        if let single = value?.object {
            return [single["name"]?.string ?? single["id"]?.string].compactMap { $0 }
        }
        return []
    }
}
