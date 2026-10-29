import Foundation

/// Diagnostic comparisons only. None of these relaxed comparisons can authorize success.
struct InsertionObservation {
    let expectedUTF16Count: Int
    let observedUTF16Count: Int
    let expectedLineBreakCount: Int
    let observedLineBreakCount: Int
    let matchesCollapsingBlankLines: Bool
    let matchesIgnoringLineBreaks: Bool

    init(expected: String, observed: String) {
        func canonical(_ value: String) -> String {
            value.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        }
        let wanted = canonical(expected), actual = canonical(observed)
        expectedUTF16Count = expected.utf16.count
        observedUTF16Count = observed.utf16.count
        expectedLineBreakCount = wanted.filter { $0 == "\n" }.count
        observedLineBreakCount = actual.filter { $0 == "\n" }.count
        matchesCollapsingBlankLines = wanted.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
            == actual.replacingOccurrences(of: "\n{2,}", with: "\n", options: .regularExpression)
        matchesIgnoringLineBreaks = wanted.replacingOccurrences(of: "\n", with: "") == actual.replacingOccurrences(of: "\n", with: "")
    }
}
