//
//  Models+Encoding.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//
//  Canonical encoders. These write the FLATTENED shape — a title as a string
//  where Notion sends a rich-text array, a property as its readable value
//  where Notion sends a tagged union three levels deep. Re-emitting Notion's
//  own shape would push the whole difficulty back onto the consumer.
//

import Foundation

extension Page {
    private enum OutputKeys: String, CodingKey {
        case id, title, properties, parentID, parentType, url, icon
        case createdTime, lastEditedTime, archived, isDatabaseRow
    }

    /// Writes the flattened shape, not the nested one Notion sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        if !properties.isEmpty { try container.encode(properties, forKey: .properties) }
        try container.encodeIfPresent(parentID, forKey: .parentID)
        try container.encodeIfPresent(parentType, forKey: .parentType)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(icon, forKey: .icon)
        try container.encodeIfPresent(createdTime, forKey: .createdTime)
        try container.encodeIfPresent(lastEditedTime, forKey: .lastEditedTime)
        try container.encode(archived, forKey: .archived)
        try container.encode(isDatabaseRow, forKey: .isDatabaseRow)
    }
}

extension Database {
    private enum OutputKeys: String, CodingKey {
        case id, title, description, schema, titleColumn, url, createdTime, lastEditedTime
    }

    /// Writes the flattened shape, not the nested one Notion sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        if !schema.isEmpty { try container.encode(schema, forKey: .schema) }
        try container.encodeIfPresent(titleColumn, forKey: .titleColumn)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(createdTime, forKey: .createdTime)
        try container.encodeIfPresent(lastEditedTime, forKey: .lastEditedTime)
    }
}

extension Block {
    private enum OutputKeys: String, CodingKey {
        case id, type, text, checked, language, hasChildren, markdown
    }

    /// Writes the flattened shape, not the nested one Notion sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(checked, forKey: .checked)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encode(hasChildren, forKey: .hasChildren)
        try container.encode(markdown, forKey: .markdown)
    }
}

extension User {
    private enum OutputKeys: String, CodingKey { case id, name, type, botOwner }

    /// Writes the flattened shape, not the nested one Notion sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(botOwner, forKey: .botOwner)
    }
}

extension PageMarkdown {
    private enum OutputKeys: String, CodingKey {
        case id, markdown, truncated, unknownBlockIDs, isComplete
    }

    /// Writes the flattened shape, not the nested one Notion sends.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OutputKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(markdown, forKey: .markdown)
        try container.encode(truncated, forKey: .truncated)
        if !unknownBlockIDs.isEmpty {
            try container.encode(unknownBlockIDs, forKey: .unknownBlockIDs)
        }
        try container.encode(isComplete, forKey: .isComplete)
    }
}
