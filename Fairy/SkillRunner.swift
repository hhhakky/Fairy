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

    func displayText(for inv: Invocation) -> String {
        let template = inv.skill.display
            ?? inv.skill.run.first?.joined(separator: " ")
            ?? inv.skill.id
        return fill(template, inv.values) ?? inv.skill.id
    }

    func run(_ inv: Invocation) async throws {
        for argv in inv.skill.run {
            let args = argv.compactMap { fill($0, inv.values) }
            guard args.count == argv.count,
                  let exe = findExecutable(args[0]) else {
                throw RunError(message: "команда не найдена: \(argv[0])")
            }
            try await exec(exe, Array(args.dropFirst()))
        }
    }

    private func findExecutable(_ name: String) -> String? {
        let fm = FileManager.default
        if name.hasPrefix("/") { return fm.isExecutableFile(atPath: name) ? name : nil }
        guard !name.contains("/") else { return nil }
        return searchDirs.map { "\($0)/\(name)" }.first { fm.isExecutableFile(atPath: $0) }
    }

    private func exec(_ exe: String, _ args: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: exe)
            p.arguments = args
            p.standardOutput = FileHandle.nullDevice
            let err = Pipe()
            p.standardError = err

            p.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    let data = err.fileHandleForReading.readDataToEndOfFile()
                    cont.resume(throwing: RunError(message: String(decoding: data, as: UTF8.self)))
                }
            }
            do {
                try p.run()
                // страховка: зависшая команда убивается через 15 секунд
                DispatchQueue.global().asyncAfter(deadline: .now() + 15) {
                    if p.isRunning { p.terminate() }
                }
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}
