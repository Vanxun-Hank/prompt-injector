import AppKit

extension AppDelegate {
    @MainActor func applyExperienceReview() {
        struct Review: Decodable { let entry: PromptEntry; let original: PromptEntry }
        Task {
            guard let index = CommandLine.arguments.firstIndex(of: "--apply-experiment-review"), CommandLine.arguments.count > index + 1 else { exit(1) }
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
                guard data.count <= 2_000_000 else { throw GenerationFailure.tooLong }
                let reviews = try JSONDecoder().decode([Review].self, from: data)
                guard reviews.count <= 100, reviews.allSatisfy({ $0.entry.id == $0.original.id && $0.entry.originalExperience == $0.original.originalExperience && $0.entry.source == $0.original.source }) else { throw LibraryFailure.conflict }
                let library = PromptLibrary()
                for review in reviews {
                    let _: PromptEntry = try await withCheckedThrowingContinuation { continuation in
                        library.saveDraft(EditorDraft(entry: review.entry, original: review.original)) { continuation.resume(with: $0) }
                    }
                }
                print("Applied \(reviews.count) reviewed entries; originals and sources preserved.")
                DiagnosticLog.shared.flush(); NSApp.terminate(nil)
            } catch { print("Review save refused, code \((error as NSError).code)."); exit(1) }
        }
    }

    // Explicit maintenance experiment: user-provided input, real API, formal local save, no target capture.
    @MainActor func runExperienceExperiment() {
        struct Input: Decodable { let id: String; let originalExperience: String; let source: String }
        Task {
            let args = CommandLine.arguments
            guard let index = args.firstIndex(of: "--experiment-experiences"), args.count > index + 2 else { exit(1) }
            let directory = URL(fileURLWithPath: args[index + 2], isDirectory: true)
            var results: [[String: Any]] = []
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: args[index + 1]))
                guard data.count <= 2_000_000 else { throw GenerationFailure.tooLong }
                let input = try JSONDecoder().decode([Input].self, from: data)
                guard !input.isEmpty, input.count <= 100, Set(input.map(\.id)).count == input.count,
                      input.allSatisfy({ UUID(uuidString: $0.id) != nil }) else { throw LibraryFailure.invalidFields }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                let library = PromptLibrary(), staging = PromptLibrary(repository: SQLitePromptRepository(url: directory.appendingPathComponent("drafts.sqlite3")))
                let client = DeepSeekClient(), encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let existing: [ManagedSummary] = try await withCheckedThrowingContinuation { continuation in
                    library.manage(category: nil, query: "") { continuation.resume(with: $0) }
                }
                for (offset, item) in input.enumerated() {
                    let number = offset + 1
                    if existing.contains(where: { $0.summary.id == item.id }) {
                        results.append(["number": number, "id": item.id, "status": "already-exists"]); continue
                    }
                    do {
                        let categories: [PromptCategory] = try await withCheckedThrowingContinuation { continuation in
                            library.load(.categories) { result in
                                switch result {
                                case .success(.categories(let values)): continuation.resume(returning: values)
                                case .failure(let error): continuation.resume(throwing: error)
                                default: continuation.resume(throwing: LibraryFailure.invalidCategory)
                                }
                            }
                        }
                        guard let first = categories.first else { throw LibraryFailure.invalidCategory }
                        let entry = PromptEntry(id: item.id, categoryID: first.id, title: "", summary: "", originalExperience: item.originalExperience, source: item.source, explanation: "", prompt: "")
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            staging.storeDraft(EditorDraft(entry: entry, original: nil)) { continuation.resume(with: $0) }
                        }
                        let candidate = try await client.generate(experience: item.originalExperience, source: item.source, categories: categories)
                        let editor = PromptEditorView(draft: EditorDraft(entry: entry, original: nil, candidate: candidate), categories: categories)
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            staging.storeDraft(editor.draft) { continuation.resume(with: $0) }
                        }
                        editor.adoptCandidate()
                        guard editor.value.originalExperience == item.originalExperience, editor.value.source == item.source,
                              !editor.value.prompt.isEmpty else { throw LibraryFailure.conflict }
                        let saved: PromptEntry = try await withCheckedThrowingContinuation { continuation in
                            library.saveDraft(editor.draft) { continuation.resume(with: $0) }
                        }
                        try encoder.encode(saved).write(to: directory.appendingPathComponent(String(format: "%02d.json", number)), options: .atomic)
                        results.append(["number": number, "id": saved.id, "categoryID": saved.categoryID, "status": "saved"])
                        print("Saved \(number)/\(input.count)"); fflush(stdout)
                    } catch {
                        results.append(["number": number, "id": item.id, "status": "failed", "systemCode": (error as NSError).code])
                        print("Failed \(number)/\(input.count)"); fflush(stdout)
                    }
                    let report: [String: Any] = ["model": DeepSeekClient.model, "realAPI": true, "results": results, "buildID": BuildIdentity.current.buildID]
                    try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("report.json"), options: .atomic)
                }
                await withCheckedContinuation { continuation in library.flush { continuation.resume() } }
                DiagnosticLog.shared.flush()
                if results.contains(where: { $0["status"] as? String == "failed" }) { exit(1) }
                NSApp.terminate(nil)
            } catch { print("Experiment failed before completion, code \((error as NSError).code)."); exit(1) }
        }
    }
}
