import Foundation

struct InsertionPlan {
    let before: String
    let range: NSRange
    let prompt: String
    let expected: String

    init?(before: String, range: NSRange, prompt: String) {
        let length = (before as NSString).length
        guard range.location != NSNotFound, range.location >= 0, range.length >= 0,
              range.location <= length, range.length <= length - range.location else { return nil }
        let units = Array(before.utf16)
        func scalarBoundary(_ offset: Int) -> Bool {
            guard offset > 0 && offset < units.count else { return true }
            return !((0xD800...0xDBFF).contains(units[offset - 1]) && (0xDC00...0xDFFF).contains(units[offset]))
        }
        guard scalarBoundary(range.location), scalarBoundary(range.location + range.length) else { return nil }
        self.before = before; self.range = range; self.prompt = prompt
        expected = (before as NSString).replacingCharacters(in: range, with: prompt)
    }

    func matches(_ actual: String) -> Bool {
        // AX providers can expose CRLF instead of LF. Do not trim content or accept just a prefix.
        func canonical(_ value: String) -> String {
            value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        }
        return canonical(actual) == canonical(expected)
    }
}
