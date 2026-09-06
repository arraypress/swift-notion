//
//  PageMarkdown.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A page rendered to Markdown by Notion's own renderer.
public struct PageMarkdown: Sendable, Codable, Equatable, Identifiable {
    /// The Notion id — a UUID, dashed or not depending on where it came from.
    public let id: String
    /// The rendered Markdown, as Notion produced it.
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
