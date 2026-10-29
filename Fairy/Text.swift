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

/// Слово в двух видах: norm для сопоставления, raw как сказал пользователь.
struct Token {
    let norm: String
    let raw: String
}

/// Режем по пробелам и чистим знаки только по краям слов,
/// поэтому youtube.com и ~/Downloads остаются целыми.
func tokens(_ s: String) -> [Token] {
    s.components(separatedBy: .whitespacesAndNewlines)
        .map(trimEnds)
        .filter { !$0.isEmpty }
        .map { Token(norm: normalize($0), raw: $0) }
}

func tokenize(_ s: String) -> [String] {
    tokens(s).map(\.norm)
}
