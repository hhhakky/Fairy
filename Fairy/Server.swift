//
//  Server.swift
//  Fairy
//
//  Created by Riyat Rahim on 25.10.2026.
//
import Foundation
import Network
import Security

enum ServerToken {
    static func loadOrCreate() -> String {
        if let t = Keychain.load(account: "server-token") { return t }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        Keychain.save(token, account: "server-token")
        return token
    }
}

final class CommandServer {
    private struct Request {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data
    }
    private enum Parsed { case needMore, bad, request(Request) }

    private var listener: NWListener?
    private let token: String
    private let onCommand: @Sendable (String) -> Void
    private let queue = DispatchQueue(label: "fairy.server")
    private let maxSize = 8192

    init(token: String, onCommand: @escaping @Sendable (String) -> Void) {
        self.token = token
        self.onCommand = onCommand
    }
    func start(port: UInt16, onState: @escaping @Sendable (NWListener.State) -> Void) throws {
        let l = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        l.newConnectionHandler = { [weak self] conn in self?.handle(conn) }
        l.stateUpdateHandler = onState
        l.start(queue: queue)
        listener = l
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }
    
    // MARK: - Соединение

    private func handle(_ conn: NWConnection) {
        conn.start(queue: queue)
        receive(conn, buffer: Data())
    }

    private func receive(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if error != nil { conn.cancel(); return }

            var buf = buffer
            if let data { buf.append(data) }
            if buf.count > self.maxSize { self.respond(conn, 413, "too large"); return }

            switch self.parse(buf) {
            case .needMore:
                if isComplete { conn.cancel() } else { self.receive(conn, buffer: buf) }
            case .bad:
                self.respond(conn, 400, "bad request")
            case .request(let req):
                self.process(req, conn)
            }
        }
    }

    // MARK: - Разбор HTTP

    private func parse(_ data: Data) -> Parsed {
        guard let sep = data.range(of: Data("\r\n\r\n".utf8)) else { return .needMore }
        guard let head = String(data: data[..<sep.lowerBound], encoding: .utf8) else { return .bad }

        var lines = head.components(separatedBy: "\r\n")
        let first = lines.removeFirst().split(separator: " ")
        guard first.count >= 2 else { return .bad }

        var headers: [String: String] = [:]
        for line in lines {
            guard let i = line.firstIndex(of: ":") else { continue }
            let name = line[..<i].lowercased()
            let value = line[line.index(after: i)...].trimmingCharacters(in: .whitespaces)
            headers[name] = value
        }

        let length = Int(headers["content-length"] ?? "0") ?? 0
        if length < 0 || length > maxSize { return .bad }

        let body = data[sep.upperBound...]
        if body.count < length { return .needMore }

        return .request(Request(method: String(first[0]),
                                path: String(first[1]),
                                headers: headers,
                                body: Data(body.prefix(length))))
    }

    // MARK: - Обработка

    private func process(_ req: Request, _ conn: NWConnection) {
        guard req.method == "POST", req.path == "/command" else {
            respond(conn, 404, "not found"); return
        }
        guard authorized(req.headers["authorization"]) else {
            respond(conn, 401, "unauthorized"); return
        }
        guard let text = extractText(req.body), !text.isEmpty, text.count <= 500 else {
            respond(conn, 400, "no text"); return
        }
        onCommand(text)
        respond(conn, 200, "ok")
    }

    /// Сравнение без утечки по времени
    private func authorized(_ header: String?) -> Bool {
        guard let header else { return false }
        let a = Array(header.utf8)
        let b = Array("Bearer \(token)".utf8)
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count { diff |= a[i] ^ b[i] }
        return diff == 0
    }

    private func extractText(_ body: Data) -> String? {
        if let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
           let t = obj["text"] as? String {
            return t.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(data: body, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func respond(_ conn: NWConnection, _ code: Int, _ text: String) {
        let reasons = [200: "OK", 400: "Bad Request", 401: "Unauthorized",
                       404: "Not Found", 413: "Payload Too Large"]
        let body = Data(text.utf8)
        let head = "HTTP/1.1 \(code) \(reasons[code] ?? "Error")\r\n"
            + "Content-Type: text/plain; charset=utf-8\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: close\r\n\r\n"
        conn.send(content: Data(head.utf8) + body,
                  completion: .contentProcessed { _ in conn.cancel() })
    }
}
