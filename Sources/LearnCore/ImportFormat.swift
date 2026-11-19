import Foundation

public enum ImportError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

public struct LearningPackage: Codable {
    public var format: String
    public var version: Int
    public var modules: [ModulePayload]
    public init(modules: [ModulePayload]) { format = "learn-to-learn"; version = 1; self.modules = modules }
    public init(library: LearningLibrary) { self.init(modules: library.modules.map(ModulePayload.init)) }
    public var cardCount: Int { modules.flatMap(\.sets).flatMap(\.cards).count }
    public var setCount: Int { modules.flatMap(\.sets).count }
    public func validate() throws {
        guard format == "learn-to-learn", version == 1 else { throw ImportError.invalid("Erwartet wird format: \"learn-to-learn\" mit version: 1.") }
        guard !modules.isEmpty else { throw ImportError.invalid("Die Datei enthält keine Module.") }
        guard modules.count <= 200, cardCount <= 50_000 else { throw ImportError.invalid("Maximal 200 Module und 50.000 Karten pro Import.") }
        for (mi, module) in modules.enumerated() {
            let path = "Modul \(mi + 1)"
            guard !module.title.trimmed.isEmpty else { throw ImportError.invalid("\(path): Der Titel fehlt.") }
            guard !module.sets.isEmpty else { throw ImportError.invalid("\(path): Mindestens ein Lernset ist erforderlich.") }
            for (si, set) in module.sets.enumerated() {
                guard !set.title.trimmed.isEmpty else { throw ImportError.invalid("\(path), Lernset \(si + 1): Der Titel fehlt.") }
                guard !set.cards.isEmpty else { throw ImportError.invalid("\(path), \(set.title): Keine Karten vorhanden.") }
                for (ci, card) in set.cards.enumerated() { try card.validate(path: "\(path), \(set.title), Karte \(ci + 1)") }
            }
        }
    }
    public static func decode(_ data: Data) throws -> LearningPackage {
        guard data.count <= 25 * 1024 * 1024 else { throw ImportError.invalid("Die Datei ist größer als 25 MB.") }
        do {
            let package = try JSONDecoder().decode(LearningPackage.self, from: data)
            try package.validate()
            return package
        } catch let error as ImportError { throw error }
        catch let error as DecodingError {
            let path: String; let message: String
            switch error {
            case .keyNotFound(let key, let context): path = context.codingPath.map(\.stringValue).joined(separator: "."); message = "Pflichtfeld \"\(key.stringValue)\" fehlt."
            case .typeMismatch(_, let context): path = context.codingPath.map(\.stringValue).joined(separator: "."); message = "Der Wert hat den falschen Typ."
            case .valueNotFound(_, let context): path = context.codingPath.map(\.stringValue).joined(separator: "."); message = "Ein Pflichtwert ist leer (null)."
            case .dataCorrupted(let context): path = context.codingPath.map(\.stringValue).joined(separator: "."); message = "Ungültiges JSON oder unbekannter Fragetyp. \(context.debugDescription)"
            @unknown default: path = ""; message = "Die Datei konnte nicht gelesen werden."
            }
            throw ImportError.invalid("\(path.isEmpty ? "JSON" : path): \(message)")
        }
    }
    public func encoded() throws -> Data { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]; return try encoder.encode(self) }
    /// New IDs prevent importing content from overwriting an existing collection or its progress.
    public func materialize() -> [LearningModule] { modules.map { $0.materialize() } }
}

public struct ModulePayload: Codable {
    public var title: String
    public var subtitle: String?
    public var color: String?
    public var icon: String?
    public var sets: [SetPayload]
    public init(title: String, subtitle: String? = nil, color: String? = nil, icon: String? = nil, sets: [SetPayload]) { self.title = title; self.subtitle = subtitle; self.color = color; self.icon = icon; self.sets = sets }
    public init(_ module: LearningModule) { self.init(title: module.title, subtitle: module.subtitle, color: module.color, icon: module.icon, sets: module.sets.map(SetPayload.init)) }
    public func materialize() -> LearningModule { .init(title: title.trimmed, subtitle: subtitle ?? "", color: color ?? "orange", icon: icon ?? "books.vertical", sets: sets.map { $0.materialize() }) }
}

