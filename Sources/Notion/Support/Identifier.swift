//
//  Identifier.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//
//  Notion ids are UUIDs, and they arrive in three forms: dashed in API
//  responses, UNDASHED in the URLs people copy from the app, and buried at the
//  end of a share link after a slug. All three have to be accepted, because
//  the one a caller has to hand is almost always the URL.
//

import Foundation

/// Reading a Notion id from whatever the caller pasted.
enum Identifier {

    /// A dashed UUID, or `nil` if there is no id in `text`.
    ///
    /// Accepts:
    ///   `2f8e1c...`                       — undashed, as copied from a URL
    ///   `2f8e1c0d-...-...`                — dashed, as the API returns it
    ///   `https://notion.so/Page-Title-2f8e...` — a share link
    static func parse(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // The last path component of a URL, minus any query.
        let tail = trimmed
            .split(separator: "/").last.map(String.init)?
            .split(separator: "?").first.map(String.init) ?? trimmed

        // A slug is "Some-Title-<32 hex>", so take the trailing hex run.
        let hex = tail.split(separator: "-").last.map(String.init) ?? tail
        let candidate = hex.filter(\.isHexDigit)

        guard candidate.count == 32 else {
            // Already dashed?
            let stripped = tail.replacingOccurrences(of: "-", with: "")
            guard stripped.count == 32, stripped.allSatisfy(\.isHexDigit) else { return nil }
            return dashed(stripped)
        }
        return dashed(candidate)
    }

    /// 8-4-4-4-12.
    static func dashed(_ hex: String) -> String {
        let characters = Array(hex.lowercased())
        guard characters.count == 32 else { return hex }
        let groups = [8, 4, 4, 4, 12]
        var index = 0
        return groups.map { length -> String in
            defer { index += length }
            return String(characters[index..<(index + length)])
        }.joined(separator: "-")
    }
}
