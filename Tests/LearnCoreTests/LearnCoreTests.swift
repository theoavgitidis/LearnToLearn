import XCTest
@testable import LearnCore

final class LearnCoreTests: XCTestCase {
    func testAllQuestionTypesRoundTrip() throws {
        let package = Demo.package
        let decoded = try LearningPackage.decode(package.encoded())
        XCTAssertEqual(decoded.cardCount, 14)
        let cards = decoded.materialize().flatMap(\.cards)
        XCTAssertEqual(Set(cards.map(\.type)), Set(QuestionType.allCases))
        XCTAssertEqual(cards.count, Set(cards.map(\.id)).count)
        XCTAssertNotEqual(decoded.materialize().first?.id, decoded.materialize().first?.id)
    }
    func testMultipleChoiceRejectsInvalidIndices() {
        var card = CardPayload(LearningCard(type: .multipleChoice, prompt: "Test", options: ["A", "B"], correctIndices: [2]))
        XCTAssertThrowsError(try card.validate(path: "Test"))
        card.correctIndices = [0, 0]
        XCTAssertThrowsError(try card.validate(path: "Test"))
        card.correctIndices = [0, 1]
        XCTAssertNoThrow(try card.validate(path: "Test"))
    }
    func testClozeAndMatchingValidation() {
        let cloze = CardPayload(LearningCard(type: .cloze, prompt: "Ohne Platzhalter", answer: "A"))
        XCTAssertThrowsError(try cloze.validate(path: "Test"))
        let matching = CardPayload(LearningCard(type: .matching, prompt: "Test", pairs: [.init(left: "A", right: "B"), .init(left: "C", right: "B")]))
        XCTAssertThrowsError(try matching.validate(path: "Test"))
    }
    func testDetailedImportErrorsAndVersion() throws {
        XCTAssertThrowsError(try LearningPackage.decode(Data("{\"format\":\"learn-to-learn\",\"version\":1}".utf8))) { error in XCTAssertTrue(error.localizedDescription.contains("modules")) }
        var package = Demo.package; package.version = 99
        XCTAssertThrowsError(try package.validate())
        XCTAssertThrowsError(try LearningPackage.decode(Data("```json\n{}\n```".utf8)))
    }
    func testSchedulerIntervalsAndLapse() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var progress = ReviewProgress(due: now)
        progress = Scheduler.review(progress, rating: .good, now: now)
        XCTAssertEqual(progress.interval, 1); XCTAssertEqual(progress.repetitions, 1)
        progress = Scheduler.review(progress, rating: .good, now: now)
        XCTAssertEqual(progress.interval, 3)
        progress = Scheduler.review(progress, rating: .good, now: now)
        XCTAssertEqual(progress.interval, 8)
        progress = Scheduler.review(progress, rating: .again, now: now)
        XCTAssertEqual(progress.repetitions, 0); XCTAssertEqual(progress.lapses, 1)
        XCTAssertEqual(progress.due.timeIntervalSince(now), 600, accuracy: 0.01)
        for _ in 0..<100 { progress = Scheduler.review(progress, rating: .hard, now: now) }
        XCTAssertGreaterThanOrEqual(progress.ease, 1.3)
        XCTAssertLessThanOrEqual(progress.interval, 3650)
    }
    func testAnswerNormalizationAndExactMultipleSelection() {
        let card = LearningCard(type: .textInput, prompt: "?", answer: "Gedächtnis", acceptedAnswers: ["Gedaechtnis"])
        XCTAssertTrue(AnswerChecker.accepts("  GEDÄCHTNIS \n", for: card))
        XCTAssertTrue(AnswerChecker.accepts("Gedaechtnis", for: card))
        XCTAssertFalse(AnswerChecker.accepts("Gedächtnis extra", for: card))
        let multi = LearningCard(type: .multipleChoice, prompt: "?", options: ["A", "B", "C"], correctIndices: [0, 2])
        XCTAssertTrue(AnswerChecker.multipleChoice([2, 0], for: multi))
        XCTAssertFalse(AnswerChecker.multipleChoice([0], for: multi))
        XCTAssertFalse(AnswerChecker.multipleChoice([0, 1, 2], for: multi))
    }
    func testPersistenceRetainsPreviousVersion() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = LibraryRepository(url: directory.appendingPathComponent("library.json"))
        XCTAssertNil(try repository.load())
        try repository.save(Demo.library)
        var changed = try XCTUnwrap(repository.load()); changed.dailyGoal = 30
        try repository.save(changed)
        XCTAssertEqual(try repository.load()?.dailyGoal, 30)
        XCTAssertEqual(try LibraryRepository.decodeBackup(Data(contentsOf: repository.backupURL)).dailyGoal, 20)
        try Data("broken".utf8).write(to: repository.url)
        XCTAssertThrowsError(try repository.save(changed))
        XCTAssertEqual(try LibraryRepository.decodeBackup(Data(contentsOf: repository.backupURL)).dailyGoal, 20)
    }
    func testBackupRejectsInvalidContent() throws {
        var library = Demo.library
        library.modules[0].sets[0].cards[0].prompt = ""
        XCTAssertThrowsError(try library.validated())
        library = Demo.library; library.schemaVersion = 9
        XCTAssertThrowsError(try library.validated())
    }
    func testStreakUsesCalendarDaysAndAllowsYesterday() {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 12))!
        var library = LearningLibrary()
        for offset in [1, 2, 3] { library.reviews.append(.init(cardID: UUID(), date: calendar.date(byAdding: .day, value: -offset, to: now)!, rating: .good)) }
        XCTAssertEqual(library.streak(at: now, calendar: calendar), 3)
        XCTAssertEqual(library.todayReviews(at: now, calendar: calendar), 0)
        library.reviews.append(.init(cardID: UUID(), date: now, rating: .good))
        XCTAssertEqual(library.streak(at: now, calendar: calendar), 4)
        XCTAssertEqual(library.todayReviews(at: now, calendar: calendar), 1)
    }
}
