import SwiftUI
import LearnCore

struct LibraryView: View {
    @EnvironmentObject var store: AppStore
    let moduleID: UUID?
    private var module: LearningModule? { moduleID.flatMap(store.module) }
    private var rows: [(module: LearningModule, set: LearningSet)] { store.setRows.filter { moduleID == nil || $0.module.id == moduleID } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 18) {
                    if let module { IconBadge(icon: module.icon, color: Theme.color(module.color), size: 60) }
                    VStack(alignment: .leading, spacing: 9) {
                        Text(module == nil ? "DEINE BIBLIOTHEK" : "MODUL").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(Theme.accent)
                        Text(module?.title ?? "Alle Lernsets").font(.system(size: 32, weight: .semibold))
                        Text(module?.subtitle.isEmpty == false ? module!.subtitle : "\(rows.count) Lernsets · \(rows.reduce(0) { $0 + $1.set.cards.count }) Karten für deinen nächsten Aha-Moment.").font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if let module {
                        Menu {
                            Button("Modul bearbeiten") { store.sheet = .module(module.id) }
                            Button("Modul exportieren …") { store.exportContent(modules: [module]) }
                            Button("Modul löschen", role: .destructive) { store.deletion = .module(module) }
                        } label: { Image(systemName: "ellipsis").frame(width: 30, height: 25) }.menuStyle(.borderlessButton).frame(width: 35)
                        Button { store.sheet = .set(module.id, nil) } label: { Label("Neues Lernset", systemImage: "plus") }.buttonStyle(PrimaryButtonStyle())
                    } else {
                        Menu {
                            ForEach(store.library.modules) { module in Button(module.title) { store.sheet = .set(module.id, nil) } }
                            Divider()
                            Button("Neues Modul …") { store.sheet = .module(nil) }
                        } label: { Label("Neues Lernset", systemImage: "plus").font(.system(size: 12, weight: .semibold)).padding(12) }.menuStyle(.borderlessButton).fixedSize()
                    }
                }
                if let module, !module.cards.isEmpty {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 7) { Text("Ein Modul. Viele Aha-Momente.").font(.system(size: 19, weight: .regular, design: .serif)); Text("\(module.cards.filter { $0.progress.due <= Date() }.count) Karten sind jetzt bereit für eine Wiederholung.").font(.system(size: 12)).foregroundStyle(Theme.muted) }
                        Spacer()
                        Button { store.startStudy(cards: store.locations.filter { $0.module.id == module.id && $0.card.progress.due <= Date() }, title: module.title) } label: { Label("Modul lernen", systemImage: "play.fill") }.buttonStyle(PrimaryButtonStyle()).disabled(!module.cards.contains { $0.progress.due <= Date() })
                    }.panel(padding: 25)
                }
                if rows.isEmpty {
                    EmptyState(icon: "rectangle.stack.badge.plus", title: "Hier beginnt dein Lernset", message: "Füge Karteikarten und interaktive Fragen hinzu oder importiere aufbereitete Modulinhalte.", actionTitle: moduleID == nil ? "Inhalte importieren" : "Erstes Lernset anlegen", action: { if let moduleID { store.sheet = .set(moduleID, nil) } else { store.sheet = .importer } })
                } else {
                    SectionHeading(title: "Lernsets", caption: "\(rows.count)")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 290), spacing: 20)], spacing: 20) {
                        ForEach(rows, id: \.set.id) { row in SetTile(module: row.module, set: row.set) }
                    }
                }
            }.padding(36)
        }
    }
}

