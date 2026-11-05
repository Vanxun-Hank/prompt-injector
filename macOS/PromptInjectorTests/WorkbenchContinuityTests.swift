import XCTest
@testable import PromptInjector

final class WorkbenchContinuityTests: XCTestCase {
    @MainActor private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<300 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Workbench operation timed out")
        throw CancellationError()
    }

    @MainActor func testIdentifyTwentyRemoveThreeThenRemoveLastAndReopen() async throws {
        let (dir, repo) = ExperienceTests().repository()
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = ControlledExperienceService()
        let model = ExperienceController(session: .init(), library: PromptLibrary(repository: repo), service: service)
        let items = (1...20).map { ExperienceItem(title: "经验\($0)", original: "第\($0)条原文。") }
        model.changeInput(items.map(\.original).joined(separator: "\n")); model.send()
        try await waitFor { service.identifyCalls.count == 1 }
        service.identifyCalls[0].1.resume(returning: items); try await waitFor { !model.busy }
        model.choose(items[6].id); model.toggle(items[6].id); model.toggle(items[8].id)
        for index in [6, 3, 19] { model.remove(items[index].id) }
        XCTAssertEqual(model.current?.id, items[7].id)
        XCTAssertEqual(model.session.items.count, 17); XCTAssertEqual(model.session.selected.map(\.id), [items[8].id])
        try await model.finish()
        let reopened = SQLitePromptRepository(url: dir.appendingPathComponent("library.sqlite3"))
        XCTAssertEqual(try reopened.experienceDraft()?.items.map(\.id), model.session.items.map(\.id))
        model.session.items.forEach { model.remove($0.id) }; try await model.finish()
        XCTAssertNil(model.current); XCTAssertFalse(model.showingInput)
        XCTAssertEqual(try reopened.experienceDraft()?.items.count, 0)
        XCTAssertTrue(service.organizeCalls.isEmpty)
        XCTAssertFalse(try reopened.managedSummaries(category: nil, query: "").contains { items.map(\.id).contains($0.summary.id) })
        model.beginAddition(); XCTAssertTrue(model.showingInput)
    }

    @MainActor func testRemovingActiveAndQueuedItemsContinuesOtherTasksBeforeLateReply() async throws {
        let fixtures = ExperienceTests(), (dir, repo) = fixtures.repository()
        defer { try? FileManager.default.removeItem(at: dir) }
        var session = fixtures.session()
        session.items += [.init(title: "排队移除", original: session.raw), .init(title: "继续生成", original: session.raw)]
        let ids = session.items.map(\.id), service = ControlledExperienceService()
        let model = ExperienceController(session: session, library: PromptLibrary(repository: repo), service: service)
        model.updateCandidate(ids[1], fixtures.candidate("保留手改"))
        ids.forEach(model.toggle); model.generateSelected()
        try await waitFor { service.organizeCalls.count == 1 }
        model.remove(ids[2]); XCTAssertEqual(model.activeItemID, ids[0])
        model.remove(ids[0]); try await waitFor { service.organizeCalls.count == 2 }
        XCTAssertEqual(model.current?.id, ids[1]); XCTAssertEqual(model.activeItemID, ids[1])
        service.organizeCalls[0].2.resume(returning: fixtures.candidate("迟到，不得复活"))
        service.organizeCalls[1].2.resume(returning: fixtures.candidate("新建议"))
        try await waitFor { service.organizeCalls.count == 3 }
        XCTAssertEqual(service.organizeCalls.map { $0.0.id }, [ids[0], ids[1], ids[3]])
        service.organizeCalls[2].2.resume(returning: fixtures.candidate("剩余任务成功")); try await waitFor { !model.busy }
        try await model.finish()
        let stored = try XCTUnwrap(repo.experienceDraft())
        XCTAssertEqual(stored.items.map(\.id), [ids[1], ids[3]])
        XCTAssertEqual(stored.items[0].candidate?.title, "保留手改")
        XCTAssertEqual(stored.items[0].suggestion?.title, "新建议")
        XCTAssertEqual(stored.items[1].candidate?.title, "剩余任务成功")
    }

    @MainActor func testLegacyAndAppendedArticlesKeepContextEditsAndSourceThroughSaveAndReopen() async throws {
        let fixtures = ExperienceTests(), (dir, repo) = fixtures.repository()
        defer { try? FileManager.default.removeItem(at: dir) }
        let legacy = fixtures.session(), oldID = legacy.items[0].id, service = ControlledExperienceService()
        let model = ExperienceController(session: legacy, library: PromptLibrary(repository: repo), service: service)
        let second = "第二篇文章的全局条件。\n第二篇的经验。", secondSource = "https://github.com/example/project"
        model.updateCandidate(oldID, fixtures.candidate("我的修改")); model.toggle(oldID); model.confirm(oldID)
        model.beginAddition(); model.changeInput(second); model.changeSource(secondSource); model.send()
        try await waitFor { service.identifyCalls.count == 1 }
        let added = ExperienceItem(title: "第二篇", original: "第二篇的经验。")
        service.identifyCalls[0].1.resume(returning: [added]); try await waitFor { !model.busy }
        XCTAssertEqual(model.session.items[0].candidate?.title, "我的修改")
        XCTAssertEqual(model.session.confirmed.map(\.id), [oldID]); XCTAssertEqual(model.session.selected.map(\.id), [oldID])
        try await model.finish()
        let restored = ExperienceController(session: try XCTUnwrap(repo.experienceDraft()), library: PromptLibrary(repository: repo), service: service)
        restored.generateCurrent(); try await waitFor { service.organizeCalls.count == 1 }
        XCTAssertEqual(service.organizeOrigins[0], .init(raw: second, source: secondSource))
        service.organizeCalls[0].2.resume(returning: fixtures.candidate("第二篇 Prompt")); try await waitFor { !restored.busy }
        restored.choose(oldID); restored.generateCurrent(); try await waitFor { service.organizeCalls.count == 2 }
        XCTAssertEqual(service.organizeOrigins[1], .init(raw: legacy.raw, source: legacy.source))
        service.organizeCalls[1].2.resume(returning: fixtures.candidate("仅比较")); try await waitFor { !restored.busy }
        restored.save(); try await waitFor { !restored.saving }
        XCTAssertEqual(try repo.entry(id: oldID, category: "coding")?.source, legacy.source)
        XCTAssertEqual(try repo.entry(id: oldID, category: "coding")?.title, "我的修改")
        restored.remove(legacy.items[1].id)
        XCTAssertEqual(restored.current?.id, added.id)
        restored.confirm(added.id); restored.save(); try await waitFor { !restored.saving }
        let entry = try XCTUnwrap(repo.entry(id: added.id, category: "coding"))
        XCTAssertEqual(entry.source, secondSource); XCTAssertEqual(entry.originalExperience, added.original)
        XCTAssertNil(try repo.experienceDraft())
    }

    @MainActor func testFailedCancelledAndInterruptedAdditionPreserveExistingDraftAndPendingInput() async throws {
        let fixtures = ExperienceTests(), (dir, repo) = fixtures.repository()
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = ControlledExperienceService(), initial = fixtures.session()
        let model = ExperienceController(session: initial, library: PromptLibrary(repository: repo), service: service)
        let oldID = initial.items[0].id, pending = "第二篇还没有整理完成。"
        model.beginAddition(); model.changeInput(pending); model.changeSource("第二位作者"); model.send()
        try await waitFor { service.identifyCalls.count == 1 }
        service.identifyCalls[0].1.resume(throwing: URLError(.timedOut)); try await waitFor { !model.busy }
        XCTAssertTrue(model.failed); XCTAssertEqual(model.session.intake.input, pending)
        model.choose(oldID); model.updateCandidate(oldID, fixtures.candidate("失败后仍可编辑")); model.confirm(oldID)
        model.beginAddition(); XCTAssertEqual(model.session.intake.input, pending); model.send()
        try await waitFor { service.identifyCalls.count == 2 }
        model.cancel(); XCTAssertEqual(model.session.intake.input, pending)
        model.send(); try await waitFor { service.identifyCalls.count == 3 }
        try await model.finish()
        for index in [1, 2] { service.identifyCalls[index].1.resume(returning: [.init(title: "迟到", original: pending)]) }
        let stored = try XCTUnwrap(repo.experienceDraft())
        let resumed = ExperienceController(session: stored, library: PromptLibrary(repository: repo), service: service)
        XCTAssertTrue(resumed.showingInput); XCTAssertEqual(resumed.session.intake.input, pending)
        XCTAssertEqual(resumed.session.intake.origin.source, "第二位作者")
        XCTAssertEqual(resumed.session.items.map(\.id), initial.items.map(\.id))
        XCTAssertEqual(resumed.session.confirmed.first?.candidate?.title, "失败后仍可编辑")
        resumed.remove(initial.items[1].id); resumed.save(); try await waitFor { !resumed.saving }
        XCTAssertEqual(try repo.experienceDraft()?.addition?.input, pending)
        resumed.cancelAddition(); try await resumed.finish()
        XCTAssertNil(try repo.experienceDraft()?.addition)
        XCTAssertEqual(try repo.entry(id: oldID, category: "coding")?.source, initial.source)
        XCTAssertTrue(model.session.items.count == 2)
    }
}
