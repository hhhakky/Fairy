//
//  Text.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
//
import Foundation

func normalize(_ s: String) -> String {
    s.lowercased()
        .replacingOccurrences(of: "ё", with: "е")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func tokenize(_ s: String) -> [String] {
    normalize(s)
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }
}
