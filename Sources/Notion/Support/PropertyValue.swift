//
//  PropertyValue.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One property value, flattened to something printable.
public struct PropertyValue: Sendable, Codable, Equatable {
    /// Notion's type tag — `title`, `rich_text`, `select`, `date`…
    public let type: String
    /// The value as text, joined where Notion returns a list.
    public let text: String
    /// The numeric value, when the property is one.
    public let number: Double?
    /// Whether a checkbox is ticked.
    public let checkbox: Bool?
    /// The separate values, where the property is a list.
    public let values: [String]

    public init(type: String, text: String, number: Double? = nil,
                checkbox: Bool? = nil, values: [String] = []) {
        self.type = type
        self.text = text
        self.number = number
        self.checkbox = checkbox
        self.values = values
    }

    /// Whether the property holds nothing.
    public var isEmpty: Bool { text.isEmpty && number == nil && checkbox == nil }
}
