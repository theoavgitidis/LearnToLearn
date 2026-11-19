import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LearnCore

enum ImportInstructions {
    static let prompt = """
    Erstelle aus meinen Modulinhalten ein Lernpaket für die native App Learn to Learn. Gib ausschließlich gültiges JSON aus, ohne Markdown-Codeblock. Format:
    {"format":"learn-to-learn","version":1,"modules":[{"title":"Modulname","subtitle":"Beschreibung","color":"orange","icon":"books.vertical","sets":[{"title":"Kapitel","description":"Lernziel","cards":[...]}]}]}

    Jede Karte benötigt type und prompt. Unterstützte Typen:
    - flashcard: answer (Text).
    - multipleChoice: options (2–12 eindeutige Texte), correctIndices (Liste aller richtigen Indizes, beginnend bei 0). Eine oder mehrere richtige Antworten.
    - textInput: answer (Text), optional acceptedAnswers (Liste zusätzlicher korrekter Schreibweisen).
    - trueFalse: answer ist der STRING "true" oder "false".
    - cloze: prompt enthält genau einmal {{blank}}, answer (Text), optional acceptedAnswers.
    - ordering: options (2–12 eindeutige Texte) IN DER RICHTIGEN REIHENFOLGE. Die App mischt sie.
    - matching: pairs (2–10 Objekte mit left und right). Alle linken und alle rechten Begriffe müssen jeweils eindeutig sein.

    Optional bei jeder Karte: explanation, hint und tags (Liste von Texten). Markdown in prompt, answer und explanation ist erlaubt; Formeln als lesbarer Unicode-/Klartext (kein LaTeX-Renderer).
    Farben: orange, blue, purple, green, pink, yellow. Symbol z. B. books.vertical, atom, function, terminal, chart.xyaxis.line.
    Gliedere das Modul in sinnvolle Lernsets. Mische passende Fragetypen, stelle klare Fragen und ergänze kurze Erklärungen. Nutze ausschließlich belegte Modulinhalte, kennzeichne Unsicherheiten und erfinde keine Fakten. Formuliere pro Karte einen klaren Lerngegenstand. Keine IDs, Datumswerte oder Lernfortschritte ausgeben. Pflichtfelder dürfen nicht fehlen; keine leeren Sets oder Karten.

    Hier sind meine Modulinhalte:
    """
}

