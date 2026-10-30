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

/// Сопоставляет шаблон с фразой по нормализованным словам,
/// а в параметры забирает слова в том виде, как их сказали.
private func match(
    _ pattern: ArraySlice<PatToken>,
    _ input: ArraySlice<Token>,
    _ captured: [String: String]
) -> [String: String]? {
    guard let first = pattern.first else { return input.isEmpty ? captured : nil }

    switch first {
    case .lit(let word):
        guard input.first?.norm == word else { return nil }
        return match(pattern.dropFirst(), input.dropFirst(), captured)

    case .param(let name):
        guard !input.isEmpty else { return nil }
        let remaining = pattern.dropFirst()
        // Последний параметр обязан забрать всё, что осталось
        let counts = remaining.isEmpty ? input.count...input.count : 1...input.count
        for count in counts {
            var next = captured
            next[name] = input.prefix(count).map(\.raw).joined(separator: " ")
            if let result = match(remaining, input.dropFirst(count), next) {
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
        "давай", "быстро", "сейчас", "потом", "затем", "можешь", "можно", "ты", "бы", "будь", "добр", "ка",
        "сначала", "сперва", "дальше", "далее", "ещё", "еще"
    ]

    private let separators: [[String]] = [
        ["и", "потом"], ["и", "затем"], ["а", "потом"], ["а", "затем"],
        ["и", "после", "этого"], ["после", "этого"], ["после", "чего"],
        ["и", "далее"], ["и", "дальше"],
        ["затем"], ["потом"], ["далее"], ["дальше"], ["и"]
    ]
    private let maxCommands = 5
    private let maxSeparators = 12

    private struct Entry {
        let skill: Skill
        let pattern: [PatToken]
        let literals: Int
        let order: Int
    }
    private let entries: [Entry]

    init(skills: [Skill], resolver: ParamResolver) {
        self.skills = skills
        self.resolver = resolver

        var list: [Entry] = []
        var order = 0
        for skill in skills {
            for trigger in skill.triggers ?? [] {
                order += 1
                let pattern = parsePattern(trigger)
                guard !pattern.isEmpty else { continue }
                let literals = pattern.reduce(into: 0) { count, token in
                    if case .lit = token { count += 1 }
                }
                list.append(Entry(skill: skill, pattern: pattern, literals: literals, order: order))
            }
        }
        entries = list
    }

    // MARK: - Одна команда

    func route(_ raw: String) -> Invocation? {
        route(tokens(raw)[...])
    }

    private func route(_ all: ArraySlice<Token>) -> Invocation? {
        var input = all.filter { !polite.contains($0.norm) }
        guard !input.isEmpty else { return nil }
        // Инфинитив ("открыть сайт") приводим к повелительному, только первое слово
        if input[0].norm == "открыть" {
            input[0] = Token(norm: "открой", raw: input[0].raw)
        }

        // Сначала конкретность шаблона, затем соответствие значения типу параметра, затем порядок
        var best: (inv: Invocation, literals: Int, fit: Int, order: Int)?
        for entry in entries {
            if let b = best, entry.literals < b.literals { continue }
            guard let captured = match(entry.pattern[...], input[...], [:]),
                  let values = resolver.resolveAll(entry.skill, given: captured) else { continue }

            let candidate = (inv: Invocation(skill: entry.skill, values: values),
                             literals: entry.literals,
                             fit: fit(entry.skill, captured: captured),
                             order: entry.order)
            if let b = best {
                let better: Bool
                if candidate.literals != b.literals {
                    better = candidate.literals > b.literals
                } else if candidate.fit != b.fit {
                    better = candidate.fit > b.fit
                } else {
                    better = candidate.order < b.order
                }
                if better { best = candidate }
            } else {
                best = candidate
            }
        }
        return best?.inv
    }

    // MARK: - Цепочка команд

    /// Делит фразу на команды, только если каждая часть распознаётся как навык.
    /// Разбиения пробуются раньше цельной фразы, чтобы "Том и Джерри" в поиске остался целым.
    func routeSequence(_ raw: String) -> [Invocation]? {
        let all = tokens(raw)
        guard !all.isEmpty else { return nil }

        let spans = separatorSpans(in: all)
        if spans.count > maxSeparators {
            return route(all[...]).map { [$0] }
        }

        // solve(i) = лучший разбор хвоста, начиная со слова i. Каждый хвост считается один раз.
        var memo: [Int: [Invocation]?] = [:]

        func solve(_ start: Int) -> [Invocation]? {
            if let cached = memo[start] { return cached }

            var result: [Invocation]?
            for span in spans where span.lower > start {
                guard let left = route(all[start..<span.lower]),
                      let rest = solve(span.upper),
                      rest.count + 1 <= maxCommands else { continue }
                result = [left] + rest
                break
            }
            if result == nil, let whole = route(all[start...]) {
                result = [whole]
            }
            memo[start] = .some(result)
            return result
        }

        return solve(0)
    }

    private func separatorSpans(in all: [Token]) -> [(lower: Int, upper: Int)] {
        var spans: [(lower: Int, upper: Int)] = []
        for i in all.indices {
            for sep in separators where i + sep.count <= all.count {
                if (0..<sep.count).allSatisfy({ all[i + $0].norm == sep[$0] }) {
                    spans.append((lower: i, upper: i + sep.count))
                }
            }
        }
        // На одной позиции сначала длинный разделитель
        return spans.sorted {
            $0.lower != $1.lower ? $0.lower < $1.lower : $0.upper > $1.upper
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
