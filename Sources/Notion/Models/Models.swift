//
//  Models.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A page, or a database row — Notion makes no distinction.
public struct Page: Sendable, Codable, Equatable, Identifiable {
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
    public let url: String?
    public let icon: String?
    public let createdTime: Date?
    public let lastEditedTime: Date?
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

/// A database — a page with a schema.
public struct Database: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let title: String
    public let description: String?
    /// Column name → Notion type (`title`, `select`, `date`…).
    public let schema: [String: String]
    public let url: String?
    public let createdTime: Date?
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

/// One block of page content, flattened to text.
public struct Block: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    /// `paragraph`, `heading_1`, `bulleted_list_item`, `code`, `to_do`…
    public let type: String
    public let text: String
    /// Whether a to-do is ticked.
    public let checked: Bool?
    /// The language, on a code block.
    public let language: String?
    /// Whether this block has children that were not fetched.
    public let hasChildren: Bool

    private enum CodingKeys: String, CodingKey {
        case id, type, hasChildren = "has_children"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? ""
        let type = (try? container.decode(String.self, forKey: .type)) ?? ""
        self.type = type
        self.hasChildren = ((try? container.decodeIfPresent(Bool.self, forKey: .hasChildren)) ?? nil) ?? false

        // The payload is under a key named after the type — the same trick
        // the properties use.
        let whole = (try? JSONValue(from: decoder))
        let payload = whole?[type]
        self.text = Properties.richText(payload?["rich_text"])
        self.checked = payload?["checked"]?.bool
        self.language = payload?["language"]?.string
    }

    public init(id: String, type: String, text: String, checked: Bool? = nil,
                language: String? = nil, hasChildren: Bool = false) {
        self.id = id
        self.type = type
        self.text = text
        self.checked = checked
        self.language = language
        self.hasChildren = hasChildren
    }

    /// The block as Markdown, so a page can be read as a document.
    public var markdown: String {
        switch type {
        case "heading_1": return "# \(text)"
        case "heading_2": return "## \(text)"
        case "heading_3": return "### \(text)"
        case "bulleted_list_item": return "- \(text)"
        case "numbered_list_item": return "1. \(text)"
        case "to_do": return "- [\(checked == true ? "x" : " ")] \(text)"
        case "quote": return "> \(text)"
        case "code": return "```\(language ?? "")\n\(text)\n```"
        case "divider": return "---"
        default: return text
        }
    }
}

/// Whoever the token belongs to.
public struct User: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let name: String?
    public let type: String?
    /// The integration's name, when the token is a bot.
    public let botOwner: String?

    private enum CodingKeys: String, CodingKey { case id, name, type, bot }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? ""
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? nil
        self.type = (try? container.decodeIfPresent(String.self, forKey: .type)) ?? nil
        let bot = (try? container.decodeIfPresent(JSONValue.self, forKey: .bot)) ?? nil
        self.botOwner = bot?["owner"]?["user"]?["name"]?.string
            ?? bot?["workspace_name"]?.string
    }

    public init(id: String, name: String?, type: String? = nil, botOwner: String? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.botOwner = botOwner
    }
}

/// Timestamp parsing.
enum Timestamps {
    private static let plain = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        return (try? plain.parse(text)) ?? (try? fractional.parse(text))
    }
}

/// A page rendered to Markdown by Notion's own renderer.
public struct PageMarkdown: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let markdown: String
    /// The page was too large to render whole.
    public let truncated: Bool
    /// Blocks the renderer had no Markdown for — synced blocks, some embeds.
    /// Non-empty means the Markdown is missing something, quietly.
    public let unknownBlockIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case id, markdown, truncated
        case unknownBlockIDs = "unknown_block_ids"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(String.self, forKey: .id)) ?? ""
        self.markdown = (try? container.decode(String.self, forKey: .markdown)) ?? ""
        self.truncated = (try? container.decodeIfPresent(Bool.self, forKey: .truncated)) ?? false
        self.unknownBlockIDs = (try? container.decodeIfPresent([String].self, forKey: .unknownBlockIDs)) ?? []
    }

    public init(id: String, markdown: String, truncated: Bool = false,
                unknownBlockIDs: [String] = []) {
        self.id = id
        self.markdown = markdown
        self.truncated = truncated
        self.unknownBlockIDs = unknownBlockIDs
    }

    /// Whether the Markdown faithfully represents the page.
    public var isComplete: Bool { !truncated && unknownBlockIDs.isEmpty }
}
