import Foundation

public enum QuestionType: String, Codable, CaseIterable, Identifiable {
    case flashcard, multipleChoice, textInput, trueFalse, cloze, ordering, matching
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .flashcard: return "Karteikarte"
        case .multipleChoice: return "Multiple Choice"
        case .textInput: return "Freitext"
        case .trueFalse: return "Wahr oder falsch"
        case .cloze: return "Lückentext"
        case .ordering: return "Reihenfolge"
        case .matching: return "Zuordnung"
        }
    }
    public var icon: String {
        switch self {
        case .flashcard: return "rectangle.on.rectangle"
        case .multipleChoice: return "checklist"
        case .textInput: return "text.cursor"
        case .trueFalse: return "checkmark.circle"
        case .cloze: return "text.badge.plus"
        case .ordering: return "arrow.up.arrow.down"
        case .matching: return "arrow.triangle.branch"
        }
    }
}

public struct MatchPair: Codable, Hashable {
    public var left: String
    public var right: String
    public init(left: String, right: String) { self.left = left; self.right = right }
}

public struct ReviewProgress: Codable, Hashable {
    public var due: Date
    public var interval: Double
    public var ease: Double
    public var repetitions: Int
    public var lapses: Int
    public var lastReviewed: Date?
    public init(due: Date = Date(), interval: Double = 0, ease: Double = 2.5, repetitions: Int = 0, lapses: Int = 0, lastReviewed: Date? = nil) {
        self.due = due; self.interval = interval; self.ease = ease
        self.repetitions = repetitions; self.lapses = lapses; self.lastReviewed = lastReviewed
    }
}

public struct LearningCard: Codable, Identifiable, Hashable {
    public var id: UUID
    public var type: QuestionType
    public var prompt: String
    public var answer: String?
    public var options: [String]?
    public var correctIndices: [Int]?
    public var acceptedAnswers: [String]?
    public var pairs: [MatchPair]?
    public var explanation: String?
    public var hint: String?
    public var tags: [String]
    public var progress: ReviewProgress
    public init(id: UUID = UUID(), type: QuestionType, prompt: String, answer: String? = nil, options: [String]? = nil, correctIndices: [Int]? = nil, acceptedAnswers: [String]? = nil, pairs: [MatchPair]? = nil, explanation: String? = nil, hint: String? = nil, tags: [String] = [], progress: ReviewProgress = .init()) {
        self.id = id; self.type = type; self.prompt = prompt; self.answer = answer
        self.options = options; self.correctIndices = correctIndices; self.acceptedAnswers = acceptedAnswers
        self.pairs = pairs; self.explanation = explanation; self.hint = hint; self.tags = tags; self.progress = progress
    }
    public var solution: String {
        switch type {
        case .multipleChoice: return (correctIndices ?? []).compactMap { index in
            guard let options, options.indices.contains(index) else { return nil }; return options[index]
        }.joined(separator: " · ")
        case .ordering: return (options ?? []).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        case .matching: return (pairs ?? []).map { "\($0.left) → \($0.right)" }.joined(separator: "\n")
        case .trueFalse: return answer == "true" ? "Wahr" : "Falsch"
        default: return answer ?? acceptedAnswers?.first ?? ""
        }
    }
    public var isMastered: Bool { progress.repetitions >= 3 && progress.interval >= 7 }
    public var isNew: Bool { progress.lastReviewed == nil }
}

public struct LearningSet: Codable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    public var description: String
    public var cards: [LearningCard]
    public var createdAt: Date
    public init(id: UUID = UUID(), title: String, description: String = "", cards: [LearningCard] = [], createdAt: Date = Date()) {
        self.id = id; self.title = title; self.description = description; self.cards = cards; self.createdAt = createdAt
    }
    public var masteredCount: Int { cards.filter(\.isMastered).count }
    public func dueCount(at now: Date = Date()) -> Int { cards.filter { $0.progress.due <= now }.count }
}

public struct LearningModule: Codable, Identifiable, Hashable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var color: String
    public var icon: String
    public var sets: [LearningSet]
    public init(id: UUID = UUID(), title: String, subtitle: String = "", color: String = "orange", icon: String = "books.vertical", sets: [LearningSet] = []) {
        self.id = id; self.title = title; self.subtitle = subtitle; self.color = color; self.icon = icon; self.sets = sets
    }
    public var cards: [LearningCard] { sets.flatMap(\.cards) }
}

public struct ReviewEvent: Codable, Identifiable {
    public var id: UUID
    public var cardID: UUID
    public var date: Date
    public var rating: ReviewRating
    public init(cardID: UUID, date: Date = Date(), rating: ReviewRating) { id = UUID(); self.cardID = cardID; self.date = date; self.rating = rating }
}