struct SetTile: View {
    @EnvironmentObject var store: AppStore
    let module: LearningModule
    let set: LearningSet
    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack {
                IconBadge(icon: "rectangle.stack", color: Theme.color(module.color))
                Spacer()
                Menu {
                    Button("Lernset bearbeiten") { store.sheet = .set(module.id, set.id) }
                    Button("Karte hinzufügen") { store.sheet = .card(module.id, set.id, nil) }
                    Button("Exportieren …") { var export = module; export.sets = [set]; store.exportContent(modules: [export]) }
                    Divider()
                    Button("Lernset löschen", role: .destructive) { store.deletion = .set(module.id, set) }
                } label: { Image(systemName: "ellipsis").foregroundStyle(Theme.muted) }.menuStyle(.borderlessButton).frame(width: 22)
            }
            Button { store.destination = .set(module.id, set.id) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(module.title.uppercased()).font(.system(size: 8, weight: .semibold)).tracking(1.3).foregroundStyle(Theme.color(module.color))
                    Text(set.title).font(.system(size: 21, weight: .semibold)).lineLimit(2).frame(height: 52, alignment: .topLeading)
                    Text(set.description.isEmpty ? "Dein Wissen wächst mit jeder Karte." : set.description).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(2).frame(height: 34, alignment: .topLeading)
                    HStack(spacing: 7) { Text("\(set.cards.count) Karten"); Text("·"); Text("\(Set(set.cards.map(\.type)).count) Fragetypen") }.font(.system(size: 10)).foregroundStyle(Theme.muted).padding(.top, 5)
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
            HStack {
                if set.dueCount() > 0 { Pill(text: "\(set.dueCount()) fällig", color: Theme.accent) } else { Pill(text: set.cards.isEmpty ? "Noch leer" : "Alles wiederholt", color: Theme.green) }
                Spacer()
                Button { store.destination = .set(module.id, set.id) } label: { Image(systemName: "arrow.right").font(.system(size: 13)).foregroundStyle(Theme.text).frame(width: 30, height: 30).background(Theme.raised, in: Circle()) }.buttonStyle(.plain).help("Lernset öffnen")
            }
        }.panel(padding: 23)
    }
}

