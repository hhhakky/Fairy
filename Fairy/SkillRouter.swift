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

private func parsePattern(_ s: String) -> [PatToken] {
    s.components(separatedBy: .whitespaces)
        .filter { !$0.isEmpty }
        .map { w in
            if w.hasPrefix("{"), w.hasSuffix("}"), w.count > 2 {
                return .param(String(w.dropFirst().dropLast()))
            }
            return .lit(normalize(w))
        }
}

/// Сопоставляет шаблон с фразой. {параметр} забирает одно или несколько слов.
private func match(_ pat: ArraySlice<PatToken>, _ inp: ArraySlice<String>,
                   _ got: [String: String]) -> [String: String]? {
    guard let first = pat.first else { return inp.isEmpty ? got : nil }
    switch first {
    case .lit(let word):
        guard inp.first == word else { return nil }
        return match(pat.dropFirst(), inp.dropFirst(), got)
    case .param(let name):
        guard !inp.isEmpty else { return nil }
        let rest = pat.dropFirst()
        for n in 1...inp.count {
            if rest.isEmpty && n != inp.count { continue }
            var g = got
            g[name] = inp.prefix(n).joined(separator: " ")
            if let r = match(rest, inp.dropFirst(n), g) { return r }
        }
        return nil
    }
}

struct SkillRouter {
    let skills: [Skill]
    let resolver: ParamResolver

    /// Слова-вежливость выбрасываются везде
    private let polite: Set<String> = [
        "фея", "fairy", "пожалуйста", "плиз", "please", "мне", "ну", "эй", "слушай",
        "давай", "быстро", "сейчас", "можешь", "можно", "ты", "бы", "будь", "добр", "ка"
    ]

    private struct Candidate {
        let skill: Skill
        let captured: [String: String]
        let literals: Int
        let order: Int
    }

    func route(_ raw: String) -> Invocation? {
        let tokens = tokenize(raw).filter { !polite.contains($0) }
        guard !tokens.isEmpty else { return nil }

        var candidates: [Candidate] = []
        var order = 0
        for skill in skills {
            for trigger in skill.triggers ?? [] {
                order += 1
                let pat = parsePattern(trigger)
                guard !pat.isEmpty,
                      let caps = match(pat[...], tokens[...], [:]) else { continue }
                let literals = pat.filter { if case .lit = $0 { return true } else { return false } }.count
                candidates.append(Candidate(skill: skill, captured: caps, literals: literals, order: order))
            }
        }

        // Чем больше в шаблоне точных слов, тем он конкретнее
        let sorted = candidates.sorted { ($0.literals, -$0.order) > ($1.literals, -$1.order) }
        for c in sorted {
            if let values = resolver.resolveAll(c.skill, given: c.captured) {
                return Invocation(skill: c.skill, values: values)
            }
        }
        return nil
    }
}
