//
//  NotionError.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong talking to Notion.
public enum NotionError: Error, LocalizedError, Sendable, Equatable {
    /// No token, or one Notion rejected.
    case unauthorized(String)
    /// The integration has a token but has not been shared the page.
    ///
    /// Notion's most confusing failure: a valid token sees NOTHING until a
    /// human clicks Share on each page or database. An empty search is the
    /// usual symptom, not an error.
    case notShared(String)
    case notFound(String)
    case rateLimited(retryAfter: Int?)
    case validation(String)
    case http(Int)
    case malformed(String)
    /// An id that is not a Notion UUID.
    case badIdentifier(String)

    public var errorDescription: String? {
        switch self {
        case .unauthorized(let detail): return detail
        case .notShared(let what):
            return "\(what) — share the page with your integration in Notion first"
        case .notFound(let what): return "no such \(what)"
        case .rateLimited(let after):
            return "Notion is rate-limiting" + (after.map { " (retry after \($0)s)" } ?? "")
        case .validation(let why): return "Notion rejected the request: \(why)"
        case .http(let code): return "Notion answered HTTP \(code)"
        case .malformed(let what): return "unexpected response shape: \(what)"
        case .badIdentifier(let id): return "\(id) is not a Notion id"
        }
    }
}
