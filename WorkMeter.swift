import AppKit
import Foundation
import Darwin

private let appVersion = "0.2.1"
private let refreshInterval: TimeInterval = 180
private let requestTimeout: TimeInterval = 15

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
        guard let object = object else {
            return "Not exposed"
        }
        if (object["unlimited"] as? Bool) == true {
            return "Unlimited"
        }
        if let balance = object["balance"] as? String, !balance.isEmpty {
            return balance
        }
        if let balance = object["balance"] as? NSNumber {
            return balance.stringValue
        }
        if (object["hasCredits"] as? Bool) == false {
            return "0"
        }
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
    private let reader = CodexUsageReader()
    private let cache = UsageCache()
    private var snapshot: UsageSnapshot?
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
            WorkMeterLog.write("loaded cached usage snapshot from \(cached.fetchedAt)")
            updateDisplay()
        }

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
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.isVisible = true
        if let button = statusItem.button {
            // Use text only. This is intentionally more conservative than an SF Symbol so
            // the item remains visible across Intel Macs and different menu-bar setups.
            button.image = nil
            button.title = "⚡ Work"
            button.toolTip = "ChatGPT Work / Codex usage"
            WorkMeterLog.write("status item created; initial title=\(button.title)")
        } else {
            WorkMeterLog.write("ERROR: NSStatusItem.button was nil")
        }
        statusItem.menu = menu
    }

    private func setupMenu() {
        let header = NSMenuItem(title: "Work / Codex allowance", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        [fiveHourItem, weeklyItem, creditsItem, resetsItem, planItem, connectionItem, updatedItem].forEach {
            $0.isEnabled = false
            menu.addItem($0)
        }

        menu.addItem(.separator())

        let refresh = NSMenuItem(title: "Refresh now", action: #selector(refreshNow), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        let quit = NSMenuItem(title: "Quit WorkMeter", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
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
                    WorkMeterLog.write("usage refresh succeeded")
                    strongSelf.snapshot = snapshot
                    strongSelf.loadedFromCache = false
                    strongSelf.lastRefreshError = nil
                    strongSelf.lastRefreshFailureKind = nil
                    strongSelf.cache.save(snapshot)
                    strongSelf.updateDisplay()
                case .failure(let error):
                    let message = error.localizedDescription
                    WorkMeterLog.write("usage refresh failed: \(message)")
                    strongSelf.lastRefreshError = message
                    strongSelf.lastRefreshFailureKind = strongSelf.classifyFailure(error)
                    if strongSelf.snapshot != nil {
                        strongSelf.updateDisplay()
                    } else {
                        strongSelf.showError(message)
                    }
                }
            }
        }
    }

    @objc private func updateDisplay() {
        guard let snapshot = snapshot else {
            if !isRefreshing {
                statusItem.button?.title = "⚡ Work"
            }
            return
        }

        let fiveTitle = compactWindowText(label: "5h", window: snapshot.fiveHour)
        let weeklyTitle = compactWindowText(label: "W", window: snapshot.weekly)
        let staleSuffix = lastRefreshError == nil ? "" : " ⚠"
        statusItem.button?.title = "⚡ \(fiveTitle) · \(weeklyTitle)\(staleSuffix)"

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

    private func compactWindowText(label: String, window: LimitWindow?) -> String {
        guard let window = window else { return "\(label) —" }
        if let reset = window.resetsAt, reset <= Date() {
            return "\(label) —"
        }
        return "\(label) \(window.leftPercent)%"
    }

    private func windowText(label: String, window: LimitWindow?) -> String {
        guard let window = window else {
            return "\(label): not reported"
        }
        if let reset = window.resetsAt {
            if reset <= Date() {
                return "\(label): previous window expired • refresh required"
            }
            return "\(label): \(window.leftPercent)% left • resets in \(remainingText(to: reset))"
        }
        return "\(label): \(window.leftPercent)% left"
    }

    private func remainingText(to date: Date) -> String {
        let total = max(0, Int(date.timeIntervalSinceNow))
        if total <= 30 { return "now" }
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
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
        statusItem.button?.title = "⚡ !"
        fiveHourItem.title = "Could not read usage"
        weeklyItem.title = message
        creditsItem.title = "Credits: —"
        resetsItem.isHidden = true
        planItem.isHidden = true
        connectionItem.title = "Status: no cached usage available"
        connectionItem.toolTip = message
        updatedItem.title = "Use “Refresh now” to retry"
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

// Explicit AppKit bootstrap. Keeping the delegate in a top-level strong reference avoids
// lifecycle differences across Swift/Xcode versions for tiny single-file menu-bar apps.
let workMeterApplication = NSApplication.shared
let workMeterDelegate = AppDelegate()
workMeterApplication.delegate = workMeterDelegate
workMeterApplication.run()
