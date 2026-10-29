import AppKit

@MainActor final class PasteboardTransaction {
    enum Failure: Error { case unreadable, changed, writeFailed }
    private let pasteboard: NSPasteboard
    private let previous: [[(NSPasteboard.PasteboardType, Data)]]
    private let ownedCount: Int
    private let text: String

    init(text: String, pasteboard: NSPasteboard = .general) throws {
        self.pasteboard = pasteboard
        self.text = text
        let initialCount = pasteboard.changeCount
        previous = try (pasteboard.pasteboardItems ?? []).map { item in
            try item.types.map { type in
                guard let data = item.data(forType: type) else { throw Failure.unreadable }
                return (type, data)
            }
        }
        guard pasteboard.changeCount == initialCount else { throw Failure.changed }
        let clearedCount = pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            if pasteboard.changeCount == clearedCount { Self.write(previous, to: pasteboard) }
            throw Failure.writeFailed
        }
        ownedCount = pasteboard.changeCount
    }

    var stillOwned: Bool { pasteboard.changeCount == ownedCount && pasteboard.string(forType: .string) == text }

    @discardableResult func restoreIfOwned() -> Bool {
        guard stillOwned else { return false }
        pasteboard.clearContents()
        Self.write(previous, to: pasteboard)
        return true
    }
    private static func write(_ snapshot: [[(NSPasteboard.PasteboardType, Data)]], to pasteboard: NSPasteboard) {
        let items = snapshot.map { values -> NSPasteboardItem in
            let item = NSPasteboardItem()
            values.forEach { item.setData($0.1, forType: $0.0) }
            return item
        }
        pasteboard.writeObjects(items)
    }
}
