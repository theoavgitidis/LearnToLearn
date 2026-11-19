import SwiftUI
import LearnCore

struct EditorField<Content: View>: View {
    var title: String
    var help: String? = nil
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .medium))
            content()
            if let help { Text(help).font(.system(size: 10)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true) }
        }
    }
}

struct ModuleEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let original: LearningModule?
    @State private var title: String
    @State private var subtitle: String
    @State private var color: String
    @State private var icon: String
    init(module: LearningModule?) {
        original = module
        _title = State(initialValue: module?.title ?? ""); _subtitle = State(initialValue: module?.subtitle ?? "")
        _color = State(initialValue: module?.color ?? "orange"); _icon = State(initialValue: module?.icon ?? "books.vertical")
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            SheetHeader(title: original == nil ? "Ein neues Kapitel." : "Modul bearbeiten", subtitle: "Organisiere dein Wissen nach Fach, Semester oder Thema.", close: { dismiss() })
            HStack(spacing: 18) { IconBadge(icon: icon, color: Theme.color(color), size: 68); VStack(alignment: .leading, spacing: 6) { Text(title.trimmed.isEmpty ? "Dein neues Modul" : title).font(.system(size: 22, weight: .semibold)); Text(subtitle.isEmpty ? "Platz für dein Wissen" : subtitle).font(.system(size: 12)).foregroundStyle(Theme.muted) } }.padding(.vertical, 9)
            EditorField(title: "Modulname") { TextField("z. B. Technische Mechanik", text: $title).fieldStyle() }
            EditorField(title: "Beschreibung (optional)") { TextField("z. B. 1. Semester · Grundlagen", text: $subtitle).fieldStyle() }
            EditorField(title: "Farbe") {
                HStack(spacing: 13) {
                    ForEach(Theme.colors, id: \.self) { name in Button { color = name } label: { Circle().fill(Theme.color(name)).frame(width: 25, height: 25).overlay(Circle().stroke(Theme.text, lineWidth: color == name ? 2 : 0).padding(-4)) }.buttonStyle(.plain).help(name) }
                }.padding(.vertical, 5)
            }
            EditorField(title: "Symbol") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(Theme.icons, id: \.self) { name in Button { icon = name } label: { Image(systemName: name).font(.system(size: 19)).foregroundStyle(icon == name ? Theme.color(color) : Theme.muted).frame(maxWidth: .infinity).frame(height: 43).background(icon == name ? Theme.raised : Theme.sidebar, in: RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain).help(name) }
                }
            }
            HStack { Button("Abbrechen") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction); Spacer(); Button(original == nil ? "Modul anlegen" : "Änderungen speichern") { var module = original ?? LearningModule(title: title); module.title = title.trimmed; module.subtitle = subtitle.trimmed; module.color = color; module.icon = icon; store.saveModule(module) }.buttonStyle(PrimaryButtonStyle()).disabled(title.trimmed.isEmpty).keyboardShortcut(.defaultAction) }
        }.padding(30).frame(width: 520).background(Theme.background).foregroundStyle(Theme.text)
    }
}

struct SetEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let moduleID: UUID
    let original: LearningSet?
    @State private var title: String
    @State private var description: String
    init(moduleID: UUID, set: LearningSet?) { self.moduleID = moduleID; original = set; _title = State(initialValue: set?.title ?? ""); _description = State(initialValue: set?.description ?? "") }
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            SheetHeader(title: original == nil ? "Dein nächstes Lernset." : "Lernset bearbeiten", subtitle: "\(store.module(moduleID)?.title ?? "Modul") · Ein Thema, viele Perspektiven.", close: { dismiss() })
            EditorField(title: "Name des Lernsets") { TextField("z. B. Kapitel 1 – Kräfte und Momente", text: $title).fieldStyle() }
            EditorField(title: "Beschreibung (optional)") { TextField("Was möchtest du in diesem Set lernen?", text: $description, axis: .vertical).lineLimit(3...5).fieldStyle() }
            HStack { Button("Abbrechen") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction); Spacer(); Button(original == nil ? "Lernset anlegen" : "Speichern") { var set = original ?? LearningSet(title: title); set.title = title.trimmed; set.description = description.trimmed; store.saveSet(set, moduleID: moduleID) }.buttonStyle(PrimaryButtonStyle()).disabled(title.trimmed.isEmpty).keyboardShortcut(.defaultAction) }
        }.padding(30).frame(width: 550).background(Theme.background).foregroundStyle(Theme.text)
    }
}

