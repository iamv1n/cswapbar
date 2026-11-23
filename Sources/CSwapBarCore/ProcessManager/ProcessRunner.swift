import Foundation

/// Output of a finished subprocess.
public struct ProcessResult: Sendable, Equatable {
    public let exitCode: Int32
    public let stdout: Data
    public let stderr: Data

    public init(exitCode: Int32, stdout: Data, stderr: Data) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }

    public var stderrText: String {
        String(decoding: stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum ProcessRunnerError: Error, Equatable, Sendable {
    case launchFailed(String)
    case timedOut(seconds: Double)
}

/// Runs an executable directly (never through a shell) and captures its output.
public protocol ProcessRunning: Sendable {
    func run(executable: URL, arguments: [String], timeout: Double) async throws -> ProcessResult
}

public struct ProcessRunner: ProcessRunning {
    /// Extra environment variables merged over the inherited environment.
    public var environment: [String: String]

    public init(environment: [String: String] = [:]) {
        self.environment = environment
    }

    public func run(executable: URL, arguments: [String], timeout: Double) async throws -> ProcessResult {
        let execution = ProcessExecution(
            executable: executable,
            arguments: arguments,
            environment: environment
        )
        return try await withTaskCancellationHandler {
            try await execution.start(timeout: timeout)
        } onCancel: {
            execution.cancel()
        }
    }
}

/// One subprocess run. All mutable state is guarded by `lock`.
private final class ProcessExecution: @unchecked Sendable {
    private let process = Process()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let lock = NSLock()
    private var stdoutData = Data()
    private var stderrData = Data()
    private var continuation: CheckedContinuation<ProcessResult, Error>?
    private var finished = false
    private var cancelled = false

    init(executable: URL, arguments: [String], environment: [String: String]) {
        process.executableURL = executable
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        if !environment.isEmpty {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        }
    }

    func start(timeout: Double) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            self.continuation = continuation
            let alreadyCancelled = cancelled
            lock.unlock()
            if alreadyCancelled {
                finish(.failure(CancellationError()))
                return
            }

            let readers = DispatchGroup()
            read(stdoutPipe, isStdout: true, group: readers)
            read(stderrPipe, isStdout: false, group: readers)

            process.terminationHandler = { [self] process in
                // Give the pipe readers a moment to hit EOF. A grandchild that
                // inherited the pipe could keep it open forever; don't wait on it.
                DispatchQueue.global().async { [self] in
                    _ = readers.wait(timeout: .now() + 2)
                    lock.lock()
                    let result = ProcessResult(
                        exitCode: process.terminationStatus,
                        stdout: stdoutData,
                        stderr: stderrData
                    )
                    lock.unlock()
                    finish(.success(result))
                }
            }

            do {
                try process.run()
            } catch {
                finish(.failure(ProcessRunnerError.launchFailed(error.localizedDescription)))
                return
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [self] in
                if process.isRunning { process.terminate() }
                finish(.failure(ProcessRunnerError.timedOut(seconds: timeout)))
            }
        }
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
        if process.isRunning { process.terminate() }
        finish(.failure(CancellationError()))
    }

    private func read(_ pipe: Pipe, isStdout: Bool, group: DispatchGroup) {
        group.enter()
        DispatchQueue.global().async { [self] in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            lock.lock()
            if isStdout { stdoutData = data } else { stderrData = data }
            lock.unlock()
            group.leave()
        }
    }

    /// Resumes the continuation exactly once.
    private func finish(_ result: Result<ProcessResult, Error>) {
        lock.lock()
        guard !finished, let continuation else {
            lock.unlock()
            return
        }
        finished = true
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}
