//
//  Timestamps.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Timestamp parsing.
enum Timestamps {
    private static let plain = Date.ISO8601FormatStyle(includingFractionalSeconds: false)
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)

    static func parse(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        return (try? plain.parse(text)) ?? (try? fractional.parse(text))
    }
}
