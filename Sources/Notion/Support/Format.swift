//
//  Format.swift
//  Notion
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Number formatting shared by the property readers.
enum Format {
    static func number(_ value: Double) -> String {
        value == value.rounded() && abs(value) < 1e15
            ? String(Int64(value))
            : String(format: "%g", value)
    }
}
