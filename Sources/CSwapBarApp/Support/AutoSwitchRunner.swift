import CSwapBarCore
import Foundation
import Observation

/// Runs CSwap's auto-switcher (`cswap auto --json`) while Auto-switch is on and
/// reacts to its events: a switch triggers an immediate refresh (so the popover,
/// history and notifications update without waiting for the next poll).
///
/// CSwap does the switching; CSwapBar only starts, stops and listens.
///
/// Safety: the process runs under a tiny `/bin/sh` watchdog that stops it as
/// soon as CSwapBar exits, even after a crash, so auto-switching never keeps
/// running unseen. Arguments go to the shell as positional parameters ("$@"),
/// never interpolated into the script text.
@MainActor
@Observable
final class AutoSwitchRunner {
    enum State: Equatable {
        case off
        case running
        case problem(String)
    }

    private(set) var state: State = .off
    /// Latest decision in plain words, e.g. "No switch needed: 7d 61% < 90%".
    private(set) var lastDecision: String?
    private(set) var lastDecisionDate: Date?

    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var buffer = Data()
    @ObservationIgnored private var stopping = false
    @ObservationIgnored private var running: AutoSwitchPreferences?
    @ObservationIgnored private var restartTask: Task<Void, Never>?
    @ObservationIgnored private let locate: () -> URL?
    @ObservationIgnored private let onEvent: (CSwapAutoEvent) -> Void

    /// Developer aid: `CSWAPBAR_AUTO_DRY_RUN=1` adds `--dry-run`, so CSwap only reports.
    private let dryRun = ProcessInfo.processInfo.environment["CSWAPBAR_AUTO_DRY_RUN"] == "1"

    init(locate: @escaping () -> URL?, onEvent: @escaping (CSwapAutoEvent) -> Void) {
        self.locate = locate
        self.onEvent = onEvent
    }

    /// Starts, restarts (when options changed) or stops to match `prefs`.
    func apply(_ prefs: AutoSwitchPreferences) {
        guard prefs.enabled else {
            stop()
            state = .off
            return
        }
        if process?.isRunning == true, running == prefs { return }
        stop()
        start(prefs)
    }

    func stop() {
        restartTask?.cancel()
        restartTask = nil
        guard let process else { return }
        stopping = true
        process.standardOutput.flatMap { ($0 as? Pipe)?.fileHandleForReading.readabilityHandler = nil }
        if process.isRunning { process.terminate() }
        self.process = nil
        running = nil
    }

    private func start(_ prefs: AutoSwitchPreferences) {
        guard let cswap = locate() else {
            state = .problem("CSwap isn't installed, so auto-switch can't run.")
            return
        }
        let watchdog = """
            parent=$1; shift
            "$@" &
            child=$!
            trap 'kill "$child" 2>/dev/null; exit 0' TERM INT HUP
            while kill -0 "$parent" 2>/dev/null && kill -0 "$child" 2>/dev/null; do sleep 2; done
            kill "$child" 2>/dev/null
            wait "$child"
            """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", watchdog, "cswapbar-auto", String(ProcessInfo.processInfo.processIdentifier), cswap.path]
            + prefs.arguments(dryRun: dryRun)
        var environment = ProcessInfo.processInfo.environment
        environment["NO_COLOR"] = "1"
        environment["PYTHONUNBUFFERED"] = "1"   // one JSON line at a time, not in blocks
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.ingest(data) }
            }
        }
        process.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.didExit(status: status) }
            }
        }

        do {
            stopping = false
            buffer.removeAll()
            try process.run()
            self.process = process
            running = prefs
            state = .running
            lastDecision = dryRun ? "Started in dry-run mode (CSwap only reports)." : "Started. Waiting for CSwap's first check…"
            lastDecisionDate = Date()
        } catch {
            state = .problem("Couldn't start CSwap's auto-switch: \(error.localizedDescription)")
        }
    }

    private func ingest(_ data: Data) {
        guard !data.isEmpty else { return }
        buffer.append(data)
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self)
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let event = CSwapAutoEvent(line: line) else { continue }
            describe(event)
            onEvent(event)
        }
    }

    private func describe(_ event: CSwapAutoEvent) {
        let summary: String? = switch event.kind {
        case .poll: nil   // every tick; the decision event follows
        case .noSwitch: "No switch needed" + (event.detail.map { ": \($0)" } ?? "")
        case .switched: "Switched accounts" + (event.reason.map { " (\($0))" } ?? "")
        case .blocked: "Wanted to switch, but no account had quota left"
        case .error: "CSwap reported a problem" + (event.detail.map { ": \($0)" } ?? "")
        case .other(let name): "CSwap: \(name)"
        }
        if let summary {
            lastDecision = summary
            lastDecisionDate = event.date ?? Date()
        }
        // Developer aid: CSWAPBAR_AUTO_LOG=/path appends each decision (no account details).
        if let path = ProcessInfo.processInfo.environment["CSWAPBAR_AUTO_LOG"],
           let line = "\(event.kind) | \(summary ?? "-")\n".data(using: .utf8) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(line)
                try? handle.close()
            } else {
                FileManager.default.createFile(atPath: path, contents: line)
            }
        }
    }

    private func didExit(status: Int32) {
        process = nil
        running = nil
        guard !stopping else { return }
        state = .problem("CSwap's auto-switch stopped (exit \(status)). Retrying in a minute.")
        // Retry once a minute while still enabled, without tight loops.
        restartTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            self?.retry()
        }
    }

    @ObservationIgnored var currentPreferences: () -> AutoSwitchPreferences = { AutoSwitchPreferences() }

    private func retry() {
        apply(currentPreferences())
    }
}
