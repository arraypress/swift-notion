//
//  User.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Whoever the token belongs to.
public struct User: Sendable, Codable, Equatable, Identifiable {
    /// The Notion id — a UUID, dashed or not depending on where it came from.
    public let id: String
    /// Their display name, or the integration's name for a bot.
    public let name: String?
    /// `person` or `bot`.
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
