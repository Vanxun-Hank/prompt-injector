import Foundation

@MainActor enum InsertionPreflight {
    static func failure(permissionGranted: Bool, captureFailure: InjectionService.Failure?) -> InjectionService.Failure? {
        if !permissionGranted { return .permission }
        if captureFailure == .permission { return .recaptureRequired }
        return captureFailure
    }
}