struct SetDetailView: View {
    @EnvironmentObject var store: AppStore
    let moduleID: UUID
    let setID: UUID
    @State private var filter: QuestionType?
    @State private var query = ""
    @State private var expanded: Set<UUID> = []
    private var set: LearningSet? { store.set(setID, module: moduleID) }
    private var module: LearningModule? { store.module(moduleID) }
    private var cards: [LearningCard] { (set?.cards ?? []).filter { (filter == nil || $0.type == filter) && (query.isEmpty || $0.prompt.localizedCaseInsensitiveContains(query) || $0.solution.localizedCaseInsensitiveContains(query) || $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }) } }
    var body: some View {
        if let set, let module {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Button { store.destination = .module(moduleID) } label: { Label(module.title, systemImage: "arrow.left").font(.system(size: 12)).foregroundStyle(Theme.muted) }.buttonStyle(.plain)
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(set.title).font(.system(size: 34, weight: .semibold))
                            if !set.description.isEmpty { Text(set.description).font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(4) }
                            HStack(spacing: 10) { Pill(text: "\(set.cards.count) Karten"); Pill(text: "\(set.masteredCount) gefestigt", color: Theme.green); Pill(text: "\(set.dueCount()) fällig", color: Theme.accent) }
                        }
                        Spacer()
                        Menu {
                            Button("Lernset bearbeiten") { store.sheet = .set(moduleID, setID) }
                            Button("Exportieren …") { var export = module; export.sets = [set]; store.exportContent(modules: [export]) }
                            Button("Lernset löschen", role: .destructive) { store.deletion = .set(moduleID, set) }
                        } label: { Image(systemName: "ellipsis").frame(width: 25, height: 25) }.menuStyle(.borderlessButton).frame(width: 32)
                    }
                    HStack(spacing: 12) {
                        Button { store.startStudy(cards: store.locations.filter { $0.set.id == setID && $0.card.progress.due <= Date() }, title: set.title) } label: { Label("Fällige lernen (\(set.dueCount()))", systemImage: "play.fill") }.buttonStyle(PrimaryButtonStyle()).disabled(set.dueCount() == 0)
                        Button { store.startStudy(cards: store.locations.filter { $0.set.id == setID }, title: set.title, practice: true) } label: { Label("Alle üben", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") }.buttonStyle(QuietButtonStyle()).disabled(set.cards.isEmpty).help("Freies Üben verändert den Wiederholungsplan nicht")
                        Spacer()
                        Button { store.sheet = .card(moduleID, setID, nil) } label: { Label("Neue Karte", systemImage: "plus") }.buttonStyle(QuietButtonStyle())
                    }
                    Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 4)
                    HStack {
                        SectionHeading(title: "Karten", caption: "\(cards.count)")
                        Picker("Fragetyp", selection: $filter) {
                            Text("Alle Fragetypen").tag(nil as QuestionType?)
                            ForEach(QuestionType.allCases) { Text($0.title).tag(Optional($0)) }
                        }.labelsHidden().frame(width: 180)
                        TextField("In diesem Set suchen", text: $query).fieldStyle().frame(width: 215).font(.system(size: 12))
                    }
                    if cards.isEmpty {
                        EmptyState(icon: "rectangle.badge.plus", title: set.cards.isEmpty ? "Deine erste Karte wartet" : "Keine passenden Karten", message: set.cards.isEmpty ? "Erstelle eine Karteikarte, eine Frage oder eine interaktive Aufgabe." : "Versuche einen anderen Suchbegriff oder Fragetyp.", actionTitle: set.cards.isEmpty ? "Karte erstellen" : nil, action: { store.sheet = .card(moduleID, setID, nil) })
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(cards) { card in
                                VStack(alignment: .leading, spacing: 15) {
                                    HStack(alignment: .top, spacing: 15) {
                                        IconBadge(icon: card.type.icon, color: Theme.color(module.color), size: 35)
                                        Button { if expanded.contains(card.id) { expanded.remove(card.id) } else { expanded.insert(card.id) } } label: {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(.init(card.prompt.replacingOccurrences(of: "{{blank}}", with: "▰▰▰"))).font(.system(size: 14, weight: .medium)).multilineTextAlignment(.leading)
                                                HStack(spacing: 9) { Text(card.type.title); Text("·"); Text(card.isNew ? "Neu" : card.progress.due.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "de_DE")))); ForEach(card.tags.prefix(3), id: \.self) { tag in Text("#\(tag)") } }.font(.system(size: 10)).foregroundStyle(Theme.muted)
                                            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                        Button { store.sheet = .card(moduleID, setID, card.id) } label: { Image(systemName: "pencil").foregroundStyle(Theme.muted).frame(width: 25, height: 25) }.buttonStyle(.plain).help("Karte bearbeiten")
                                    }
                                    if expanded.contains(card.id) {
                                        VStack(alignment: .leading, spacing: 10) {
                                            Text("LÖSUNG").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(Theme.green)
                                            Text(.init(card.solution)).font(.system(size: 13)).textSelection(.enabled)
                                            if let explanation = card.explanation, !explanation.isEmpty { Text(.init(explanation)).font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4) }
                                        }.padding(17).frame(maxWidth: .infinity, alignment: .leading).background(Theme.sidebar.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
                                    }
                                }.panel(padding: 18).contextMenu {
                                    Button("Bearbeiten") { store.sheet = .card(moduleID, setID, card.id) }
                                    Button("Karte löschen", role: .destructive) { store.deletion = .card(moduleID, setID, card) }
                                }
                            }
                        }
                    }
                }.padding(36)
            }
        } else { EmptyState(icon: "rectangle.stack", title: "Lernset nicht gefunden", message: "Wähle ein Lernset aus deiner Bibliothek.") }
    }
}