struct ImportView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var text = ""
    @State private var package: LearningPackage?
    @State private var validatedText: String?
    @State private var validationError: String?
    @State private var targetModule: UUID?
    @State private var dropTargeted = false
    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Aus deinen Inhalten wird Wissen.", subtitle: "JSON einfügen oder eine .json-Datei öffnen. Vor dem Import siehst du eine Vorschau.", close: { dismiss() }).padding(28)
            Divider().overlay(Theme.border)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 15) {
                    HStack(spacing: 10) {
                        Button(action: openFile) { Label("Datei öffnen", systemImage: "doc.badge.plus") }.buttonStyle(QuietButtonStyle())
                        Button { if let value = NSPasteboard.general.string(forType: .string) { text = clean(value); validate() } else { validationError = "Die Zwischenablage enthält keinen Text." } } label: { Label("Einfügen", systemImage: "doc.on.clipboard") }.buttonStyle(QuietButtonStyle())
                        Spacer()
                        Button("Beispiel laden") { text = String(data: (try? Demo.package.encoded()) ?? Data(), encoding: .utf8) ?? ""; validate() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.accent)
                    }
                    ZStack(alignment: .topLeading) {
                        if text.isEmpty {
                            VStack(alignment: .leading, spacing: 12) { Text("{ ").foregroundStyle(Theme.accent); Text("  \"format\": \"learn-to-learn\",\n  \"version\": 1,\n  \"modules\": [ … ]\n}").foregroundStyle(Theme.muted); Text("JSON hier einfügen oder eine Datei hineinziehen.").font(.system(size: 11)).foregroundStyle(Theme.muted.opacity(0.6)).padding(.top, 15) }.font(.system(size: 13, design: .monospaced)).padding(18).allowsHitTesting(false)
                        }
                        TextEditor(text: $text).font(.system(size: 12, design: .monospaced)).scrollContentBackground(.hidden).padding(10).opacity(text.isEmpty ? 0.35 : 1).accessibilityLabel("JSON-Lernpaket")
                    }.frame(maxHeight: .infinity).background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 11)).overlay(RoundedRectangle(cornerRadius: 11).stroke(dropTargeted ? Theme.accent : Theme.border, lineWidth: dropTargeted ? 2 : 1))
                    .dropDestination(for: URL.self) { urls, _ in guard let url = urls.first else { return false }; readFile(url); return true } isTargeted: { dropTargeted = $0 }
                    if let validationError { Label(validationError, systemImage: "exclamationmark.circle").font(.system(size: 11)).foregroundStyle(Theme.red).lineLimit(5).textSelection(.enabled) }
                    HStack { Text("UTF-8 · max. 25 MB").font(.system(size: 10)).foregroundStyle(Theme.muted); Spacer(); Button("Vorschau prüfen", action: validate).buttonStyle(QuietButtonStyle()).disabled(text.trimmed.isEmpty).keyboardShortcut(.return, modifiers: .command) }
                }.padding(25).frame(width: 580)
                Rectangle().fill(Theme.border).frame(width: 1)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if let package {
                            Label("Lernpaket ist gültig", systemImage: "checkmark.seal.fill").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.green)
                            HStack(spacing: 10) { Pill(text: "\(package.modules.count) Module"); Pill(text: "\(package.setCount) Sets"); Pill(text: "\(package.cardCount) Karten", color: Theme.accent) }
                            ForEach(Array(package.modules.enumerated()), id: \.offset) { _, module in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(module.title).font(.system(size: 16, weight: .semibold))
                                    ForEach(Array(module.sets.enumerated()), id: \.offset) { _, set in
                                        VStack(alignment: .leading, spacing: 6) { HStack { Image(systemName: "rectangle.stack"); Text(set.title).fontWeight(.medium); Spacer(); Text("\(set.cards.count)") }.font(.system(size: 12)); Text(Array(Set(set.cards.map { $0.type.title })).sorted().joined(separator: " · ")).font(.system(size: 10)).foregroundStyle(Theme.muted) }
                                    }
                                }.panel(padding: 15)
                            }
                            EditorField(title: "Importziel") {
                                Picker("Importziel", selection: $targetModule) {
                                    Text("Als neue Module anlegen").tag(nil as UUID?)
                                    ForEach(store.library.modules) { Text("Sets zu „\($0.title)“ hinzufügen").tag(Optional($0.id)) }
                                }.labelsHidden().frame(maxWidth: .infinity)
                            }
                            Text(targetModule == nil ? "Es entstehen neue Module. Vorhandene Inhalte und Lernfortschritte werden beibehalten, auch bei gleichen Titeln." : "Alle enthaltenen Lernsets werden dem gewählten Modul hinzugefügt. Bestehende Sets bleiben erhalten.").font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(3)
                            Button { if store.importPackage(package, into: targetModule) { dismiss() } } label: { Label("\(package.cardCount) Karten importieren", systemImage: "square.and.arrow.down") }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                        } else { instructions }
                    }.padding(25)
                }.frame(maxWidth: .infinity)
            }
        }.frame(width: 990, height: 740).background(Theme.background).foregroundStyle(Theme.text)
        .onChange(of: text) { _, value in if value != validatedText { package = nil; validationError = nil } }
    }
    private var instructions: some View {
        VStack(alignment: .leading, spacing: 23) {
            IconBadge(icon: "sparkles", size: 50)
            Text("Dein Skript.\nDeine Lernkarten.").font(.system(size: 29, weight: .regular, design: .serif))
            step("01", "Inhalte aufbereiten", "Schicke deine Modulinhalte im Chat an Codex oder ChatGPT. Die Vorlage beschreibt das passende Format.")
            step("02", "JSON übernehmen", "Füge das erzeugte JSON links ein oder öffne eine Datei. Du kannst es auch als .txt speichern.")
            step("03", "Prüfen & loslernen", "Kontrolliere die Vorschau und füge die Karten deiner Bibliothek hinzu.")
            Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(ImportInstructions.prompt, forType: .string); store.notify("Chat-Vorlage kopiert") } label: { Label("Chat-Vorlage kopieren", systemImage: "doc.on.doc") }.buttonStyle(QuietButtonStyle())
            Button("JSON-Beispiel speichern …") { do { try store.saveFile(data: Demo.package.encoded(), name: "LearnToLearn-Beispiel.json") } catch { validationError = error.localizedDescription } }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.accent)
            Text("Die App arbeitet offline. Das Aufbereiten deiner Inhalte erfolgt im Chat deiner Wahl.").font(.system(size: 10)).foregroundStyle(Theme.muted).lineSpacing(3)
        }
    }
    private func step(_ number: String, _ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 12) { Text(number).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(Theme.accent).padding(.top, 2); VStack(alignment: .leading, spacing: 7) { Text(title).font(.system(size: 12, weight: .semibold)); Text(description).font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true) } }
    }
    private func clean(_ value: String) -> String {
        var value = value.trimmed
        if value.hasPrefix("```") { var lines = value.components(separatedBy: .newlines); lines.removeFirst(); if lines.last?.trimmed == "```" { lines.removeLast() }; value = lines.joined(separator: "\n") }
        return value
    }
    private func validate() {
        do { let result = try LearningPackage.decode(Data(clean(text).utf8)); validatedText = text; package = result; validationError = nil }
        catch { package = nil; validationError = error.localizedDescription }
    }
    private func openFile() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json, .plainText]; panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url { readFile(url) }
    }
    private func readFile(_ url: URL) {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 25 * 1024 * 1024 else { throw ImportError.invalid("Die Datei ist größer als 25 MB.") }
            text = clean(try String(contentsOf: url, encoding: .utf8)); validate()
        } catch { validationError = error.localizedDescription; package = nil }
    }
}
