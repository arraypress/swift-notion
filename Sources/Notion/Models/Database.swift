//
//  Database.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A database — a page with a schema.
public struct Database: Sendable, Codable, Equatable, Identifiable {
    /// The Notion id — a UUID, dashed or not depending on where it came from.
    public let id: String
    /// The database name.
    public let title: String
    /// The blurb under the title, when one is set.
    public let description: String?
    /// Column name → Notion type (`title`, `select`, `date`…).
    public let schema: [String: String]
    /// The database's address in Notion.
    public let url: String?
    /// When the database was made.
    public let createdTime: Date?
    /// When it was last changed.
    public let lastEditedTime: Date?

    private enum CodingKeys: String, CodingKey {
        case id, title, description, properties, url
        case createdTime = "created_time", lastEditedTime = "last_edited_time"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? ""
        // A database's title is a rich-text ARRAY at the top level, where a
        // page's is buried in its properties. Different shape, same idea.
        self.title = Properties.richText((try? container.decodeIfPresent(JSONValue.self, forKey: .title)) ?? nil)
        let described = Properties.richText((try? container.decodeIfPresent(JSONValue.self, forKey: .description)) ?? nil)
        self.description = described.isEmpty ? nil : described

        let raw = (try? container.decodeIfPresent([String: JSONValue].self, forKey: .properties)) ?? nil
        self.schema = (raw ?? [:]).compactMapValues { $0["type"]?.string }

        self.url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? nil
        self.createdTime = Timestamps.parse((try? container.decodeIfPresent(String.self, forKey: .createdTime)) ?? nil)
        self.lastEditedTime = Timestamps.parse((try? container.decodeIfPresent(String.self, forKey: .lastEditedTime)) ?? nil)
    }

    public init(id: String, title: String, description: String? = nil,
                schema: [String: String] = [:], url: String? = nil,
                createdTime: Date? = nil, lastEditedTime: Date? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.schema = schema
        self.url = url
        self.createdTime = createdTime
        self.lastEditedTime = lastEditedTime
    }

    /// The name of the title column, whatever the user called it.
    public var titleColumn: String? {
        schema.first { $0.value == "title" }?.key
    }
}
