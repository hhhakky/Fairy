//
//  SkillRunner.swift
//  Fairy
//
//  Created by Riyat Rahim on 26.10.2026.
//
import Foundation

struct SkillRunner {
    struct RunError: Error { let message: String }

    private let searchDirs = ["/usr/bin", "/bin", "/usr/sbin", "/sbin",
                              "/opt/homebrew/bin", "/usr/local/bin"]

    // MARK: - Что показать на острове

    func displayText(for inv: Invocation) -> String {
        let template = inv.skill.display?.text
            ?? inv.skill.run.first?.joined(separator: " ")
            ?? inv.skill.id
        return fill(template, inv.values) ?? inv.skill.id
    }

    /// Готовим вывод команды для острова: без ANSI-кодов, максимум 3 строки и 200 символов
    static func clean(_ raw: String) -> String {
        let noAnsi = raw.replacingOccurrences(
            of: "\u{1B}\\[[0-9;?]*[A-Za-z]", with: "", options: .regularExpression)
        let lines = noAnsi.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(3)
        var text = lines.joined(separator: "\n")
        if text.count > 200 { text = String(text.prefix(200)) + "…" }
        return text
    }

    // MARK: - Запуск

    /// Выполняет команды навыка по порядку и возвращает stdout последней,
    /// но только если у навыка "output": "show"
    func run(_ inv: Invocation) async throws -> String {
        let timeout = TimeInterval(min(max(inv.skill.timeout ?? 15, 1), 120))
        let last = inv.skill.run.count - 1
        var output = ""

        for (i, argv) in inv.skill.run.enumerated() {
            let args = argv.compactMap { fill($0, inv.values) }
            guard args.count == argv.count else {
                throw RunError(message: "не удалось подставить параметры")
            }
            let (exe, exeArgs) = try resolve(args)
            let capture = inv.skill.output == .show && i == last
            let out = try await exec(exe, exeArgs, timeout: timeout, capture: capture)
            if capture { output = out }
        }
        return output
    }

    /// Если первый элемент оканчивается на .sh, запускаем скрипт через его интерпретатор
    private func resolve(_ args: [String]) throws -> (String, [String]) {
        let name = args[0]
        if name.lowercased().hasSuffix(".sh") {
            let path = try scriptPath(name)
            return (interpreter(for: path), [path] + args.dropFirst())
        }
        guard let exe = findExecutable(name) else {
            throw RunError(message: "команда не найдена: \(name)")
        }
        return (exe, Array(args.dropFirst()))
    }

    /// "weather.sh" ищется в папке skills/scripts, абсолютные пути и ~/ берутся как есть
    private func scriptPath(_ name: String) throws -> String {
        var path: String
        if name.hasPrefix("/") || name.hasPrefix("~") {
            path = (name as NSString).expandingTildeInPath
        } else {
            guard !name.contains("..") else { throw RunError(message: "недопустимый путь скрипта") }
            path = Storage.scriptsDir.appendingPathComponent(name).path
        }
        path = (path as NSString).standardizingPath
        guard FileManager.default.isReadableFile(atPath: path) else {
            throw RunError(message: "скрипт не найден: \(name)")
        }
        return path
    }

    /// Смотрим на первую строку (#!/bin/bash и т.п.). chmod +x не нужен.
    private func interpreter(for path: String) -> String {
        guard let h = FileHandle(forReadingAtPath: path) else { return "/bin/zsh" }
        defer { try? h.close() }
        let head = String(decoding: (try? h.read(upToCount: 120)) ?? Data(), as: UTF8.self)
        let first = head.components(separatedBy: .newlines).first ?? ""
        if first.hasPrefix("#!") {
            if first.contains("bash") { return "/bin/bash" }
            if first.contains("zsh") { return "/bin/zsh" }
            if first.hasSuffix("/sh") || first.hasSuffix(" sh") { return "/bin/sh" }
        }
        return "/bin/zsh"
    }

    private func findExecutable(_ name: String) -> String? {
        let fm = FileManager.default
        if name.hasPrefix("/") { return fm.isExecutableFile(atPath: name) ? name : nil }
        guard !name.contains("/") else { return nil }
        return searchDirs.map { "\($0)/\(name)" }.first { fm.isExecutableFile(atPath: $0) }
    }

    /// У приложения из Dock/Xcode урезанный PATH: добавляем Homebrew
    private func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin"
        env["PATH"] = extra + ":" + (env["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        if env["LANG"] == nil { env["LANG"] = "en_US.UTF-8" }
        return env
    }

    // MARK: - Процесс

    private func exec(_ exe: String, _ args: [String],
                      timeout: TimeInterval, capture: Bool) async throws -> String {
        // Вывод пишем во временные файлы: так процесс не может зависнуть на заполненном канале
        let outURL = Self.makeTemp("out")
        let errURL = Self.makeTemp("err")

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exe)
            p.arguments = args
            p.environment = environment()
            p.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())

            guard let errHandle = try? FileHandle(forWritingTo: errURL) else {
                cont.resume(throwing: RunError(message: "не удалось создать временный файл"))
                return
            }
            var outHandle: FileHandle?
            if capture {
                outHandle = try? FileHandle(forWritingTo: outURL)
                p.standardOutput = outHandle ?? FileHandle.nullDevice
            } else {
                p.standardOutput = FileHandle.nullDevice
            }
            p.standardError = errHandle

            p.terminationHandler = { proc in
                let out = capture ? Self.readCapped(outURL) : ""
                let err = Self.readCapped(errURL)
                try? FileManager.default.removeItem(at: outURL)
                try? FileManager.default.removeItem(at: errURL)

                if proc.terminationReason == .uncaughtSignal && proc.terminationStatus == SIGTERM {
                    cont.resume(throwing: RunError(message: "таймаут \(Int(timeout)) с"))
                } else if proc.terminationStatus == 0 {
                    cont.resume(returning: out)
                } else {
                    let line = err.components(separatedBy: .newlines)
                        .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
                    let msg = line.isEmpty ? "код выхода \(proc.terminationStatus)" : line
                    cont.resume(throwing: RunError(message: msg))
                }
            }

            do {
                try p.run()
                try? errHandle.close()
                try? outHandle?.close()
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if p.isRunning { p.terminate() }
                }
            } catch {
                try? errHandle.close()
                try? outHandle?.close()
                try? FileManager.default.removeItem(at: outURL)
                try? FileManager.default.removeItem(at: errURL)
                cont.resume(throwing: error)
            }
        }
    }

    private static func makeTemp(_ ext: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("fairy-\(UUID().uuidString).\(ext)")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return url
    }

    private static func readCapped(_ url: URL) -> String {
        guard let h = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? h.close() }
        let data = (try? h.read(upToCount: 64_000)) ?? Data()
        return String(decoding: data, as: UTF8.self)
    }
}
