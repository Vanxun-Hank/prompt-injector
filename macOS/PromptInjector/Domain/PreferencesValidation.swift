import Foundation

enum ShortcutPreference {
    static func resolve(_ stored: Int, optionCount: Int) -> Int {
        guard optionCount > 0, (0..<optionCount).contains(stored) else { return 0 }
        return stored
    }
}

enum WindowGeometry {
    static func isValidSavedFrame(_ frame: CGRect) -> Bool {
        [frame.origin.x, frame.origin.y, frame.width, frame.height, frame.maxX, frame.maxY].allSatisfy(\.isFinite)
            && frame.width > 0 && frame.height > 0
    }
}
