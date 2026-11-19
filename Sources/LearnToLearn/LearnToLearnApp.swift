import SwiftUI
import LearnCore

@main
struct LearnToLearnApp: App {
    @StateObject private var store = AppStore()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store).preferredColorScheme(.dark)
                .frame(minWidth: 1050, minHeight: 720)
                .tint(Theme.accent)
        }
        .defaultSize(width: 1380, height: 900)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neues Modul …") { store.sheet = .module(nil) }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button("Lerninhalte importieren …") { store.sheet = .importer }.keyboardShortcut("i", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Lerninhalte exportieren …") { store.exportContent() }
                Button("Sicherung erstellen …") { store.exportBackup() }.keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandGroup(replacing: .appSettings) {
                Button("Einstellungen …") { store.sheet = .settings }.keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Lernen") {
                Button("Fällige Karten lernen") { store.startStudy(cards: store.dueCards, title: "Deine Wiederholung") }.keyboardShortcut("l", modifiers: .command)
                Button("Übersicht") { store.destination = .home }.keyboardShortcut("1", modifiers: .command)
                Button("Alle Lernsets") { store.destination = .allSets }.keyboardShortcut("2", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Button("Importformat & Hilfe") { store.sheet = .importer }
            }
        }
    }
}
