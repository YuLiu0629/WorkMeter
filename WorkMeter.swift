import AppKit
import Foundation
import Darwin
import Network

private let appVersion = "0.2.1"
private let refreshInterval: TimeInterval = 180
private let requestTimeout: TimeInterval = 15
private let browserBridgePort: UInt16 = 17891

private struct LimitWindow: Codable {
    let usedPercent: Double
    let windowMinutes: Int
    let resetsAt: Date?

    var leftPercent: Int {
        let value = max(0, min(100, 100 - usedPercent))
        return Int(value.rounded())
    }
}

private struct UsageSnapshot: Codable {
    let fiveHour: LimitWindow?
    let weekly: LimitWindow?
    let creditsText: String
    let freeResetCount: Int?
    let planType: String?
    let fetchedAt: Date
}

private struct ChatGPTFeatureSnapshot: Codable {
    let name: String
    let remaining: Int?
    let limit: Double?
    let resetsAt: Date?
    let blocked: Bool
}

private struct ChatGPTUsageSnapshot: Codable {
    let reason: ChatGPTFeatureSnapshot?
    let deepResearch: ChatGPTFeatureSnapshot?
    let imageGen: ChatGPTFeatureSnapshot?
    let blockedModels: [String]
    let importedAt: Date
    let source: String?
}

private final class UsageCache {
    private let cacheFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/WorkMeter/last-usage.json")

    func load() -> UsageSnapshot? {
        guard let data = try? Data(contentsOf: cacheFile) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(UsageSnapshot.self, from: data)
    }

    func save(_ snapshot: UsageSnapshot) {
        let fm = FileManager.default
        let directory = cacheFile.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(snapshot)
            try data.write(to: cacheFile, options: .atomic)
        } catch {
            WorkMeterLog.write("cache write failed: \(error.localizedDescription)")
        }
    }
}

private final class ChatGPTUsageCache {
    private let cacheFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/WorkMeter/chatgpt-usage.json")

    func load() -> ChatGPTUsageSnapshot? {
        guard let data = try? Data(contentsOf: cacheFile) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(ChatGPTUsageSnapshot.self, from: data)
    }

    func save(_ snapshot: ChatGPTUsageSnapshot) {
        let fm = FileManager.default
        let directory = cacheFile.deletingLastPathComponent()
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            let data = try encoder.encode(snapshot)
            try data.write(to: cacheFile, options: .atomic)
        } catch {
            WorkMeterLog.write("ChatGPT usage cache write failed: \(error.localizedDescription)")
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: cacheFile)
    }
}

private enum RefreshFailureKind {
    case authentication
    case connection
    case setup
    case other
}

private enum WorkMeterError: LocalizedError {
    case codexNotFound
    case launchFailed(String)
    case timeout(String)
    case rpc(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "Codex CLI was not found. Run the WorkMeter installer again after installing/signing in to Codex."
        case .launchFailed(let message):
            return "Could not start Codex: \(message)"
        case .timeout(let step):
            return "Timed out while \(step)."
        case .rpc(let message):
            return message
        case .invalidResponse:
            return "Codex returned an unexpected rate-limit response."
        }
    }
}

private enum ChatGPTImportError: LocalizedError {
    case emptyClipboard
    case invalidJSON
    case metadataNotFound
    case noSupportedUsageFields

    var errorDescription: String? {
        switch self {
        case .emptyClipboard:
            return "The clipboard does not contain text."
        case .invalidJSON:
            return "The clipboard is not valid JSON. Copy the conversation_detail_metadata object from ChatGPT Web."
        case .metadataNotFound:
            return "Could not find a conversation_detail_metadata object in the copied JSON."
        case .noSupportedUsageFields:
            return "The metadata did not contain Pro/Reasoning, Deep Research, or Image Generation usage fields."
        }
    }
}

private enum WorkMeterISODate {
    private static let fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ text: String?) -> Date? {
        guard let text = text, !text.isEmpty else { return nil }
        return fractional.date(from: text) ?? plain.date(from: text)
    }
}

private final class ChatGPTUsageImporter {
    func parse(
        _ text: String,
        previous: ChatGPTUsageSnapshot?,
        source: String
    ) -> Result<ChatGPTUsageSnapshot, Error> {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(ChatGPTImportError.emptyClipboard) }

        guard let object = parseJSONObject(from: trimmed) else {
            return .failure(ChatGPTImportError.invalidJSON)
        }
        guard let metadata = findMetadata(in: object) else {
            return .failure(ChatGPTImportError.metadataNotFound)
        }

        let blocked = metadata["blocked_features"] as? [[String: Any]] ?? []
        let progress = metadata["limits_progress"] as? [[String: Any]] ?? []
        let modelLimits = metadata["model_limits"] as? [[String: Any]] ?? []
        let blockedModels = modelLimits.compactMap { $0["model_slug"] as? String }