public struct SetPayload: Codable {
    public var title: String
    public var description: String?
    public var cards: [CardPayload]
    public init(title: String, description: String? = nil, cards: [CardPayload]) { self.title = title; self.description = description; self.cards = cards }
    public init(_ set: LearningSet) { self.init(title: set.title, description: set.description, cards: set.cards.map(CardPayload.init)) }
    public func materialize() -> LearningSet { .init(title: title.trimmed, description: description ?? "", cards: cards.map { $0.materialize() }) }
}

public struct CardPayload: Codable {
    public var type: QuestionType
    public var prompt: String
    public var answer: String?
    public var options: [String]?
    public var correctIndices: [Int]?
    public var acceptedAnswers: [String]?
    public var pairs: [MatchPair]?
    public var explanation: String?
    public var hint: String?
    public var tags: [String]?
    public init(_ card: LearningCard) {
        type = card.type; prompt = card.prompt; answer = card.answer; options = card.options
        correctIndices = card.correctIndices; acceptedAnswers = card.acceptedAnswers; pairs = card.pairs
        explanation = card.explanation; hint = card.hint; tags = card.tags
    }
    public func materialize() -> LearningCard { .init(type: type, prompt: prompt, answer: answer, options: options, correctIndices: correctIndices, acceptedAnswers: acceptedAnswers, pairs: pairs, explanation: explanation, hint: hint, tags: tags ?? []) }
    public func validate(path: String) throws {
        func require(_ condition: Bool, _ message: String) throws { if !condition { throw ImportError.invalid("\(path): \(message)") } }
        try require(!prompt.trimmed.isEmpty, "Die Frage fehlt.")
        try require(prompt.count <= 30_000, "Die Frage ist zu lang (max. 30.000 Zeichen).")
        switch type {
        case .flashcard: try require(!(answer ?? "").trimmed.isEmpty, "Eine Karteikarte benötigt answer.")
        case .textInput, .cloze:
            try require(!(answer ?? "").trimmed.isEmpty || (acceptedAnswers ?? []).contains(where: { !$0.trimmed.isEmpty }), "Eine Texteingabe benötigt answer oder acceptedAnswers.")
            if type == .cloze { try require(prompt.components(separatedBy: "{{blank}}").count == 2, "Ein Lückentext benötigt genau einen Platzhalter {{blank}}. Für mehrere Lücken bitte mehrere Karten anlegen.") }
        case .trueFalse: try require(answer == "true" || answer == "false", "Bei trueFalse muss answer genau \"true\" oder \"false\" sein.")
        case .multipleChoice:
            let items = options ?? []; let indices = correctIndices ?? []
            try require((2...12).contains(items.count), "Multiple Choice benötigt 2–12 options.")
            try require(items.allSatisfy { !$0.trimmed.isEmpty } && Set(items.map(AnswerChecker.normalize)).count == items.count, "Antwortoptionen müssen ausgefüllt und eindeutig sein.")
            try require(!indices.isEmpty && Set(indices).count == indices.count && indices.allSatisfy { items.indices.contains($0) }, "correctIndices muss eindeutige gültige Indizes enthalten (Zählung ab 0).")
        case .ordering:
            let items = options ?? []
            try require((2...12).contains(items.count), "Reihenfolge benötigt 2–12 options in der richtigen Reihenfolge.")
            try require(items.allSatisfy { !$0.trimmed.isEmpty } && Set(items.map(AnswerChecker.normalize)).count == items.count, "Elemente müssen ausgefüllt und eindeutig sein.")
        case .matching:
            let items = pairs ?? []
            try require((2...10).contains(items.count), "Zuordnung benötigt 2–10 pairs.")
            try require(items.allSatisfy { !$0.left.trimmed.isEmpty && !$0.right.trimmed.isEmpty }, "Jedes Paar benötigt left und right.")
            try require(Set(items.map { AnswerChecker.normalize($0.left) }).count == items.count && Set(items.map { AnswerChecker.normalize($0.right) }).count == items.count, "Die linken und rechten Begriffe müssen jeweils eindeutig sein.")
        }
    }
}

extension String { public var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) } }
