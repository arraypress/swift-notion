//
//  SearchResults.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What a search found.
public struct SearchResults: Sendable, Codable, Equatable {
    /// The pages that matched.
    public let pages: [Page]
    /// The databases that matched.
    public let databases: [Database]

    /// Whether nothing matched.
    ///
    /// An empty result is the normal symptom of a valid token that has not been
    /// shared with any page — see ``Notion`` for why.
    public var isEmpty: Bool { pages.isEmpty && databases.isEmpty }
    /// How many things matched, of both kinds.
    public var count: Int { pages.count + databases.count }

    public init(pages: [Page], databases: [Database]) {
        self.pages = pages
        self.databases = databases
    }
}
