import XCTest
import LearnCore
@testable import LearnToLearn

final class AppIntegrationTests: XCTestCase {
    private func temporaryRepository() -> LibraryRepository {
        .init(url: FileManager.default.temporaryDirectory.appendingPathComponent("LearnToLearnTests-\(UUID())").appendingPathComponent("library.json"))
    }
    func testImportsAppendWithoutReplacingProgressAndSurviveRestart() async throws {
        let repository = temporaryRepository()
        defer { try? FileManager.default.removeItem(at: repository.url.deletingLastPathComponent()) }
        try await MainActor.run {
            let store = AppStore(repository: repository)
            let cardID = try XCTUnwrap(store.library.cards.first?.id)
            XCTAssertTrue(store.review(cardID, rating: .good))
            XCTAssertTrue(store.importPackage(Demo.package, into: nil))
            XCTAssertTrue(store.importPackage(Demo.package, into: nil))
            XCTAssertEqual(store.library.modules.count, 9)
            XCTAssertEqual(store.library.cards.count, 42)
            XCTAssertEqual(Set(store.library.cards.map(\.id)).count, 42)
            XCTAssertEqual(store.card(cardID)?.progress.repetitions, 1)
            let restarted = AppStore(repository: repository)
            XCTAssertEqual(restarted.library.cards.count, 42)
            XCTAssertEqual(restarted.library.reviews.count, 1)
            XCTAssertEqual(restarted.card(cardID)?.progress.repetitions, 1)
        }
    }
    func testCreateEditImportIntoModuleAndDelete() async throws {
        let repository = temporaryRepository()
        defer { try? FileManager.default.removeItem(at: repository.url.deletingLastPathComponent()) }
        try await MainActor.run {
            let store = AppStore(repository: repository)
            let module = LearningModule(title: "Eigenes Modul")
            store.saveModule(module)
            let set = LearningSet(title: "Kapitel 1")
            store.saveSet(set, moduleID: module.id)
            var card = LearningCard(type: .flashcard, prompt: "Eine Frage", answer: "Eine Antwort")
            store.saveCard(card, moduleID: module.id, setID: set.id)
            card.answer = "Neue Antwort"
            store.saveCard(card, moduleID: module.id, setID: set.id)
            XCTAssertEqual(store.set(set.id, module: module.id)?.cards.count, 1)
            XCTAssertEqual(store.card(card.id)?.answer, "Neue Antwort")
            XCTAssertTrue(store.review(card.id, rating: .easy))
            XCTAssertTrue(store.importPackage(Demo.package, into: module.id))
            XCTAssertEqual(store.module(module.id)?.sets.count, 4)
            XCTAssertEqual(store.library.modules.count, 4)
            store.delete(.card(module.id, set.id, card))
            XCTAssertNil(store.card(card.id))
            XCTAssertEqual(store.library.reviews.count, 1)
            store.delete(.module(try XCTUnwrap(store.module(module.id))))
            XCTAssertNil(try repository.load()?.modules.first { $0.id == module.id })
        }
    }
    func testInvalidChangesDoNotReplacePersistedLibrary() async throws {
        let repository = temporaryRepository()
        defer { try? FileManager.default.removeItem(at: repository.url.deletingLastPathComponent()) }
        try await MainActor.run {
            let store = AppStore(repository: repository)
            XCTAssertFalse(store.commit { $0.modules[0].sets[0].cards[0].prompt = "" })
            XCTAssertEqual(store.library.cards.count, 14)
            XCTAssertFalse(store.library.cards[0].prompt.isEmpty)
            XCTAssertEqual(try repository.load()?.cards.count, 14)
            XCTAssertNotNil(store.error)
        }
    }
    func testCorruptionBlocksWritesAndBackupCanRestore() async throws {
        let repository = temporaryRepository()
        defer { try? FileManager.default.removeItem(at: repository.url.deletingLastPathComponent()) }
        try repository.save(Demo.library)
        let backup = try LibraryRepository.encodeBackup(Demo.library)
        let broken = Data("unreadable library".utf8)
        try broken.write(to: repository.url)
        try await MainActor.run {
            let store = AppStore(repository: repository)
            XCTAssertTrue(store.storageBlocked)
            XCTAssertFalse(store.commit { $0.dailyGoal = 50 })
            XCTAssertEqual(try Data(contentsOf: repository.url), broken)
            try store.restoreBackup(data: backup)
            XCTAssertFalse(store.storageBlocked)
            XCTAssertEqual(store.library.cards.count, 14)
            XCTAssertTrue(store.commit { $0.dailyGoal = 35 })
            XCTAssertEqual(try repository.load()?.dailyGoal, 35)
            let files = try FileManager.default.contentsOfDirectory(at: repository.url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
            let preserved = try XCTUnwrap(files.first { $0.lastPathComponent.hasPrefix("library-before-restore-") })
            XCTAssertEqual(try Data(contentsOf: preserved), broken)
        }
    }
}