struct CardEditor: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let moduleID: UUID
    let setID: UUID
    let original: LearningCard?
    @State private var type: QuestionType
    @State private var prompt: String
    @State private var answer: String
    @State private var optionText: String
    @State private var selectedIndices: Set<Int>
    @State private var acceptedText: String
    @State private var pairText: String
    @State private var explanation: String
    @State private var hint: String
    @State private var tags: String
    @State private var resetProgress = false
    @State private var validationError: String?
    init(moduleID: UUID, setID: UUID, card: LearningCard?) {
        self.moduleID = moduleID; self.setID = setID; original = card
        _type = State(initialValue: card?.type ?? .flashcard); _prompt = State(initialValue: card?.prompt ?? "")
        _answer = State(initialValue: card?.answer ?? ""); _optionText = State(initialValue: (card?.options ?? []).joined(separator: "\n"))
        _selectedIndices = State(initialValue: Set(card?.correctIndices ?? [])); _acceptedText = State(initialValue: (card?.acceptedAnswers ?? []).joined(separator: "\n"))
        _pairText = State(initialValue: (card?.pairs ?? []).map { "\($0.left) | \($0.right)" }.joined(separator: "\n"))
        _explanation = State(initialValue: card?.explanation ?? ""); _hint = State(initialValue: card?.hint ?? ""); _tags = State(initialValue: (card?.tags ?? []).joined(separator: ", "))
    }
    private var options: [String] { optionText.components(separatedBy: .newlines).map(\.trimmed).filter { !$0.isEmpty } }
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: original == nil ? "Eine neue Karte." : "Karte bearbeiten", subtitle: store.set(setID, module: moduleID)?.title ?? "", close: { dismiss() }).padding(28)
            Divider().overlay(Theme.border)
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    EditorField(title: "Fragetyp") {
                        Picker("Fragetyp", selection: $type) { ForEach(QuestionType.allCases) { Label($0.title, systemImage: $0.icon).tag($0) } }.labelsHidden().controlSize(.large)
                    }
                    EditorField(title: type == .cloze ? "Lückentext" : "Frage / Vorderseite", help: type == .cloze ? "Genau eine Lücke mit {{blank}} markieren." : "Einfache Markdown-Formatierung ist möglich, z. B. **fett**.") { textArea($prompt, height: 90) }
                    answerFields
                    EditorField(title: "Erklärung (optional)", help: "Wird nach dem Auflösen angezeigt.") { textArea($explanation, height: 75) }
                    EditorField(title: "Hinweis (optional)") { TextField("Ein kleiner Denkanstoß", text: $hint).fieldStyle() }
                    EditorField(title: "Tags (optional)", help: "Mit Komma trennen.") { TextField("z. B. Grundlagen, Klausur", text: $tags).fieldStyle() }
                    if original != nil { Toggle("Lernfortschritt dieser Karte zurücksetzen", isOn: $resetProgress).font(.system(size: 12)).toggleStyle(.checkbox) }
                    if let validationError { Label(validationError, systemImage: "exclamationmark.circle").font(.system(size: 12)).foregroundStyle(Theme.red).fixedSize(horizontal: false, vertical: true) }
                }.padding(28)
            }
            Divider().overlay(Theme.border)
            HStack { Button("Abbrechen") { dismiss() }.buttonStyle(QuietButtonStyle()).keyboardShortcut(.cancelAction); Spacer(); Button("Karte speichern", action: save).buttonStyle(PrimaryButtonStyle()).keyboardShortcut("s", modifiers: .command).disabled(prompt.trimmed.isEmpty) }.padding(23)
        }.frame(width: 690, height: 760).background(Theme.background).foregroundStyle(Theme.text)
        .onChange(of: type) { _, newType in if newType == .trueFalse && answer != "true" && answer != "false" { answer = "true" }; validationError = nil }
    }
    @ViewBuilder private var answerFields: some View {
        switch type {
        case .flashcard:
            EditorField(title: "Antwort / Rückseite") { textArea($answer, height: 110) }
        case .textInput, .cloze:
            EditorField(title: "Musterantwort") { TextField("Die gesuchte Antwort", text: $answer).fieldStyle() }
            EditorField(title: "Weitere akzeptierte Antworten (optional)", help: "Eine Variante pro Zeile. Groß-/Kleinschreibung, Akzente und äußere Leerzeichen werden ignoriert. Andere Schreibweisen explizit ergänzen.") { textArea($acceptedText, height: 65) }
        case .trueFalse:
            EditorField(title: "Die richtige Antwort") { Picker("Antwort", selection: $answer) { Text("Wahr").tag("true"); Text("Falsch").tag("false") }.pickerStyle(.segmented) }
        case .multipleChoice:
            EditorField(title: "Antwortoptionen", help: "Eine Antwort pro Zeile (2–12 Optionen). Danach alle richtigen Antworten markieren.") { textArea($optionText, height: 110) }
            if !options.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        Toggle(option, isOn: Binding(get: { selectedIndices.contains(index) }, set: { if $0 { selectedIndices.insert(index) } else { selectedIndices.remove(index) } })).toggleStyle(.checkbox).font(.system(size: 12))
                    }
                }.padding(15).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
            }
        case .ordering:
            EditorField(title: "Elemente in der richtigen Reihenfolge", help: "Ein Element pro Zeile (2–12). Die App mischt sie beim Lernen.") { textArea($optionText, height: 140) }
        case .matching:
            EditorField(title: "Zusammengehörige Paare", help: "Ein Paar pro Zeile, getrennt durch |. Beispiel: Stack | LIFO. 2–10 Paare mit eindeutigen Begriffen.") { textArea($pairText, height: 140) }
        }
    }
    private func textArea(_ binding: Binding<String>, height: CGFloat) -> some View {
        TextEditor(text: binding).font(.system(size: 13)).scrollContentBackground(.hidden).padding(8).frame(height: height).background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.border))
    }
    private func save() {
        let accepted = acceptedText.components(separatedBy: .newlines).map(\.trimmed).filter { !$0.isEmpty }
        var pairs: [MatchPair] = []
        if type == .matching {
            for line in pairText.components(separatedBy: .newlines).filter({ !$0.trimmed.isEmpty }) {
                let pieces = line.components(separatedBy: "|")
                guard pieces.count == 2 else { validationError = "Jede Paar-Zeile muss genau ein | als Trennzeichen enthalten."; return }
                pairs.append(.init(left: pieces[0].trimmed, right: pieces[1].trimmed))
            }
        }
        let card = LearningCard(id: original?.id ?? UUID(), type: type, prompt: prompt.trimmed,
            answer: [.flashcard, .textInput, .cloze, .trueFalse].contains(type) ? answer.trimmed : nil,
            options: [.multipleChoice, .ordering].contains(type) ? options : nil,
            correctIndices: type == .multipleChoice ? selectedIndices.sorted() : nil,
            acceptedAnswers: [.textInput, .cloze].contains(type) ? accepted : nil,
            pairs: type == .matching ? pairs : nil,
            explanation: explanation.trimmed.isEmpty ? nil : explanation.trimmed, hint: hint.trimmed.isEmpty ? nil : hint.trimmed,
            tags: Array(Set(tags.components(separatedBy: ",").map(\.trimmed).filter { !$0.isEmpty })).sorted(),
            progress: resetProgress ? ReviewProgress() : original?.progress ?? ReviewProgress())
        do { try CardPayload(card).validate(path: "Karte"); store.saveCard(card, moduleID: moduleID, setID: setID) }
        catch { validationError = error.localizedDescription }
    }
}