struct DueView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) { Text("Zeit, dein Wissen zu festigen.").font(.system(size: 32, weight: .semibold)); Text("Neue und fällige Karten aus deinen Modulen. Der nächste Abstand richtet sich nach deiner Bewertung.").font(.system(size: 13)).foregroundStyle(Theme.muted) }
                if store.dueCards.isEmpty {
                    EmptyState(icon: "checkmark.seal", title: "Alles für heute wiederholt", message: nextDueText, actionTitle: "Lernsets entdecken", action: { store.destination = .allSets }).panel()
                } else {
                    HStack { VStack(alignment: .leading, spacing: 8) { Text("\(store.dueCards.count) Karten sind bereit.").font(.system(size: 25, weight: .medium, design: .serif)); Text("Darunter \(store.dueCards.filter { $0.card.isNew }.count) neue Karten").font(.system(size: 12)).foregroundStyle(Theme.muted) }; Spacer(); Button { store.startStudy(cards: store.dueCards, title: "Deine Wiederholung") } label: { Label("Alle fälligen lernen", systemImage: "play.fill") }.buttonStyle(PrimaryButtonStyle()) }.panel(padding: 28)
                    ForEach(store.library.modules.filter { module in module.cards.contains { $0.progress.due <= Date() } }) { module in
                        VStack(alignment: .leading, spacing: 15) {
                            HStack { IconBadge(icon: module.icon, color: Theme.color(module.color), size: 35); Text(module.title).font(.system(size: 17, weight: .semibold)); Spacer(); Button("Modul lernen") { store.startStudy(cards: store.dueCards.filter { $0.module.id == module.id }, title: module.title) }.buttonStyle(QuietButtonStyle()) }
                            ForEach(module.sets.filter { $0.dueCount() > 0 }) { set in SetRow(module: module, set: set) }
                        }.panel()
                    }
                }
            }.padding(36)
        }
    }
    private var nextDueText: String {
        if let next = store.library.cards.map(\.progress.due).min() { return "Deine nächste Wiederholung: \(next.formatted(.dateTime.day().month(.wide).hour().minute().locale(Locale(identifier: "de_DE")))). Mit „Alle üben“ kannst du jederzeit freiwillig weiterlernen." }
        return "Importiere ein Lernpaket oder erstelle dein erstes Modul."
    }
}

struct SearchResultsView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        let query = store.search
        let modules = store.library.modules.filter { $0.title.localizedCaseInsensitiveContains(query) }
        let sets = store.setRows.filter { $0.set.title.localizedCaseInsensitiveContains(query) || $0.set.description.localizedCaseInsensitiveContains(query) }
        let cards = store.locations.filter { $0.card.prompt.localizedCaseInsensitiveContains(query) || $0.card.solution.localizedCaseInsensitiveContains(query) || $0.card.tags.contains { $0.localizedCaseInsensitiveContains(query) } }
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Suche nach „\(query)“").font(.system(size: 28, weight: .semibold))
                if modules.isEmpty && sets.isEmpty && cards.isEmpty { EmptyState(icon: "magnifyingglass", title: "Noch kein Treffer", message: "Probiere einen anderen Begriff.") }
                if !modules.isEmpty { SectionHeading(title: "Module"); LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))]) { ForEach(modules) { ModuleTile(module: $0) } } }
                if !sets.isEmpty { SectionHeading(title: "Lernsets"); ForEach(sets, id: \.set.id) { row in SetRow(module: row.module, set: row.set).panel(padding: 0) } }
                if !cards.isEmpty {
                    SectionHeading(title: "Karten", caption: "\(cards.count)")
                    ForEach(cards.prefix(100)) { location in
                        Button { store.destination = .set(location.module.id, location.set.id); store.search = "" } label: {
                            HStack(spacing: 15) { IconBadge(icon: location.card.type.icon, color: Theme.color(location.module.color), size: 36); VStack(alignment: .leading, spacing: 8) { Text(.init(location.card.prompt)).font(.system(size: 14)).multilineTextAlignment(.leading); Text("\(location.module.title) / \(location.set.title)").font(.system(size: 11)).foregroundStyle(Theme.muted) }; Spacer(); Image(systemName: "arrow.right").foregroundStyle(Theme.muted) }.panel(padding: 20)
                        }.buttonStyle(.plain)
                    }
                    if cards.count > 100 { Text("Die ersten 100 Treffer werden angezeigt. Grenze die Suche weiter ein.").font(.system(size: 12)).foregroundStyle(Theme.muted) }
                }
            }.padding(36)
        }
    }
}
