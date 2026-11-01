import AppKit

if let index = CommandLine.arguments.firstIndex(of: "--import-deepseek-key-file"), CommandLine.arguments.count > index + 1 {
    do {
        try DeepSeekKeychain.importFile(URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        DiagnosticLog.shared.flush(); print("Keychain saved and verified; temporary input file cleared."); exit(0)
    } catch { fputs("Key import failed; input file retained.\n", stderr); exit(1) }
}

MainActor.assumeIsolated {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.run()
}