        let reason = parseFeature(
            name: "reason",
            blocked: blocked,
            progress: progress,
            previousLimit: previous?.reason?.limit
        )
        let deepResearch = parseFeature(
            name: "deep_research",
            blocked: blocked,
            progress: progress,
            previousLimit: previous?.deepResearch?.limit
        )
        let imageGen = parseFeature(
            name: "image_gen",
            blocked: blocked,
            progress: progress,
            previousLimit: previous?.imageGen?.limit
        )

        guard reason != nil || deepResearch != nil || imageGen != nil || !blockedModels.isEmpty else {
            return .failure(ChatGPTImportError.noSupportedUsageFields)
        }

        return .success(ChatGPTUsageSnapshot(
            reason: reason,
            deepResearch: deepResearch,
            imageGen: imageGen,
            blockedModels: blockedModels,
            importedAt: Date(),
            source: source
        ))
    }

    private func parseJSONObject(from text: String) -> Any? {
        if let data = text.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) {
            return object
        }

        guard let first = text.firstIndex(of: "{"),
              let last = text.lastIndex(of: "}"),
              first <= last else {
            return nil
        }
        let candidate = String(text[first...last])
        guard let data = candidate.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    private func findMetadata(in value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            if (dictionary["type"] as? String) == "conversation_detail_metadata" {
                return dictionary
            }
            for child in dictionary.values {
                if let found = findMetadata(in: child) {
                    return found
                }
            }
        } else if let array = value as? [Any] {
            for child in array {
                if let found = findMetadata(in: child) {
                    return found
                }
            }
        }
        return nil
    }

    private func parseFeature(
        name: String,
        blocked: [[String: Any]],
        progress: [[String: Any]],
        previousLimit: Double?
    ) -> ChatGPTFeatureSnapshot? {
        let blockedEntry = blocked.first { ($0["name"] as? String) == name }
        let progressEntry = progress.first { ($0["feature_name"] as? String) == name }

        guard blockedEntry != nil || progressEntry != nil else { return nil }

        let remaining: Int? = {
            if let value = (progressEntry?["remaining"] as? NSNumber)?.intValue {
                return value
            }
            if blockedEntry != nil {
                return 0
            }
            return nil
        }()

        let limit = (blockedEntry?["limit"] as? NSNumber)?.doubleValue ?? previousLimit
        let resetString = (progressEntry?["reset_after"] as? String)
            ?? (blockedEntry?["resets_after"] as? String)
        let resetsAt = WorkMeterISODate.parse(resetString)

        return ChatGPTFeatureSnapshot(
            name: name,
            remaining: remaining,
            limit: limit,
            resetsAt: resetsAt,
            blocked: blockedEntry != nil
        )
    }
}

private final class ChatGPTBrowserBridge {
    enum State {
        case starting
        case listening
        case failed(String)
    }

    private let queue = DispatchQueue(label: "app.workmeter.browser-bridge")
    private let onPayload: (String) -> Void
    private let onState: (State) -> Void
    private var listener: NWListener?

    init(onPayload: @escaping (String) -> Void, onState: @escaping (State) -> Void) {
        self.onPayload = onPayload
        self.onState = onState
    }

