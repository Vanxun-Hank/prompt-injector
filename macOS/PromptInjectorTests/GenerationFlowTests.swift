import XCTest
import AppKit
@testable import PromptInjector

@MainActor private final class ControlledGenerator: PromptGenerating {
    struct Call {
        let experience: String, source: String
        let categories: [PromptCategory]
        let continuation: CheckedContinuation<GeneratedPrompt, Error>
    }
    var calls: [Call] = []
    func generate(experience: String, source: String, categories: [PromptCategory]) async throws -> GeneratedPrompt {
        try await withCheckedThrowingContinuation { calls.append(Call(experience: experience, source: source, categories: categories, continuation: $0)) }
    }
}

final class GenerationFlowTests: XCTestCase {
    @MainActor private func until(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Generation flow timed out")
    }
    @MainActor func testDraftBeforeRequestFailureRetryCancellationAndLateResponseKeepManualEdits() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repository = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3")), library = PromptLibrary(repository: repository)
        let generator = ControlledGenerator(), form = ManagementWindowController(library: library, generator: generator)
        form.newEntry(); try await until { form.root.editor != nil }
        let editor = try XCTUnwrap(form.root.editor)
        editor.originalText.text.string = "仅在能复现 bug 时，先写失败测试再修复。"
        editor.sourceField.stringValue = "本人粘贴 https://example.com"
        editor.titleField.stringValue = "手改标题"
        editor.promptText.text.string = "手改 Prompt"
        let initial = editor.value
        form.generatePrompt(); try await until { generator.calls.count == 1 }
        XCTAssertEqual(try repository.editorDraft()?.entry, initial)
        XCTAssertEqual(generator.calls[0].experience, initial.originalExperience)
        XCTAssertEqual(generator.calls[0].source, initial.source)
        XCTAssertEqual(generator.calls[0].categories.map(\.id), try repository.categories().map(\.id))
        generator.calls[0].continuation.resume(throwing: URLError(.timedOut))
        try await until { !form.isGenerating }
        XCTAssertEqual(editor.value, initial); XCTAssertTrue(form.root.requiredLabel.stringValue.contains("超时"))
        let added = try repository.saveDraft(EditorDraft(entry: GenerationTests().entry(), original: nil, newCategoryName: "模型选择"))
        form.generatePrompt(); try await until { generator.calls.count == 2 }
        XCTAssertEqual(generator.calls[1].categories.last?.id, added.categoryID)
        XCTAssertEqual(generator.calls[1].categories.count, 6)
        form.cancelGeneration()
        editor.promptText.text.string = "取消后手改"
        editor.textDidChange(Notification(name: NSText.didChangeNotification))
        let manual = editor.value
        let candidate = GeneratedPrompt(title: "候选", summary: "适用条件", explanation: "解释", prompt: "明确指令", categoryID: nil, newCategoryName: "学习")
        generator.calls[1].continuation.resume(returning: candidate)
        await withCheckedContinuation { continuation in library.flush { continuation.resume() } }
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(editor.value, manual); XCTAssertNil(editor.candidate)
        form.generatePrompt(); try await until { generator.calls.count == 3 }
        editor.titleField.stringValue = "请求中编辑"
        editor.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: editor.titleField))
        XCTAssertFalse(form.isGenerating)
        XCTAssertTrue(form.root.requiredLabel.stringValue.contains("取消"))
        generator.calls[2].continuation.resume(returning: candidate)
        try await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(editor.value.title, "请求中编辑"); XCTAssertNil(editor.candidate)
        form.generatePrompt(); try await until { generator.calls.count == 4 }
        generator.calls[3].continuation.resume(returning: candidate)
        try await until { editor.candidate != nil }
        XCTAssertEqual(editor.value.prompt, manual.prompt)
        editor.candidateEditor.fields[0].text.string = "候选内已修改"
        editor.candidateEditor.textDidChange(Notification(name: NSText.didChangeNotification))
        let editedCandidate = try XCTUnwrap(editor.candidate)
        form.confirmCandidateReplacement = { false }
        form.generatePrompt()
        XCTAssertFalse(form.isGenerating); XCTAssertEqual(generator.calls.count, 4); XCTAssertEqual(editor.candidate, editedCandidate)
        form.confirmCandidateReplacement = { true }
        form.generatePrompt(); try await until { generator.calls.count == 5 }
        generator.calls[4].continuation.resume(throwing: URLError(.notConnectedToInternet))
        try await until { !form.isGenerating }
        XCTAssertEqual(editor.candidate, editedCandidate)
        form.prepareForTermination { _ in }
        await withCheckedContinuation { continuation in library.flush { continuation.resume() } }
        XCTAssertEqual(try repository.editorDraft()?.candidate, editedCandidate)
        let resumed = ManagementWindowController(library: library, generator: generator)
        resumed.newEntry(); try await until { resumed.root.editor != nil }
        let restored = try XCTUnwrap(resumed.root.editor)
        XCTAssertEqual(restored.candidate, editedCandidate)
        restored.adoptCandidate()
        XCTAssertEqual(restored.value.originalExperience, initial.originalExperience)
        XCTAssertEqual(restored.value.source, initial.source)
        XCTAssertEqual(restored.draft.newCategoryName, "学习")
        resumed.saveEditor(); try await until { !resumed.isSaving && resumed.root.editor == nil && resumed.root.categoryItems.count == 7 }
        XCTAssertEqual(try repository.categories().last?.name, "学习")
        XCTAssertEqual(resumed.root.categoryItems.count, 7)
        XCTAssertEqual(try repository.categories().last?.entryCount, 1)
    }
}
