import AppKit

extension AppDelegate {
    @MainActor func runGenerationVerification() {
        Task {
            let args = CommandLine.arguments
            guard let index = args.firstIndex(of: "--verify-generation"), args.count > index + 1 else { exit(1) }
            let directory = URL(fileURLWithPath: args[index + 1], isDirectory: true)
            var stage = "categories"
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let url = directory.appendingPathComponent("library.sqlite3")
                let library = PromptLibrary(repository: SQLitePromptRepository(url: url))
                let categories: [PromptCategory] = try await withCheckedThrowingContinuation { continuation in
                    library.load(.categories) { result in
                        switch result {
                        case .success(.categories(let values)): continuation.resume(returning: values)
                        case .failure(let error): continuation.resume(throwing: error)
                        default: continuation.resume(throwing: LibraryFailure.invalidCategory)
                        }
                    }
                }
                guard let firstCategory = categories.first else { throw LibraryFailure.invalidCategory }
                struct Sample: Decodable { let originalExperience: String; let source: String }
                let sample: Sample
                if args.count > index + 2 {
                    let data = try Data(contentsOf: URL(fileURLWithPath: args[index + 2]))
                    guard data.count <= 400_000 else { throw GenerationFailure.tooLong }
                    sample = try JSONDecoder().decode(Sample.self, from: data)
                } else { sample = Sample(originalExperience: "仅当 bug 可以稳定复现时，先写一个最小回归测试，确认修复前失败；再做最小修复并重跑相关测试。无法复现时，先记录观察和证据，不要用猜测改代码。", source: "本项目 AGENTS.md 的 bug 修复工作约定，人工摘录验收样本") }
                let raw = sample.originalExperience, source = sample.source
                let entry = PromptEntry(id: UUID().uuidString, categoryID: firstCategory.id, title: "", summary: "", originalExperience: raw, source: source, explanation: "", prompt: "")
                let draft = EditorDraft(entry: entry, original: nil)
                stage = "draft"
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in library.storeDraft(draft) { continuation.resume(with: $0) } }
                stage = "api"
                let candidate = try await DeepSeekClient().generate(experience: raw, source: source, categories: categories)
                let editor = PromptEditorView(draft: EditorDraft(entry: entry, original: nil, candidate: candidate), categories: categories)
                guard editor.value == entry else { throw LibraryFailure.conflict }
                editor.candidateEditor.fields[0].text.string += "（验收编辑）"
                editor.adoptCandidate()
                guard editor.value.originalExperience == raw, editor.value.source == source,
                      editor.value.title.hasSuffix("（验收编辑）") else { throw LibraryFailure.conflict }
                stage = "save"
                let saved: PromptEntry = try await withCheckedThrowingContinuation { continuation in library.saveDraft(editor.draft) { continuation.resume(with: $0) } }
                stage = "reopen"
                let reopened = PromptLibrary(repository: SQLitePromptRepository(url: url))
                let restored: PromptEntry = try await withCheckedThrowingContinuation { continuation in
                    reopened.load(.detail(saved.categoryID, saved.id)) { result in
                        switch result {
                        case .success(.detail(let value)): continuation.resume(returning: value)
                        case .failure(let error): continuation.resume(throwing: error)
                        default: continuation.resume(throwing: LibraryFailure.missingEntry)
                        }
                    }
                }
                guard restored == saved else { throw LibraryFailure.conflict }
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                // Only the public verification sample and generated candidate go into this local artifact.
                try encoder.encode(saved).write(to: directory.appendingPathComponent("generated-entry.json"), options: .atomic)
                let report: [String: Any] = ["passed": true, "model": DeepSeekClient.model, "buildID": BuildIdentity.current.buildID, "sourceFingerprint": BuildIdentity.current.sourceFingerprint, "realAPI": true, "candidateEdited": true, "originalAndSourcePreserved": true, "savedAndReopened": true, "realCodexInsertion": false]
                try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("report.json"), options: .atomic)
                print("Real API generation, candidate edit, SQLite save and reopen passed.")
                DiagnosticLog.shared.flush(); NSApp.terminate(nil)
            } catch {
                let code: Int
                switch error {
                case GenerationFailure.http(let status): code = status
                case GenerationFailure.keychain(let status): code = Int(status)
                default: code = (error as NSError).code
                }
                let report: [String: Any] = ["passed": false, "stage": stage, "systemCode": code]
                if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]) { try? data.write(to: directory.appendingPathComponent("report.json"), options: .atomic) }
                print("Generation verification failed at \(stage), code \(code).")
                DiagnosticLog.shared.flush(); exit(1)
            }
        }
    }
}