    func start() {
        guard listener == nil else { return }
        onState(.starting)

        do {
            guard let port = NWEndpoint.Port(rawValue: browserBridgePort) else {
                onState(.failed("invalid local port"))
                return
            }
            let newListener = try NWListener(using: .tcp, on: port)
            newListener.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .ready:
                    WorkMeterLog.write("browser companion bridge listening on 127.0.0.1:\(browserBridgePort)")
                    self.onState(.listening)
                case .failed(let error):
                    WorkMeterLog.write("browser companion bridge failed: \(error)")
                    self.onState(.failed(error.localizedDescription))
                default:
                    break
                }
            }
            newListener.newConnectionHandler = { [weak self] connection in
                self?.handle(connection)
            }
            newListener.start(queue: queue)
            listener = newListener
        } catch {
            WorkMeterLog.write("browser companion bridge start failed: \(error.localizedDescription)")
            onState(.failed(error.localizedDescription))
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        var buffer = Data()

        func receiveMore() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 32_768) { [weak self] data, _, complete, error in
                guard let self = self else {
                    connection.cancel()
                    return
                }

                if let data = data, !data.isEmpty {
                    buffer.append(data)
                }

                if buffer.count > 131_072 {
                    self.respond(connection, status: "413 Payload Too Large", body: "{\"ok\":false}")
                    return
                }

                if let request = self.completeRequest(from: buffer) {
                    self.process(request, connection: connection)
                    return
                }

                if complete || error != nil {
                    self.respond(connection, status: "400 Bad Request", body: "{\"ok\":false}")
                    return
                }

                receiveMore()
            }
        }

        receiveMore()
    }

    private struct HTTPRequest {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data
    }

    private func completeRequest(from data: Data) -> HTTPRequest? {
        let separator = Data("\r\n\r\n".utf8)
        guard let range = data.range(of: separator) else { return nil }

        let headerData = data.subdata(in: data.startIndex..<range.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerText.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return nil }
        let firstParts = firstLine.split(separator: " ")
        guard firstParts.count >= 2 else { return nil }

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[name] = value
        }

        let length = Int(headers["content-length"] ?? "0") ?? 0
        let bodyStart = range.upperBound
        guard data.count >= bodyStart + length else { return nil }
        let body = data.subdata(in: bodyStart..<(bodyStart + length))

        return HTTPRequest(
            method: String(firstParts[0]),
            path: String(firstParts[1]),
            headers: headers,
            body: body
        )
    }

    private func process(_ request: HTTPRequest, connection: NWConnection) {
        let origin = request.headers["origin"] ?? ""
        if origin.hasPrefix("http://") || origin.hasPrefix("https://") {
            respond(connection, status: "403 Forbidden", body: "{\"ok\":false,\"error\":\"browser-origin-not-allowed\"}")
            return
        }

        if request.method == "OPTIONS" {
            respond(connection, status: "204 No Content", body: "")
            return
        }

        guard request.method == "POST", request.path == "/chatgpt-usage" else {
            respond(connection, status: "404 Not Found", body: "{\"ok\":false}")
            return
        }

        guard !request.body.isEmpty,
              let text = String(data: request.body, encoding: .utf8) else {
            respond(connection, status: "400 Bad Request", body: "{\"ok\":false,\"error\":\"empty-body\"}")
            return
        }

        onPayload(text)
        respond(connection, status: "200 OK", body: "{\"ok\":true}")
    }

    private func respond(_ connection: NWConnection, status: String, body: String) {
        let bodyData = Data(body.utf8)
        var headers = "HTTP/1.1 \(status)\r\n"
        headers += "Content-Type: application/json; charset=utf-8\r\n"
        headers += "Content-Length: \(bodyData.count)\r\n"
        headers += "Access-Control-Allow-Origin: *\r\n"
        headers += "Access-Control-Allow-Methods: POST, OPTIONS\r\n"
        headers += "Access-Control-Allow-Headers: Content-Type\r\n"
        headers += "Connection: close\r\n\r\n"

        var response = Data(headers.utf8)
        response.append(bodyData)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private final class CodexUsageReader {
    private let configFile = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/WorkMeter/codex-path.txt")

    func fetch() -> Result<UsageSnapshot, Error> {
        guard let codexURL = resolveCodexURL() else {
            return .failure(WorkMeterError.codexNotFound)
        }

        let process = Process()
        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()

        process.executableURL = codexURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return .failure(WorkMeterError.launchFailed(error.localizedDescription))
        }

        defer {
            try? stdinPipe.fileHandleForWriting.close()
            try? stdoutPipe.fileHandleForReading.close()
            if process.isRunning {
                process.terminate()
            }
        }

        let stdoutFD = stdoutPipe.fileHandleForReading.fileDescriptor
        let oldFlags = fcntl(stdoutFD, F_GETFL)
        if oldFlags >= 0 {
            _ = fcntl(stdoutFD, F_SETFL, oldFlags | O_NONBLOCK)
        }

        func send(_ object: [String: Any]) -> Bool {
            guard JSONSerialization.isValidJSONObject(object),
                  let data = try? JSONSerialization.data(withJSONObject: object),
                  var line = String(data: data, encoding: .utf8) else {
                return false
            }
            line.append("\n")
            guard let bytes = line.data(using: .utf8) else { return false }
            do {
                try stdinPipe.fileHandleForWriting.write(contentsOf: bytes)
                return true
            } catch {
                return false
            }
        }

        let initialize: [String: Any] = [
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "workmeter",
                    "title": "WorkMeter",
                    "version": appVersion
                ],
                "capabilities": [:]
            ]
        ]

        guard send(initialize) else {
            return .failure(WorkMeterError.rpc("Could not write to the Codex app-server."))
        }

        var receiveBuffer = Data()
        var didInitialize = false
        var sentRateRequest = false
        let deadline = Date().addingTimeInterval(requestTimeout)

        while Date() < deadline {
            var chunk = [UInt8](repeating: 0, count: 8192)
            let count = Darwin.read(stdoutFD, &chunk, chunk.count)

            if count > 0 {
                receiveBuffer.append(contentsOf: chunk.prefix(count))

                while let newlineIndex = receiveBuffer.firstIndex(of: 0x0A) {
                    let lineData = receiveBuffer.prefix(upTo: newlineIndex)
                    receiveBuffer.removeSubrange(receiveBuffer.startIndex...newlineIndex)

                    guard !lineData.isEmpty,
                          let object = try? JSONSerialization.jsonObject(with: Data(lineData)),
                          let message = object as? [String: Any] else {
                        continue
                    }

                    let id = (message["id"] as? NSNumber)?.intValue

                    if id == 1 {
                        if let errorObject = message["error"] as? [String: Any] {
                            return .failure(WorkMeterError.rpc(rpcErrorText(errorObject)))
                        }

                        didInitialize = true
                        if !sentRateRequest {
                            guard send(["method": "initialized"]) else {
                                return .failure(WorkMeterError.rpc("Could not finish the Codex initialization handshake."))
                            }
                            guard send(["id": 2, "method": "account/rateLimits/read"]) else {
                                return .failure(WorkMeterError.rpc("Could not request rate-limit data from Codex."))
                            }
                            sentRateRequest = true
                        }
                    } else if id == 2 {
                        if let errorObject = message["error"] as? [String: Any] {
                            return .failure(WorkMeterError.rpc(rpcErrorText(errorObject)))
                        }
                        guard let result = message["result"] as? [String: Any],
                              let snapshot = parseSnapshot(result) else {
                            return .failure(WorkMeterError.invalidResponse)
                        }
                        return .success(snapshot)
                    }
                }
            } else if count == 0 {
                if !process.isRunning {
                    return .failure(WorkMeterError.rpc("Codex app-server exited before returning usage data. Open Terminal and run `codex` to confirm you are signed in."))
                }
            } else if errno != EAGAIN && errno != EWOULDBLOCK {
                return .failure(WorkMeterError.rpc("Could not read from the Codex app-server."))
            }

            usleep(20_000)
        }

        if !didInitialize {
            return .failure(WorkMeterError.timeout("starting the Codex app-server"))
        }
        return .failure(WorkMeterError.timeout("reading Work/Codex usage"))
    }

    private func resolveCodexURL() -> URL? {
        if let configured = try? String(contentsOf: configFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !configured.isEmpty,
           FileManager.default.isExecutableFile(atPath: configured) {
            return URL(fileURLWithPath: configured)
        }

        if let envPath = ProcessInfo.processInfo.environment["WORKMETER_CODEX_PATH"],
           FileManager.default.isExecutableFile(atPath: envPath) {
            return URL(fileURLWithPath: envPath)
        }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "/usr/local/bin/codex",
            "/opt/homebrew/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        let shell = Process()
        let out = Pipe()
        shell.executableURL = URL(fileURLWithPath: "/bin/zsh")
        shell.arguments = ["-lic", "command -v codex"]
        shell.standardOutput = out
        shell.standardError = FileHandle.nullDevice
        do {
            try shell.run()
            shell.waitUntilExit()
            let data = out.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?
                .split(separator: "\n")
                .first
                .map(String.init),
               FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        } catch {
            return nil
        }
        return nil
    }

    private func parseSnapshot(_ result: [String: Any]) -> UsageSnapshot? {
        var rateObject: [String: Any]?

        if let byID = result["rateLimitsByLimitId"] as? [String: Any],
           let codex = byID["codex"] as? [String: Any] {
            rateObject = codex
        } else if let direct = result["rateLimits"] as? [String: Any] {
            rateObject = direct
        }

        guard let rate = rateObject else { return nil }

        var windows: [LimitWindow] = []
        for key in ["primary", "secondary"] {
            if let object = rate[key] as? [String: Any],
               let window = parseWindow(object) {
                windows.append(window)
            }
        }

        var fiveHour: LimitWindow?
        var weekly: LimitWindow?

        for window in windows {
            if window.windowMinutes >= 240 && window.windowMinutes <= 360 {
                fiveHour = window
            } else if window.windowMinutes >= 7_000 {
                weekly = window
            }
        }

        if fiveHour == nil, windows.count >= 2 {
            fiveHour = windows.min(by: { $0.windowMinutes < $1.windowMinutes })
        }
        if weekly == nil {
            weekly = windows.max(by: { $0.windowMinutes < $1.windowMinutes })
            if weekly?.windowMinutes == fiveHour?.windowMinutes {
                weekly = nil
            }
        }

        let creditsText = parseCredits(rate["credits"] as? [String: Any])
        let freeResetCount: Int? = {
            guard let resetCredits = result["rateLimitResetCredits"] as? [String: Any] else { return nil }
            return (resetCredits["availableCount"] as? NSNumber)?.intValue
        }()
        let planType = rate["planType"] as? String

        return UsageSnapshot(
            fiveHour: fiveHour,
            weekly: weekly,
            creditsText: creditsText,
            freeResetCount: freeResetCount,
            planType: planType,
            fetchedAt: Date()
        )
    }

    private func parseWindow(_ object: [String: Any]) -> LimitWindow? {
        guard let used = (object["usedPercent"] as? NSNumber)?.doubleValue,
              let minutes = (object["windowDurationMins"] as? NSNumber)?.intValue else {
            return nil
        }
        let resetDate: Date?
        if let epoch = (object["resetsAt"] as? NSNumber)?.doubleValue {
            resetDate = Date(timeIntervalSince1970: epoch)
        } else {
            resetDate = nil
        }
        return LimitWindow(usedPercent: used, windowMinutes: minutes, resetsAt: resetDate)
    }

    private func parseCredits(_ object: [String: Any]?) -> String {
        guard let object = object else { return "Not exposed" }
        if (object["unlimited"] as? Bool) == true { return "Unlimited" }
        if let balance = object["balance"] as? String, !balance.isEmpty { return balance }
        if let balance = object["balance"] as? NSNumber { return balance.stringValue }
        if (object["hasCredits"] as? Bool) == false { return "0" }
        return "Not exposed"
    }

    private func rpcErrorText(_ object: [String: Any]) -> String {
        if let message = object["message"] as? String, !message.isEmpty {
            if message.localizedCaseInsensitiveContains("auth") || message.localizedCaseInsensitiveContains("login") {
                return "Codex is not signed in. Open Terminal, run `codex`, and sign in with the same ChatGPT account."
            }
            return "Codex: \(message)"
        }
        return "Codex returned an error while reading usage."
    }
}

