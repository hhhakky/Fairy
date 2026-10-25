//
//  Executor.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
//
import Foundation

struct Executor {
    struct ShellError: Error { let message: String }

    func run(_ action: FairyAction) async throws {
        switch action {
        case .openApp(let name):
            try await shell("/usr/bin/open", ["-a", name])
        case .quitApp(let name):
            try await shell("/usr/bin/osascript", ["-e", "tell application \"\(name)\" to quit"])
        case .setVolume(let v):
            try await shell("/usr/bin/osascript", ["-e", "set volume output volume \(v)"])
        case .mute(let m):
            try await shell("/usr/bin/osascript", ["-e", "set volume output muted \(m)"])
        }
    }

    private func shell(_ path: String, _ args: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            let errPipe = Pipe()
            process.standardError = errPipe

            process.terminationHandler = { p in
                if p.terminationStatus == 0 {
                    cont.resume()
                } else {
                    let data = errPipe.fileHandleForReading.readDataToEndOfFile()
                    cont.resume(throwing: ShellError(message: String(decoding: data, as: UTF8.self)))
                }
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
    }
}
