//
//  Notion.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//
//  Notion with a token, not OAuth.
//
//  An INTERNAL INTEGRATION token is just an API key: made in two minutes at
//  Settings → Connections → Develop, no OAuth flow, no review, no server. That
//  is what makes this fit a command-line tool at all. OAuth is only needed
//  when each user connects their own workspace without pasting anything —
//  a consumer app's problem, not a CLI's.
//
//  THE GOTCHA THAT CATCHES EVERYONE: a perfectly valid token sees NOTHING
//  until a human opens each page and shares it with the integration
//  (⋯ → Connections). An empty search is the normal symptom, so this library
//  says so rather than returning a bare empty list.
//

import Foundation

/// A client for the Notion API.
public struct Notion: Sendable {

    /// How requests are performed — injectable so tests run on recordings.
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    /// The API version this library speaks.
    ///
    /// Notion REQUIRES this header on every request and pins behaviour to it,
    /// so it is a constant here rather than "latest" — an unannounced change
    /// to the response shape is not something a caller should discover in
    /// production.
    public static let apiVersion = "2022-06-28"
    public static let defaultHost = "api.notion.com"

    /// The most rows Notion returns in one page.
    public static let maximumPageSize = 100

    private let token: String
    private let host: String
    private let transport: Transport

    /// A client.
    ///
    /// - Parameter token: An internal integration secret (`ntn_…`) or an
    ///   OAuth access token. Both are bearer tokens; this does not care which.
    public init(token: String, host: String = Notion.defaultHost, transport: Transport? = nil) {
        self.token = token
        self.host = host
        self.transport = transport ?? { request in
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw NotionError.malformed("not an HTTP response")
            }
            return (data, http)
        }
    }

    // MARK: - Identity

    /// Who the token belongs to. The cheapest way to prove one works.
    public func me() async throws -> User {
        let data = try await request("GET", "/v1/users/me")
        return try decode(User.self, from: data)
    }

    // MARK: - Search

    /// Pages and databases the integration can see.
    ///
    /// - Parameters:
    ///   - query: Free text over titles. Empty lists everything shared.
    ///   - kind: Restrict to pages or databases.
    ///   - limit: How many, 1–100.
    /// - Throws: ``NotionError/notShared(_:)`` when the token is valid but
    ///   nothing has been shared with it — otherwise this looks like an empty
    ///   workspace.
    public func search(_ query: String = "", kind: Kind? = nil,
                       limit: Int = 25) async throws -> SearchResults {
        var body: [String: JSONValue] = [
            "page_size": .number(Double(min(max(limit, 1), Notion.maximumPageSize))),
        ]
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            body["query"] = .string(query)
        }
        if let kind {
            body["filter"] = .object(["property": .string("object"), "value": .string(kind.rawValue)])
        }
        let data = try await request("POST", "/v1/search", body: .object(body))
        let results = try decodeResults(from: data)
        guard !results.isEmpty else {
            throw NotionError.notShared("the integration can see nothing")
        }
        return results
    }

    /// What a search can be narrowed to.
    public enum Kind: String, Sendable, CaseIterable {
        case page
        case database
    }

    // MARK: - Pages

    /// One page's properties.
    public func page(_ identifier: String) async throws -> Page {
        let id = try Notion.identifier(identifier)
        let data = try await request("GET", "/v1/pages/\(id)")
        return try decode(Page.self, from: data)
    }

    /// A page's content, as blocks.
    ///
    /// One level deep: a nested list's children are reported by
    /// ``Block/hasChildren`` rather than fetched, because doing so silently
    /// would turn one call into dozens.
    public func blocks(_ identifier: String, limit: Int = Notion.maximumPageSize) async throws -> [Block] {
        let id = try Notion.identifier(identifier)
        let data = try await request(
            "GET", "/v1/blocks/\(id)/children",
            query: ["page_size": String(min(max(limit, 1), Notion.maximumPageSize))]
        )
        struct Response: Decodable { let results: [Block]? }
        return try decode(Response.self, from: data).results ?? []
    }

    /// A page's content as Markdown.
    public func markdown(_ identifier: String) async throws -> String {
        try await blocks(identifier)
            .map(\.markdown)
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    // MARK: - Databases

    /// A database's schema.
    public func database(_ identifier: String) async throws -> Database {
        let id = try Notion.identifier(identifier)
        let data = try await request("GET", "/v1/databases/\(id)")
        return try decode(Database.self, from: data)
    }

    /// A database's rows.
    ///
    /// - Parameter sortBy: A column name to sort on.
    /// - Parameter descending: Largest or latest first.
    public func rows(_ identifier: String, sortBy: String? = nil, descending: Bool = false,
                     limit: Int = 25) async throws -> [Page] {
        let id = try Notion.identifier(identifier)
        var body: [String: JSONValue] = [
            "page_size": .number(Double(min(max(limit, 1), Notion.maximumPageSize))),
        ]
        if let sortBy {
            body["sorts"] = .array([.object([
                "property": .string(sortBy),
                "direction": .string(descending ? "descending" : "ascending"),
            ])])
        }
        let data = try await request("POST", "/v1/databases/\(id)/query", body: .object(body))
        struct Response: Decodable { let results: [Page]? }
        return try decode(Response.self, from: data).results ?? []
    }

    // MARK: - Writing

    /// Creates a page under a parent page, with optional Markdown-ish body.
    ///
    /// Only paragraphs and headings are written: Notion's block model is far
    /// larger, and a partial Markdown converter that silently drops tables
    /// would be worse than one that states its scope.
    public func createPage(parent: String, title: String,
                           paragraphs: [String] = []) async throws -> Page {
        let parentID = try Notion.identifier(parent)
        var body: [String: JSONValue] = [
            "parent": .object(["page_id": .string(parentID)]),
            "properties": .object([
                "title": .object(["title": .array([
                    .object(["text": .object(["content": .string(title)])]),
                ])]),
            ]),
        ]
        if !paragraphs.isEmpty {
            body["children"] = .array(paragraphs.map { text in
                .object([
                    "object": .string("block"),
                    "type": .string("paragraph"),
                    "paragraph": .object(["rich_text": .array([
                        .object(["type": .string("text"),
                                 "text": .object(["content": .string(text)])]),
                    ])]),
                ])
            })
        }
        let data = try await request("POST", "/v1/pages", body: .object(body))
        return try decode(Page.self, from: data)
    }

    /// Appends paragraphs to an existing page.
    public func append(to identifier: String, paragraphs: [String]) async throws -> [Block] {
        guard !paragraphs.isEmpty else { return [] }
        let id = try Notion.identifier(identifier)
        let body = JSONValue.object([
            "children": .array(paragraphs.map { text in
                .object([
                    "object": .string("block"),
                    "type": .string("paragraph"),
                    "paragraph": .object(["rich_text": .array([
                        .object(["type": .string("text"),
                                 "text": .object(["content": .string(text)])]),
                    ])]),
                ])
            }),
        ])
        let data = try await request("PATCH", "/v1/blocks/\(id)/children", body: body)
        struct Response: Decodable { let results: [Block]? }
        return try decode(Response.self, from: data).results ?? []
    }

    // MARK: - Identifiers

    /// Reads a Notion id from an id or a URL.
    public static func identifier(_ text: String) throws -> String {
        guard let id = Identifier.parse(text) else {
            throw NotionError.badIdentifier(text)
        }
        return id
    }

    // MARK: - Transport

    private func request(_ method: String, _ path: String,
                         query: [String: String] = [:],
                         body: JSONValue? = nil) async throws -> Data {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
                .sorted { $0.name < $1.name }
        }
        guard let url = components.url else {
            throw NotionError.malformed("could not build a URL for \(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Required on every request; Notion refuses without it.
        request.setValue(Notion.apiVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONEncoder().encode(body)
        }

        let (data, response) = try await transport(request)
        switch response.statusCode {
        case 200...299:
            return data
        case 401:
            throw NotionError.unauthorized(Notion.message(in: data)
                ?? "Notion rejected the token")
        case 404:
            // Notion answers 404 for "does not exist" AND for "exists but is
            // not shared with you" — indistinguishable, and the second is far
            // more likely, so the message says both.
            throw NotionError.notShared(Notion.message(in: data)
                ?? "not found, or not shared with the integration")
        case 429:
            let after = response.value(forHTTPHeaderField: "Retry-After").flatMap { Int(Double($0) ?? 0) }
            throw NotionError.rateLimited(retryAfter: after)
        case 400:
            throw NotionError.validation(Notion.message(in: data) ?? "bad request")
        default:
            throw NotionError.http(response.statusCode)
        }
    }

    /// Notion's own error message, which is usually the useful part.
    private static func message(in data: Data) -> String? {
        guard let value = try? JSONDecoder().decode(JSONValue.self, from: data) else { return nil }
        return value["message"]?.string
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NotionError.malformed(error.localizedDescription)
        }
    }

    /// Search returns pages and databases mixed in one array, told apart by
    /// an `object` field. Splitting them is friendlier than making every
    /// caller do it.
    private func decodeResults(from data: Data) throws -> SearchResults {
        struct Row: Decodable { let object: String? }
        struct Envelope: Decodable { let results: [JSONValue]? }

        let envelope = try decode(Envelope.self, from: data)
        var pages: [Page] = []
        var databases: [Database] = []
        let encoder = JSONEncoder()

        for value in envelope.results ?? [] {
            guard let kind = value["object"]?.string, let raw = try? encoder.encode(value) else { continue }
            switch kind {
            case "page": if let page = try? JSONDecoder().decode(Page.self, from: raw) { pages.append(page) }
            case "database": if let db = try? JSONDecoder().decode(Database.self, from: raw) { databases.append(db) }
            default: break
            }
        }
        return SearchResults(pages: pages, databases: databases)
    }
}

/// What a search found.
public struct SearchResults: Sendable, Codable, Equatable {
    public let pages: [Page]
    public let databases: [Database]

    public var isEmpty: Bool { pages.isEmpty && databases.isEmpty }
    public var count: Int { pages.count + databases.count }

    public init(pages: [Page], databases: [Database]) {
        self.pages = pages
        self.databases = databases
    }
}
