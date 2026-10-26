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

private let leadingChars: Set<Character> = Set("\"'«»“”„‘’([{<")
private let trailingChars: Set<Character> = Set("\"'«»“”„‘’)]}>.,!?;:…%")

private func trimEnds(_ s: String) -> String {
    var t = Substring(s)
    while let f = t.first, leadingChars.contains(f) { t = t.dropFirst() }
    while let l = t.last, trailingChars.contains(l) { t = t.dropLast() }
    return String(t)
}

/// Режем по пробелам и чистим знаки только по краям слов,
/// поэтому youtube.com и ~/Downloads остаются целыми.
func tokenize(_ s: String) -> [String] {
    normalize(s)
        .components(separatedBy: .whitespacesAndNewlines)
        .map(trimEnds)
        .filter { !$0.isEmpty }
}