private enum WorkMeterLog {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func write(_ message: String) {
        let fm = FileManager.default
        let url = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/WorkMeter.log")
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if !fm.fileExists(atPath: url.path) {
            fm.createFile(atPath: url.path, contents: data)
            return
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Logging must never interfere with the menu-bar app.
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()

    private let fiveHourItem = NSMenuItem(title: "5-hour: —", action: nil, keyEquivalent: "")
    private let weeklyItem = NSMenuItem(title: "Weekly: —", action: nil, keyEquivalent: "")
    private let creditsItem = NSMenuItem(title: "Credits: —", action: nil, keyEquivalent: "")
    private let resetsItem = NSMenuItem(title: "Free resets: —", action: nil, keyEquivalent: "")
    private let planItem = NSMenuItem(title: "Plan: —", action: nil, keyEquivalent: "")
    private let connectionItem = NSMenuItem(title: "Status: —", action: nil, keyEquivalent: "")
    private let updatedItem = NSMenuItem(title: "Last confirmed: —", action: nil, keyEquivalent: "")

    private let proItem = NSMenuItem(title: "Pro / Reasoning: waiting for browser", action: nil, keyEquivalent: "")
    private let researchItem = NSMenuItem(title: "Deep Research: waiting for browser", action: nil, keyEquivalent: "")
    private let imageGenItem = NSMenuItem(title: "Image generation: waiting for browser", action: nil, keyEquivalent: "")
    private let blockedModelsItem = NSMenuItem(title: "Blocked Pro models: —", action: nil, keyEquivalent: "")
    private let chatGPTSourceItem = NSMenuItem(title: "Source: browser companion / manual import", action: nil, keyEquivalent: "")
    private let chatGPTUpdatedItem = NSMenuItem(title: "Last ChatGPT update: —", action: nil, keyEquivalent: "")
    private let browserBridgeItem = NSMenuItem(title: "Browser bridge: starting…", action: nil, keyEquivalent: "")

    private let reader = CodexUsageReader()
    private let cache = UsageCache()
    private let chatGPTCache = ChatGPTUsageCache()
    private let chatGPTImporter = ChatGPTUsageImporter()

    private var browserBridge: ChatGPTBrowserBridge?
    private var snapshot: UsageSnapshot?
    private var chatGPTSnapshot: ChatGPTUsageSnapshot?
    private var lastRefreshError: String?
    private var lastRefreshFailureKind: RefreshFailureKind?
    private var loadedFromCache = false
    private var refreshTimer: Timer?
    private var countdownTimer: Timer?
    private var isRefreshing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        WorkMeterLog.write("applicationDidFinishLaunching")
        setupStatusItem()
        setupMenu()

        if let cached = cache.load() {
            snapshot = cached
            loadedFromCache = true
            WorkMeterLog.write("loaded cached Codex usage snapshot from \(cached.fetchedAt)")
        }
        if let imported = chatGPTCache.load() {
            chatGPTSnapshot = imported
            WorkMeterLog.write("loaded cached ChatGPT usage snapshot from \(imported.importedAt)")
        }

        browserBridge = ChatGPTBrowserBridge(
            onPayload: { [weak self] text in
                DispatchQueue.main.async {
                    self?.handleBrowserUsagePayload(text)
                }
            },
            onState: { [weak self] state in
                DispatchQueue.main.async {
                    self?.updateBrowserBridgeState(state)
                }
            }
        )
        browserBridge?.start()

        updateDisplay()
        refreshNow()

        refreshTimer = Timer.scheduledTimer(timeInterval: refreshInterval,
                                            target: self,
                                            selector: #selector(refreshNow),
                                            userInfo: nil,
                                            repeats: true)
        countdownTimer = Timer.scheduledTimer(timeInterval: 60,
                                              target: self,
                                              selector: #selector(updateDisplay),
                                              userInfo: nil,
                                              repeats: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        countdownTimer?.invalidate()
        browserBridge?.stop()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        if let button = statusItem.button {
            button.image = nil
            button.title = "⚡ Work"
            button.toolTip = "ChatGPT & Codex usage"
            WorkMeterLog.write("status item created; initial title=\(button.title)")
        } else {
            WorkMeterLog.write("ERROR: NSStatusItem.button was nil")
        }
        statusItem.menu = menu
    }

    private func setupMenu() {
        let codexHeader = NSMenuItem(title: "Work / Codex allowance", action: nil, keyEquivalent: "")
        codexHeader.isEnabled = false
        menu.addItem(codexHeader)
        menu.addItem(.separator())

        [fiveHourItem, weeklyItem, creditsItem, resetsItem, planItem, connectionItem, updatedItem].forEach {
            $0.isEnabled = false
            menu.addItem($0)
        }

        menu.addItem(.separator())

        let chatGPTHeader = NSMenuItem(title: "ChatGPT advanced features (beta)", action: nil, keyEquivalent: "")
        chatGPTHeader.isEnabled = false
        menu.addItem(chatGPTHeader)

        [proItem, researchItem, imageGenItem, blockedModelsItem, chatGPTSourceItem, chatGPTUpdatedItem, browserBridgeItem].forEach {
            $0.isEnabled = false
            menu.addItem($0)
        }
        blockedModelsItem.isHidden = true

        let companionGuide = NSMenuItem(title: "Set up automatic browser companion…", action: #selector(openCompanionGuide), keyEquivalent: "")
        companionGuide.target = self
        menu.addItem(companionGuide)

        let importItem = NSMenuItem(title: "Import ChatGPT usage from clipboard…", action: #selector(importChatGPTUsageFromClipboard), keyEquivalent: "i")
        importItem.target = self
        menu.addItem(importItem)

        let clearImported = NSMenuItem(title: "Clear ChatGPT usage cache", action: #selector(clearImportedChatGPTUsage), keyEquivalent: "")
        clearImported.target = self
        menu.addItem(clearImported)

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh Codex now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let quit = NSMenuItem(title: "Quit WorkMeter", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func updateBrowserBridgeState(_ state: ChatGPTBrowserBridge.State) {
        switch state {
        case .starting:
            browserBridgeItem.title = "Browser bridge: starting…"
            browserBridgeItem.toolTip = nil
        case .listening:
            browserBridgeItem.title = "Browser bridge: ready • localhost only"
            browserBridgeItem.toolTip = "Listening on 127.0.0.1:\(browserBridgePort). It accepts sanitized usage data from the optional WorkMeter browser companion."
        case .failed(let message):
            browserBridgeItem.title = "⚠ Browser bridge unavailable"
            browserBridgeItem.toolTip = message
        }
    }

    private func handleBrowserUsagePayload(_ text: String) {
        switch chatGPTImporter.parse(text, previous: chatGPTSnapshot, source: "browser") {
        case .success(let imported):
            chatGPTSnapshot = imported
            chatGPTCache.save(imported)
            WorkMeterLog.write("ChatGPT usage updated automatically by browser companion")
            updateDisplay()
        case .failure(let error):
            WorkMeterLog.write("browser companion payload rejected: \(error.localizedDescription)")
        }
    }

    @objc private func refreshNow() {
        guard !isRefreshing else { return }
        isRefreshing = true
        if snapshot != nil {
            connectionItem.title = loadedFromCache ? "Status: refreshing cached data…" : "Status: refreshing…"
        } else {
            updatedItem.title = "Updating…"
        }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let strongSelf = self else { return }
            let result = strongSelf.reader.fetch()
            DispatchQueue.main.async {
                strongSelf.isRefreshing = false
                switch result {
                case .success(let snapshot):
                    WorkMeterLog.write("Codex usage refresh succeeded")
                    strongSelf.snapshot = snapshot
                    strongSelf.loadedFromCache = false
                    strongSelf.lastRefreshError = nil
                    strongSelf.lastRefreshFailureKind = nil
                    strongSelf.cache.save(snapshot)
                    strongSelf.updateDisplay()
                case .failure(let error):
                    let message = error.localizedDescription
                    WorkMeterLog.write("Codex usage refresh failed: \(message)")
                    strongSelf.lastRefreshError = message
                    strongSelf.lastRefreshFailureKind = strongSelf.classifyFailure(error)
                    if strongSelf.snapshot != nil || strongSelf.chatGPTSnapshot != nil {
                        strongSelf.updateDisplay()
                    } else {
                        strongSelf.showError(message)
                    }
                }
            }
        }
    }

    @objc private func importChatGPTUsageFromClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string) else {
            showImportAlert(error: ChatGPTImportError.emptyClipboard.localizedDescription)
            return
        }

        switch chatGPTImporter.parse(text, previous: chatGPTSnapshot, source: "manual") {
        case .success(let imported):
            chatGPTSnapshot = imported
            chatGPTCache.save(imported)
            WorkMeterLog.write("ChatGPT usage imported manually from clipboard")
            updateDisplay()

            let alert = NSAlert()
            alert.messageText = "ChatGPT usage imported"
            alert.informativeText = "WorkMeter saved only parsed counters and reset times on this Mac. It did not read browser cookies or your ChatGPT session."
            alert.alertStyle = .informational
            alert.runModal()
        case .failure(let error):
            showImportAlert(error: error.localizedDescription)
        }
    }

    @objc private func clearImportedChatGPTUsage() {
        chatGPTSnapshot = nil
        chatGPTCache.clear()
        WorkMeterLog.write("cleared ChatGPT usage snapshot")
        updateDisplay()
    }

    @objc private func openCompanionGuide() {
        guard let url = URL(string: "https://github.com/YuLiu0629/WorkMeter/blob/experimental/chatgpt-usage-v0.3/docs/CHATGPT-COMPANION.md") else { return }
        NSWorkspace.shared.open(url)
    }

    private func showImportAlert(error: String) {
        let alert = NSAlert()
        alert.messageText = "Could not import ChatGPT usage"
        alert.informativeText = "\(error)\n\nFallback: ChatGPT Web → DevTools → Network → conversation/init → Response, copy the conversation_detail_metadata JSON object, then choose Import again."
        alert.alertStyle = .warning
        alert.runModal()
    }

    @objc private func updateDisplay() {
        updateChatGPTDisplay()

        guard let snapshot = snapshot else {
            if !isRefreshing {
                if let compactPro = compactProText() {
                    statusItem.button?.title = "⚡ \(compactPro)"
                } else {
                    statusItem.button?.title = "⚡ Work"
                }
            }
            return
        }

        let fiveTitle = compactWindowText(label: "5h", window: snapshot.fiveHour)
        let weeklyTitle = compactWindowText(label: "W", window: snapshot.weekly)
        let proSuffix = compactProText().map { " · \($0)" } ?? ""
        let staleSuffix = lastRefreshError == nil ? "" : " ⚠"
        statusItem.button?.title = "⚡ \(fiveTitle) · \(weeklyTitle)\(proSuffix)\(staleSuffix)"

        fiveHourItem.title = windowText(label: "5-hour", window: snapshot.fiveHour)
        weeklyItem.title = windowText(label: "Weekly", window: snapshot.weekly)
        creditsItem.title = "Credits: \(snapshot.creditsText)"

        if let count = snapshot.freeResetCount {
            resetsItem.title = "Free resets: \(count)"
            resetsItem.isHidden = false
        } else {
            resetsItem.isHidden = true
        }

        if let plan = snapshot.planType, !plan.isEmpty {
            planItem.title = "Plan: \(plan)"
            planItem.isHidden = false
        } else {
            planItem.isHidden = true
        }

        if let error = lastRefreshError {
            switch lastRefreshFailureKind ?? .other {
            case .authentication:
                connectionItem.title = "⚠ Codex sign-in required • showing last known usage"
            case .connection:
                connectionItem.title = "⚠ Offline / service unavailable • showing last known usage"
            case .setup:
                connectionItem.title = "⚠ Codex unavailable • showing last known usage"
            case .other:
                connectionItem.title = "⚠ Refresh failed • showing last known usage"
            }
            connectionItem.toolTip = error
        } else if loadedFromCache || isRefreshing {
            connectionItem.title = "Status: refreshing last known usage…"
            connectionItem.toolTip = nil
        } else {
            connectionItem.title = "Status: Live"
            connectionItem.toolTip = nil
        }

        let age = ageText(since: snapshot.fetchedAt)
        let prefix = lastRefreshError == nil && !loadedFromCache ? "Last updated" : "Last confirmed"
        updatedItem.title = "\(prefix): \(timeFormatter.string(from: snapshot.fetchedAt)) • \(age)"
    }

    private func updateChatGPTDisplay() {
        guard let imported = chatGPTSnapshot else {
            proItem.title = "Pro / Reasoning: waiting for ChatGPT data"
            researchItem.title = "Deep Research: waiting for ChatGPT data"
            imageGenItem.title = "Image generation: waiting for ChatGPT data"
            blockedModelsItem.isHidden = true
            chatGPTSourceItem.title = "Source: browser companion / manual fallback"
            chatGPTUpdatedItem.title = "Last ChatGPT update: —"
            return
        }

        proItem.title = chatGPTFeatureText(label: "Pro / Reasoning", feature: imported.reason)
        researchItem.title = chatGPTFeatureText(label: "Deep Research", feature: imported.deepResearch)
        imageGenItem.title = chatGPTFeatureText(label: "Image generation", feature: imported.imageGen)

        if imported.blockedModels.isEmpty {
            blockedModelsItem.isHidden = true
        } else {
            blockedModelsItem.isHidden = false
            blockedModelsItem.title = "Blocked Pro models: \(imported.blockedModels.count)"
            blockedModelsItem.toolTip = imported.blockedModels.joined(separator: ", ")
        }

        if imported.source == "browser" {
            chatGPTSourceItem.title = "Source: browser companion • automatic"
        } else {
            chatGPTSourceItem.title = "Source: manual import • local only"
        }
        chatGPTUpdatedItem.title = "Last ChatGPT update: \(timeFormatter.string(from: imported.importedAt)) • \(ageText(since: imported.importedAt))"
    }

    private func compactProText() -> String? {
        guard let feature = chatGPTSnapshot?.reason else { return nil }
        if let reset = feature.resetsAt, reset <= Date() { return "P —" }
        if let remaining = feature.remaining {
            if let limit = feature.limit {
                return "P \(remaining)/\(formatLimit(limit))"
            }
            return "P \(remaining)"
        }
        return feature.blocked ? "P 0" : nil
    }

    private func compactWindowText(label: String, window: LimitWindow?) -> String {
        guard let window = window else { return "\(label) —" }
        if let reset = window.resetsAt, reset <= Date() { return "\(label) —" }
        return "\(label) \(window.leftPercent)%"
    }

    private func windowText(label: String, window: LimitWindow?) -> String {
        guard let window = window else { return "\(label): not reported" }
        if let reset = window.resetsAt {
            if reset <= Date() {
                return "\(label): previous window expired • refresh required"
            }
            return "\(label): \(window.leftPercent)% left • resets in \(remainingText(to: reset))"
        }
        return "\(label): \(window.leftPercent)% left"
    }

    private func chatGPTFeatureText(label: String, feature: ChatGPTFeatureSnapshot?) -> String {
        guard let feature = feature else {
            return "\(label): not reported in latest ChatGPT metadata"
        }

        if let reset = feature.resetsAt, reset <= Date() {
            return "\(label): previous snapshot expired • waiting for browser refresh"
        }

        var value: String
        if let remaining = feature.remaining {
            if let limit = feature.limit {
                value = "\(remaining) / \(formatLimit(limit)) remaining"
            } else {
                value = "\(remaining) remaining"
            }
        } else if feature.blocked {
            value = "blocked"
        } else {
            value = "reported"
        }

        if let reset = feature.resetsAt {
            value += " • resets in \(remainingText(to: reset))"
        }
        return "\(label): \(value)"
    }

    private func formatLimit(_ limit: Double) -> String {
        if limit.rounded() == limit { return String(Int(limit)) }
        return String(format: "%.1f", limit)
    }

    private func remainingText(to date: Date) -> String {
        let total = max(0, Int(date.timeIntervalSinceNow))
        if total <= 30 { return "now" }
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(max(1, minutes))m"
    }

    private func ageText(since date: Date) -> String {
        let total = max(0, Int(Date().timeIntervalSince(date)))
        if total < 60 { return "just now" }
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h ago" }
        if hours > 0 { return "\(hours)h \(minutes)m ago" }
        return "\(minutes)m ago"
    }

    private func classifyFailure(_ error: Error) -> RefreshFailureKind {
        if let workError = error as? WorkMeterError {
            switch workError {
            case .codexNotFound, .launchFailed:
                return .setup
            case .timeout:
                return .connection
            case .rpc(let message):
                let text = message.lowercased()
                if text.contains("sign in") || text.contains("signed in") || text.contains("auth") ||
                    text.contains("token") || text.contains("login") || text.contains("401") ||
                    text.contains("unauthorized") {
                    return .authentication
                }
                if text.contains("network") || text.contains("connection") || text.contains("connect") ||
                    text.contains("offline") || text.contains("dns") || text.contains("timed out") ||
                    text.contains("unavailable") {
                    return .connection
                }
                return .other
            case .invalidResponse:
                return .other
            }
        }

        let text = error.localizedDescription.lowercased()
        if text.contains("auth") || text.contains("token") || text.contains("login") || text.contains("401") {
            return .authentication
        }
        if text.contains("network") || text.contains("connection") || text.contains("offline") || text.contains("timeout") {
            return .connection
        }
        return .other
    }

    private func showError(_ message: String) {
        statusItem.button?.title = compactProText().map { "⚡ ! · \($0)" } ?? "⚡ !"
        fiveHourItem.title = "Could not read Codex usage"
        weeklyItem.title = message
        creditsItem.title = "Credits: —"
        resetsItem.isHidden = true
        planItem.isHidden = true
        connectionItem.title = "Status: no cached Codex usage available"
        connectionItem.toolTip = message
        updatedItem.title = "Use “Refresh Codex now” to retry"
        updateChatGPTDisplay()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

let workMeterApplication = NSApplication.shared
let workMeterDelegate = AppDelegate()
workMeterApplication.delegate = workMeterDelegate
workMeterApplication.run()
