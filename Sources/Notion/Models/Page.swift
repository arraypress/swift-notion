//
//  Page.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A page, or a database row — Notion makes no distinction.
public struct Page: Sendable, Codable, Equatable, Identifiable {
    /// The Notion id — a UUID, dashed or not depending on where it came from.
    public let id: String
    /// The title, found by TYPE rather than key: the title column can be
    /// called anything.
    public let title: String
    /// Every property, flattened to something printable.
    public let properties: [String: PropertyValue]
    /// The page this one sits inside, when it has one.
    public let parentID: String?
    /// `database_id`, `page_id`, `workspace`.
    public let parentType: String?
    /// The page's address in Notion.
    public let url: String?
    /// The page icon, as an emoji or an image URL.
    public let icon: String?
    /// When the page was made.
    public let createdTime: Date?
    /// When it was last changed.
    public let lastEditedTime: Date?
    /// Whether it is in the trash. Archived pages still resolve.
    public let archived: Bool

    private enum CodingKeys: String, CodingKey {
        case id, properties, parent, url, icon, cover
        case createdTime = "created_time", lastEditedTime = "last_edited_time"
        case archived, inTrash = "in_trash"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? ""
        let raw = (try? container.decodeIfPresent([String: JSONValue].self, forKey: .properties)) ?? nil
        self.properties = Properties.flatten(raw)
        self.title = Properties.title(raw) ?? ""
        self.url = (try? container.decodeIfPresent(String.self, forKey: .url)) ?? nil

        let parent = (try? container.decodeIfPresent(JSONValue.self, forKey: .parent)) ?? nil
        self.parentType = parent?["type"]?.string
        self.parentID = parent.flatMap { block in
            block["database_id"]?.string ?? block["page_id"]?.string ?? block["block_id"]?.string
        }

        // An icon is an emoji or a file; the emoji is the useful one.
        let iconValue = (try? container.decodeIfPresent(JSONValue.self, forKey: .icon)) ?? nil
        self.icon = iconValue?["emoji"]?.string
            ?? iconValue?["external"]?["url"]?.string
            ?? iconValue?["file"]?["url"]?.string

        self.createdTime = Timestamps.parse((try? container.decodeIfPresent(String.self, forKey: .createdTime)) ?? nil)
        self.lastEditedTime = Timestamps.parse((try? container.decodeIfPresent(String.self, forKey: .lastEditedTime)) ?? nil)
        // `archived` was renamed `in_trash`; both appear depending on age.
        let archived = ((try? container.decodeIfPresent(Bool.self, forKey: .archived)) ?? nil)
        let inTrash = ((try? container.decodeIfPresent(Bool.self, forKey: .inTrash)) ?? nil)
        self.archived = archived ?? inTrash ?? false
    }

    public init(id: String, title: String, properties: [String: PropertyValue] = [:],
                parentID: String? = nil, parentType: String? = nil, url: String? = nil,
                icon: String? = nil, createdTime: Date? = nil, lastEditedTime: Date? = nil,
                archived: Bool = false) {
        self.id = id
        self.title = title
        self.properties = properties
        self.parentID = parentID
        self.parentType = parentType
        self.url = url
        self.icon = icon
        self.createdTime = createdTime
        self.lastEditedTime = lastEditedTime
        self.archived = archived
    }

    /// Whether this page is a row in a database.
    public var isDatabaseRow: Bool { parentType == "database_id" }
}
