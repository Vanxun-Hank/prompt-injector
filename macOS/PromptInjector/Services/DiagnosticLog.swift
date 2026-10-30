import Foundation
import Darwin

enum DiagnosticEvent: String, Codable, Sendable {
    case appStopping = "app.stopping"
    case appStarted = "app.started", appStopped = "app.stopped", libraryFailed = "library.load_failed"
    case permissionChanged = "permission.changed", permissionRequested = "permission.requested"
    case shortcutRegistered = "shortcut.registered", shortcutFailed = "shortcut.failed", preferenceInvalid = "preference.invalid"
    case launcherReady = "launcher.ready", launcherSettled = "launcher.settled"
    case launcherShown = "launcher.shown", launcherHidden = "launcher.hidden", pageChanged = "page.changed"
    case copySucceeded = "copy.succeeded", copyFailed = "copy.failed"
    case captureStarted = "capture.started", captureReady = "capture.ready", captureFailed = "capture.failed"
    case insertionStarted = "insertion.started", insertionStage = "insertion.stage", writeRequested = "insertion.write_requested"
    case insertionVerified = "insertion.verified", insertionUnconfirmed = "insertion.unconfirmed", insertionFailed = "insertion.failed"
    case insertionBlocked = "insertion.blocked"
    case clipboardRestored = "clipboard.restored", clipboardKept = "clipboard.kept"
    case storageOpened = "storage.opened", storageMigrating = "storage.migrating", storageQuery = "storage.query", storageFailed = "storage.failed"
    case storageSaved = "storage.saved", draftSaved = "draft.saved", usageRecorded = "usage.recorded"
    case probe = "diagnostics.probe"
}

enum DiagnosticLevel: String, Codable, Sendable { case info, warning, error }

/// Deliberately no arbitrary payload, message, prompt, input text, clipboard data or source URL.
struct DiagnosticFields: Codable, Sendable {
    var captureID: UUID? = nil
    var stage: String? = nil
    var result: String? = nil
    var errorCode: String? = nil
    var systemCode: Int? = nil
    var method: String? = nil
    var targetBundleID: String? = nil
    var role: String? = nil
    var beforeUTF16Count: Int? = nil
    var observedUTF16Count: Int? = nil
    var promptUTF16Count: Int? = nil
    var textReadable: Bool? = nil
    var selectionReadable: Bool? = nil
    var selectionWritable: Bool? = nil
    var valueWritable: Bool? = nil
    var targetEnabled: Bool? = nil
    var targetEditable: Bool? = nil
    var trusted: Bool? = nil
    var fromLevel: Int? = nil
    var toLevel: Int? = nil
    var shortcutIndex: Int? = nil
    var preference: String? = nil
    var elapsedMilliseconds: Int? = nil
    var rowCount: Int? = nil
    var selectionLocation: Int? = nil
    var selectionLength: Int? = nil
    var expectedUTF16Count: Int? = nil
    var expectedLineBreakCount: Int? = nil
    var observedLineBreakCount: Int? = nil
    var matchesCollapsingBlankLines: Bool? = nil
    var matchesIgnoringLineBreaks: Bool? = nil
}

struct BuildIdentity: Codable, Sendable {
    let version: String
    let buildID: String
    let sourceFingerprint: String
    let revision: String
    static var current: Self {
        let info = Bundle.main.infoDictionary ?? [:]
        return .init(version: info["CFBundleShortVersionString"] as? String ?? "development",
                     buildID: info["PIBuildID"] as? String ?? "unpackaged",
                     sourceFingerprint: info["PISourceFingerprint"] as? String ?? "unknown",
                     revision: info["PIRevision"] as? String ?? "unversioned")
    }
}

struct DiagnosticRecord: Codable {
    let schemaVersion: Int
    let timestamp: Date
    let sessionID: UUID
    let operationID: UUID?
    let sequence: UInt64
    let pid: Int32
    let build: BuildIdentity
    let systemVersion: String
    let mode: String
    let level: DiagnosticLevel
    let event: DiagnosticEvent
    let fields: DiagnosticFields
}

