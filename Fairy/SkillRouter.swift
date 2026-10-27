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

        // Больше литералов → конкретнее. При ничьей — тип параметра, который реально подходит.
        var resolved: [(Candidate, [String: String], Int)] = []
        for c in candidates {
            guard let values = resolver.resolveAll(c.skill, given: c.captured) else { continue }
            resolved.append((c, values, fit(c.skill, captured: c.captured)))
        }
        resolved.sort {
            if $0.0.literals != $1.0.literals { return $0.0.literals > $1.0.literals }
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.0.order < $1.0.order
        }
        return resolved.first.map { Invocation(skill: $0.0.skill, values: $0.1) }
    }

    /// Насколько захваченный текст похож на заявленный тип параметра.
    private func fit(_ skill: Skill, captured: [String: String]) -> Int {
        var score = 0
        for (name, spec) in skill.params ?? [:] {
            let raw = captured[name] ?? ""
            let key = normalize(raw)
            switch spec.type {
            case .url:
                if resolver.aliases.sites[key] != nil || raw.contains(".") { score += 3 }
            case .folder:
                if resolver.aliases.folders[key] != nil
                    || raw.hasPrefix("~") || raw.hasPrefix("/") { score += 3 }
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
