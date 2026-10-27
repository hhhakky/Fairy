//
//  SkillRouter.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import Foundation

struct Invocation {
    let skill: Skill
    let values: [String: String]
}

private enum PatToken {
    case lit(String)
    case param(String)
}

private func parsePattern(_ string: String) -> [PatToken] {
    string.components(separatedBy: .whitespaces)
        .filter { !$0.isEmpty }
        .map { word in
            if word.hasPrefix("{"), word.hasSuffix("}"), word.count > 2 {
                return .param(String(word.dropFirst().dropLast()))
            }
            return .lit(normalize(word))
        }
}

/// Сопоставляет шаблон с фразой. Параметр в фигурных скобках захватывает одно или несколько слов.
private func match(
    _ pattern: ArraySlice<PatToken>,
    _ input: ArraySlice<String>,
    _ captured: [String: String]
) -> [String: String]? {
    guard let first = pattern.first else { return input.isEmpty ? captured : nil }

    switch first {
    case .lit(let word):
        guard input.first == word else { return nil }
        return match(pattern.dropFirst(), input.dropFirst(), captured)

    case .param(let name):
        guard !input.isEmpty else { return nil }
        let remainingPattern = pattern.dropFirst()
        for count in 1...input.count {
            if remainingPattern.isEmpty && count != input.count { continue }
            var nextCaptured = captured
            nextCaptured[name] = input.prefix(count).joined(separator: " ")
            if let result = match(remainingPattern, input.dropFirst(count), nextCaptured) {
                return result
            }
        }
        return nil
    }
}

struct SkillRouter {
    let skills: [Skill]
    let resolver: ParamResolver

    /// Слова-вежливость выбрасываются везде.
    private let polite: Set<String> = [
        "фея", "fairy", "пожалуйста", "плиз", "please", "мне", "ну", "эй", "слушай",
        "давай", "быстро", "сейчас", "потом", "затем", "можешь", "можно", "ты", "бы", "будь", "добр", "ка"
    ]

    private let separators = [" и потом ", " и затем ", " а затем ", " после этого ", " затем ", " потом ", " и "]

    private struct Candidate {
        let skill: Skill
        let captured: [String: String]
        let literalCount: Int
        let order: Int
    }

    func route(_ raw: String) -> Invocation? {
        var tokens = tokenize(raw).filter { !polite.contains($0) }
        guard !tokens.isEmpty else { return nil }
        // Russian infinitive wording is common in text requests ("открыть сайт").
        // Normalize only the leading action so existing user-edited skill files still match.
        if tokens.first == "открыть" { tokens[0] = "открой" }

        var candidates: [Candidate] = []
        var order = 0
        for skill in skills {
            for trigger in skill.triggers ?? [] {
                order += 1
                let pattern = parsePattern(trigger)
                guard !pattern.isEmpty,
                      let captured = match(pattern[...], tokens[...], [:]) else { continue }
                let literalCount = pattern.reduce(into: 0) { count, token in
                    if case .lit = token { count += 1 }
                }
                candidates.append(Candidate(
                    skill: skill,
                    captured: captured,
                    literalCount: literalCount,
                    order: order
                ))
            }
        }

        // Сначала конкретность шаблона, затем соответствие захваченного значения его типу.
        let resolved = candidates.compactMap { candidate -> (Candidate, [String: String], Int)? in
            guard let values = resolver.resolveAll(candidate.skill, given: candidate.captured) else {
                return nil
            }
            return (candidate, values, fit(candidate.skill, captured: candidate.captured))
        }
        let best = resolved.sorted { lhs, rhs in
            if lhs.0.literalCount != rhs.0.literalCount {
                return lhs.0.literalCount > rhs.0.literalCount
            }
            if lhs.2 != rhs.2 {
                return lhs.2 > rhs.2
            }
            return lhs.0.order < rhs.0.order
        }.first

        return best.map { Invocation(skill: $0.0.skill, values: $0.1) }
    }

    /// Splits a request only when every resulting phrase maps to a valid skill.
    /// Trying splits before a broad query trigger preserves ordinary text such as "Tom and Jerry".
    func routeSequence(_ raw: String) -> [Invocation]? {
        routeSequence(raw, depth: 0)
    }

    private func routeSequence(_ raw: String, depth: Int) -> [Invocation]? {
        guard depth < 5 else { return nil }
        let text = normalize(raw)
        for (range, _) in splitRanges(in: text) {
            let leftText = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rightText = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !leftText.isEmpty, !rightText.isEmpty,
                  let left = routeSequence(leftText, depth: depth + 1),
                  let right = routeSequence(rightText, depth: depth + 1),
                  left.count + right.count <= 5 else { continue }
            return left + right
        }

        guard let invocation = route(text) else { return nil }
        return [invocation]
    }

    private func splitRanges(in text: String) -> [(Range<String.Index>, String)] {
        var ranges: [(Range<String.Index>, String)] = []
        for separator in separators {
            var searchStart = text.startIndex
            while searchStart < text.endIndex,
                  let range = text.range(of: separator, range: searchStart..<text.endIndex) {
                ranges.append((range, separator))
                searchStart = range.upperBound
            }
        }
        return ranges.sorted { lhs, rhs in
            if lhs.0.lowerBound != rhs.0.lowerBound { return lhs.0.lowerBound < rhs.0.lowerBound }
            return lhs.1.count > rhs.1.count
        }
    }

    /// Насколько захваченный текст похож на значение заявленного типа параметра.
    private func fit(_ skill: Skill, captured: [String: String]) -> Int {
        var score = 0
        for (name, spec) in skill.params ?? [:] {
            let raw = captured[name] ?? ""
            let key = normalize(raw)
            switch spec.type {
            case .url:
                if resolver.aliases.sites[key] != nil || raw.contains(".") {
                    score += 3
                } else {
                    score += resolver.sites.matchQuality(raw)
                }
            case .folder:
                if resolver.aliases.folders[key] != nil || raw.hasPrefix("~") || raw.hasPrefix("/") {
                    score += 3
                }
            case .app:
                let appName = resolver.aliases.apps[key] ?? key
                score += resolver.catalog.matchQuality(appName)
            default:
                score += 1
            }
        }
        return score
    }
}