public struct LearningLibrary: Codable {
    public var schemaVersion: Int = 1
    public var modules: [LearningModule]
    public var reviews: [ReviewEvent]
    public var dailyGoal: Int
    public init(modules: [LearningModule] = [], reviews: [ReviewEvent] = [], dailyGoal: Int = 20) {
        self.modules = modules; self.reviews = reviews; self.dailyGoal = dailyGoal
    }
    public var cards: [LearningCard] { modules.flatMap(\.cards) }
    public var sets: [LearningSet] { modules.flatMap(\.sets) }
    public func todayReviews(at now: Date = Date(), calendar: Calendar = .current) -> Int {
        reviews.filter { calendar.isDate($0.date, inSameDayAs: now) }.count
    }
    public func streak(at now: Date = Date(), calendar: Calendar = .current) -> Int {
        let days = Set(reviews.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var count = 0
        while days.contains(day) {
            count += 1; day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return count
    }
    public func validated() throws -> LearningLibrary {
        guard schemaVersion == 1 else { throw ImportError.invalid("Diese Sicherungsversion wird nicht unterstützt.") }
        guard (1...500).contains(dailyGoal) else { throw ImportError.invalid("Das Tagesziel muss zwischen 1 und 500 liegen.") }
        var ids = Set<UUID>()
        for module in modules {
            guard ids.insert(module.id).inserted, !module.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportError.invalid("Ungültiges oder doppeltes Modul in der Sicherung.") }
            for set in module.sets {
                guard ids.insert(set.id).inserted, !set.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ImportError.invalid("Ungültiges oder doppeltes Lernset in der Sicherung.") }
                for card in set.cards {
                    guard ids.insert(card.id).inserted else { throw ImportError.invalid("Doppelte Karten-ID in der Sicherung.") }
                    try CardPayload(card).validate(path: "\(module.title) / \(set.title)")
                    let p = card.progress
                    guard p.interval.isFinite, p.interval >= 0, p.ease.isFinite, p.ease >= 1.3, p.repetitions >= 0, p.lapses >= 0 else { throw ImportError.invalid("Ungültiger Lernfortschritt in der Sicherung.") }
                }
            }
        }
        return self
    }
}

public struct CardLocation: Identifiable {
    public var module: LearningModule
    public var set: LearningSet
    public var card: LearningCard
    public var id: UUID { card.id }
    public init(module: LearningModule, set: LearningSet, card: LearningCard) { self.module = module; self.set = set; self.card = card }
}

public enum ReviewRating: String, Codable, CaseIterable {
    case again, hard, good, easy
    public var title: String {
        switch self { case .again: return "Nochmal"; case .hard: return "Schwer"; case .good: return "Gut"; case .easy: return "Leicht" }
    }
}

public enum Scheduler {
    public static func review(_ progress: ReviewProgress, rating: ReviewRating, now: Date = Date()) -> ReviewProgress {
        var result = progress
        result.lastReviewed = now
        switch rating {
        case .again:
            result.repetitions = 0; result.lapses += 1; result.interval = 0
            result.ease = max(1.3, result.ease - 0.2)
            result.due = now.addingTimeInterval(10 * 60)
            return result
        case .hard:
            result.interval = progress.interval < 1 ? 1 : max(1, progress.interval * 1.2)
            result.ease = max(1.3, result.ease - 0.15)
        case .good:
            result.interval = progress.repetitions == 0 ? 1 : progress.repetitions == 1 ? 3 : max(1, progress.interval * progress.ease)
        case .easy:
            result.interval = progress.interval < 1 ? 4 : max(4, progress.interval * progress.ease * 1.3)
            result.ease += 0.15
        }
        result.interval = min(3650, result.interval.rounded())
        result.repetitions += 1
        result.due = Calendar.current.date(byAdding: .day, value: Int(result.interval), to: now) ?? now.addingTimeInterval(result.interval * 86400)
        return result
    }
    public static func intervalLabel(_ progress: ReviewProgress, rating: ReviewRating, now: Date = Date()) -> String {
        let next = review(progress, rating: rating, now: now)
        if rating == .again { return "10 Min." }
        return "\(Int(next.interval)) \(next.interval == 1 ? "Tag" : "Tage")"
    }
}

public enum AnswerChecker {
    public static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    public static func accepts(_ text: String, for card: LearningCard) -> Bool {
        let choices = [card.answer].compactMap { $0 } + (card.acceptedAnswers ?? [])
        return choices.contains { normalize($0) == normalize(text) }
    }
    public static func multipleChoice(_ selection: Set<Int>, for card: LearningCard) -> Bool {
        !selection.isEmpty && selection == Set(card.correctIndices ?? [])
    }
    public static func ordering(_ order: [Int], for card: LearningCard) -> Bool {
        let expected = Array((card.options ?? []).indices)
        return !expected.isEmpty && order == expected
    }
    public static func matching(_ matches: [Int: Int], for card: LearningCard) -> Bool {
        guard let pairs = card.pairs, !pairs.isEmpty, matches.count == pairs.count else { return false }
        return pairs.indices.allSatisfy { matches[$0] == $0 }
    }
}