/// Bounded JSONL, serialized off the main thread. A lock also protects rotation across app instances.
final class DiagnosticLog: @unchecked Sendable {
    static let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Prompt Injector", isDirectory: true)
    static let shared = DiagnosticLog(directory: directory)
    let directoryURL: URL
    let sessionID: UUID
    private let build: BuildIdentity
    private let mode: String
    private let maxFileBytes: Int
    private let archiveCount: Int
    private let queue = DispatchQueue(label: "com.promptinjector.diagnostics", qos: .utility)
    private let queueKey = DispatchSpecificKey<Bool>()
    private var sequence: UInt64 = 0
    private var writeError: Int?

    init(directory: URL, build: BuildIdentity = .current, sessionID: UUID = UUID(), maxFileBytes: Int = 1_048_576, archiveCount: Int = 3, mode: String? = nil) {
        directoryURL = directory; self.build = build; self.sessionID = sessionID
        self.maxFileBytes = max(2048, maxFileBytes); self.archiveCount = max(0, archiveCount)
        self.mode = mode ?? (CommandLine.arguments.contains("--verify-ui") ? "ui-verification" : CommandLine.arguments.contains("--verify-termination") ? "headless-verification" : "application")
        queue.setSpecific(key: queueKey, value: true)
    }

    func write(_ event: DiagnosticEvent, level: DiagnosticLevel = .info, operationID: UUID? = nil, fields: DiagnosticFields = .init()) {
        let timestamp = Date()
        queue.async { [self] in
            sequence += 1
            let record = DiagnosticRecord(schemaVersion: 1, timestamp: timestamp, sessionID: sessionID, operationID: operationID,
                                          sequence: sequence, pid: ProcessInfo.processInfo.processIdentifier, build: build,
                                          systemVersion: ProcessInfo.processInfo.operatingSystemVersionString, mode: mode,
                                          level: level, event: event, fields: fields)
            do {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
                encoder.dateEncodingStrategy = .iso8601
                var line = try encoder.encode(record); line.append(0x0A)
                guard line.count <= maxFileBytes else { throw CocoaError(.fileWriteOutOfSpace) }
                try append(line)
            } catch {
                if writeError == nil {
                    // Do not echo localized errors (which may contain user paths) into another log.
                    fputs("Prompt Injector: diagnostic log unavailable; app operations continue.\n", stderr)
                }
                writeError = (error as NSError).code
            }
        }
    }

    func flush() {
        if DispatchQueue.getSpecific(key: queueKey) == nil { queue.sync {} }
    }
    var lastWriteErrorCode: Int? {
        if DispatchQueue.getSpecific(key: queueKey) != nil { return writeError }
        return queue.sync { writeError }
    }

    private func append(_ line: Data) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let lockPath = directoryURL.appendingPathComponent(".writer.lock").path
        let lock = Darwin.open(lockPath, O_CREAT | O_WRONLY, 0o600)
        guard lock >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(lock) }
        guard flock(lock, LOCK_EX) == 0 else { throw POSIXError(.EIO) }
        defer { flock(lock, LOCK_UN) }
        let active = directoryURL.appendingPathComponent("events.jsonl")
        let size = (try? fm.attributesOfItem(atPath: active.path)[.size] as? NSNumber)?.intValue ?? 0
        if size + line.count > maxFileBytes { try rotate(active, manager: fm) }
        if !fm.fileExists(atPath: active.path) {
            guard fm.createFile(atPath: active.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw CocoaError(.fileWriteUnknown) }
        }
        let handle = try FileHandle(forWritingTo: active)
        defer { try? handle.close() }
        try handle.seekToEnd(); try handle.write(contentsOf: line)
    }

    private func rotate(_ active: URL, manager fm: FileManager) throws {
        if archiveCount == 0 { if fm.fileExists(atPath: active.path) { try fm.removeItem(at: active) }; return }
        func archive(_ index: Int) -> URL { directoryURL.appendingPathComponent("events.\(index).jsonl") }
        let oldest = archive(archiveCount)
        if fm.fileExists(atPath: oldest.path) { try fm.removeItem(at: oldest) }
        if archiveCount > 1 {
            for index in stride(from: archiveCount - 1, through: 1, by: -1) {
                let source = archive(index)
                if fm.fileExists(atPath: source.path) { try fm.moveItem(at: source, to: archive(index + 1)) }
            }
        }
        if fm.fileExists(atPath: active.path) { try fm.moveItem(at: active, to: archive(1)) }
    }
}
