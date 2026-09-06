//
//  Block.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One block of page content, flattened to text.
public struct Block: Sendable, Codable, Equatable, Identifiable {
    /// The Notion id — a UUID, dashed or not depending on where it came from.
    public let id: String
    /// `paragraph`, `heading_1`, `bulleted_list_item`, `code`, `to_do`…
    public let type: String
    /// The block's rich text flattened to plain text.
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
