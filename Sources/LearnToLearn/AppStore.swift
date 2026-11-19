import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LearnCore

enum Destination: Hashable {
    case home, allSets, due, module(UUID), set(UUID, UUID)
}

struct StudyRequest: Identifiable {
    let id = UUID()
    var title: String
    var cards: [CardLocation]
    var practice: Bool
}

enum AppSheet: Identifiable {
    case module(UUID?)
    case set(UUID, UUID?)
    case card(UUID, UUID, UUID?)
    case importer
    case settings
    case study(StudyRequest)
    var id: String {
        switch self {
        case .module(let id): return "module-\(id?.uuidString ?? "new")"
        case .set(let module, let set): return "set-\(module)-\(set?.uuidString ?? "new")"
        case .card(_, let set, let card): return "card-\(set)-\(card?.uuidString ?? "new")"
        case .importer: return "import"
        case .settings: return "settings"
        case .study(let request): return request.id.uuidString
        }
    }
}

enum DeleteTarget: Identifiable {
    case module(LearningModule), set(UUID, LearningSet), card(UUID, UUID, LearningCard)
    var id: UUID {
        switch self { case .module(let module): return module.id; case .set(_, let set): return set.id; case .card(_, _, let card): return card.id }
    }
    var title: String {
        switch self { case .module(let module): return "Modul „\(module.title)“ löschen?"; case .set(_, let set): return "Lernset „\(set.title)“ löschen?"; case .card: return "Karte löschen?" }
    }
    var detail: String { "Die enthaltenen Karten und ihr Lernfortschritt werden gelöscht. Diese Aktion kann nicht rückgängig gemacht werden." }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var library: LearningLibrary
    @Published var destination: Destination = .home
    @Published var sheet: AppSheet?
    @Published var deletion: DeleteTarget?
    @Published var error: String?
    @Published var toast: String?
    @Published var search = ""
    let repository: LibraryRepository
    private(set) var storageBlocked = false

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--data-dir"), arguments.indices.contains(index + 1) {
            repository = LibraryRepository(url: URL(fileURLWithPath: arguments[index + 1]).appendingPathComponent("library.json"))
        } else { repository = .standard }
        do {
            if let loaded = try repository.load() { library = loaded }
            else { let initial = Demo.library; try repository.save(initial); library = initial }
        } catch {
            library = LearningLibrary(); storageBlocked = true
            self.error = "Die Lerndaten konnten nicht geöffnet werden. Die Datei wurde unverändert erhalten. Du kannst in den Einstellungen eine Sicherung wiederherstellen.\n\n\(error.localizedDescription)\n\n\(repository.url.path)"
        }
    }
    var locations: [CardLocation] {
        library.modules.flatMap { module in module.sets.flatMap { set in set.cards.map { CardLocation(module: module, set: set, card: $0) } } }
    }
    var dueCards: [CardLocation] { locations.filter { $0.card.progress.due <= Date() }.sorted { $0.card.progress.due < $1.card.progress.due } }
    var setRows: [(module: LearningModule, set: LearningSet)] { library.modules.flatMap { module in module.sets.map { (module, $0) } } }
    func module(_ id: UUID) -> LearningModule? { library.modules.first { $0.id == id } }
    func set(_ id: UUID, module moduleID: UUID) -> LearningSet? { module(moduleID)?.sets.first { $0.id == id } }
    func card(_ id: UUID) -> LearningCard? { library.cards.first { $0.id == id } }
    func notify(_ message: String) {
        toast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in if self?.toast == message { self?.toast = nil } }
    }
    @discardableResult func commit(_ transform: (inout LearningLibrary) -> Void) -> Bool {
        guard !storageBlocked else { error = "Die Datendatei ist gesperrt, weil sie nicht gelesen werden konnte. Stelle in den Einstellungen eine gültige Sicherung wieder her."; return false }
        var updated = library; transform(&updated)
        do { try repository.save(updated); library = updated; return true }
        catch { self.error = "Speichern fehlgeschlagen. Die Änderung wurde nicht übernommen.\n\n\(error.localizedDescription)"; return false }
    }
    func saveModule(_ module: LearningModule) {
        if commit({ library in
            if let index = library.modules.firstIndex(where: { $0.id == module.id }) { library.modules[index] = module }
            else { library.modules.append(module) }
        }) { destination = .module(module.id); sheet = nil }
    }
    func saveSet(_ set: LearningSet, moduleID: UUID) {
        if commit({ library in
            guard let mi = library.modules.firstIndex(where: { $0.id == moduleID }) else { return }
            if let si = library.modules[mi].sets.firstIndex(where: { $0.id == set.id }) { library.modules[mi].sets[si] = set }
            else { library.modules[mi].sets.append(set) }
        }) { destination = .set(moduleID, set.id); sheet = nil }
    }
    func saveCard(_ card: LearningCard, moduleID: UUID, setID: UUID) {
        if commit({ library in
            guard let mi = library.modules.firstIndex(where: { $0.id == moduleID }), let si = library.modules[mi].sets.firstIndex(where: { $0.id == setID }) else { return }
            if let ci = library.modules[mi].sets[si].cards.firstIndex(where: { $0.id == card.id }) { library.modules[mi].sets[si].cards[ci] = card }
            else { library.modules[mi].sets[si].cards.append(card) }
        }) { sheet = nil }
    }
    func delete(_ target: DeleteTarget) {
        let deletedIDs: Set<UUID>
        switch target {
        case .module(let module): deletedIDs = Set(module.cards.map(\.id))
        case .set(_, let set): deletedIDs = Set(set.cards.map(\.id))
        case .card(_, _, let card): deletedIDs = [card.id]
        }
        let success = commit { library in
            switch target {
            case .module(let module): library.modules.removeAll { $0.id == module.id }
            case .set(let moduleID, let set):
                guard let mi = library.modules.firstIndex(where: { $0.id == moduleID }) else { return }
                library.modules[mi].sets.removeAll { $0.id == set.id }
            case .card(let moduleID, let setID, let card):
                guard let mi = library.modules.firstIndex(where: { $0.id == moduleID }), let si = library.modules[mi].sets.firstIndex(where: { $0.id == setID }) else { return }
                library.modules[mi].sets[si].cards.removeAll { $0.id == card.id }
            }
            // Keep historical review counts even after content deletion.
        }
        _ = deletedIDs
        if success {
            switch target { case .module: destination = .home; case .set(let moduleID, _): destination = .module(moduleID); case .card: break }
            notify("Gelöscht")
        }
        deletion = nil
    }
    func startStudy(cards: [CardLocation], title: String, practice: Bool = false, shuffle: Bool = true) {
        guard !cards.isEmpty else { notify("Hier gibt es gerade keine Karten zu lernen."); return }
        let sorted = shuffle ? cards.shuffled() : cards
        sheet = .study(.init(title: title, cards: sorted, practice: practice))
    }
    @discardableResult func review(_ id: UUID, rating: ReviewRating) -> Bool {
        commit { library in
            for mi in library.modules.indices {
                for si in library.modules[mi].sets.indices {
                    if let ci = library.modules[mi].sets[si].cards.firstIndex(where: { $0.id == id }) {
                        let progress = library.modules[mi].sets[si].cards[ci].progress
                        library.modules[mi].sets[si].cards[ci].progress = Scheduler.review(progress, rating: rating)
                        library.reviews.append(.init(cardID: id, rating: rating)); return
                    }
                }
            }
        }
    }
    @discardableResult func importPackage(_ package: LearningPackage, into moduleID: UUID?) -> Bool {
        do { try package.validate() } catch { self.error = error.localizedDescription; return false }
        let modules = package.materialize()
        let success = commit { library in
            if let moduleID, let index = library.modules.firstIndex(where: { $0.id == moduleID }) { library.modules[index].sets.append(contentsOf: modules.flatMap(\.sets)) }
            else { library.modules.append(contentsOf: modules) }
        }
        if success {
            if let moduleID { destination = .module(moduleID) } else if let first = modules.first { destination = .module(first.id) }
            notify("\(package.cardCount) Karten importiert")
        }
        return success
    }
    func exportContent(modules: [LearningModule]? = nil) {
        do {
            let package = LearningPackage(library: LearningLibrary(modules: modules ?? library.modules))
            try saveFile(data: package.encoded(), name: "Lernsets.json")
        } catch { self.error = error.localizedDescription }
    }
    func exportBackup() { do { try saveFile(data: LibraryRepository.encodeBackup(library), name: "LearnToLearn-Sicherung.json") } catch { self.error = error.localizedDescription } }
    func saveFile(data: Data, name: String) throws {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.allowedContentTypes = [.json]; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { try data.write(to: url, options: .atomic); notify("Datei gespeichert") }
    }
    func restoreBackup(data: Data) throws {
        let restored = try LibraryRepository.decodeBackup(data)
        // Explicit restoration preserves even an unreadable original for manual recovery.
        if FileManager.default.fileExists(atPath: repository.url.path) {
            let recovery = repository.url.deletingLastPathComponent().appendingPathComponent("library-before-restore-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: repository.url, to: recovery)
            if storageBlocked { try FileManager.default.removeItem(at: repository.url) }
        }
        try repository.save(restored)
        storageBlocked = false; library = restored; destination = .home; notify("Sicherung wiederhergestellt")
    }
}
