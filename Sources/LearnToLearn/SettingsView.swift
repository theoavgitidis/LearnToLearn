import SwiftUI
import AppKit
import UniformTypeIdentifiers
import LearnCore

struct SettingsView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    @State private var goal = 20
    @State private var restoreData: Data?
    @State private var restoreSummary = ""
    @State private var localError: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            SheetHeader(title: "Dein Lernraum, dein Tempo.", subtitle: "Einstellungen & Datensicherung", close: { dismiss() })
            VStack(alignment: .leading, spacing: 17) {
                Label("Tagesziel", systemImage: "scope").font(.system(size: 15, weight: .semibold))
                Text("Wie viele Wiederholungen möchtest du täglich schaffen?").font(.system(size: 12)).foregroundStyle(Theme.muted)
                HStack { Stepper(value: $goal, in: 1...500, step: 5) { Text("\(goal) Wiederholungen").font(.system(size: 15, weight: .medium)) }; Spacer(); Button("Übernehmen") { if store.commit({ $0.dailyGoal = goal }) { store.notify("Tagesziel gespeichert") } }.buttonStyle(QuietButtonStyle()).disabled(goal == store.library.dailyGoal) }
            }.panel()
            VStack(alignment: .leading, spacing: 16) {
                Label("Deine Daten gehören dir", systemImage: "externaldrive").font(.system(size: 15, weight: .semibold))
                Text("Alle Module, Karten und Lernfortschritte liegen lokal auf diesem Mac. Eine Sicherung enthält auch deinen Wiederholungsplan und deine Lernstatistik.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4)
                HStack(spacing: 12) {
                    Button { store.exportBackup() } label: { Label("Sicherung erstellen", systemImage: "square.and.arrow.up") }.buttonStyle(QuietButtonStyle())
                    Button(action: chooseBackup) { Label("Wiederherstellen", systemImage: "arrow.counterclockwise") }.buttonStyle(QuietButtonStyle())
                }
                Divider().overlay(Theme.border)
                Text(store.repository.url.deletingLastPathComponent().path).font(.system(size: 10, design: .monospaced)).foregroundStyle(Theme.muted).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Button("Datenordner im Finder öffnen") { NSWorkspace.shared.open(store.repository.url.deletingLastPathComponent()) }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.accent)
            }.panel()
            HStack(spacing: 13) { IconBadge(icon: "square.stack.3d.up.fill", size: 42); VStack(alignment: .leading, spacing: 5) { Text("Learn to Learn").font(.system(size: 13, weight: .semibold)); Text("Version 1.0 · Native macOS-App · Ohne Konto").font(.system(size: 10)).foregroundStyle(Theme.muted) }; Spacer() }
            if let localError { Text(localError).font(.system(size: 12)).foregroundStyle(Theme.red) }
        }.padding(30).frame(width: 650).background(Theme.background).foregroundStyle(Theme.text)
        .onAppear { goal = store.library.dailyGoal }
        .alert("Bibliothek wiederherstellen?", isPresented: Binding(get: { restoreData != nil }, set: { if !$0 { restoreData = nil } })) {
            Button("Abbrechen", role: .cancel) { restoreData = nil }
            Button("Bibliothek ersetzen", role: .destructive) {
                guard let data = restoreData else { return }
                do { try store.restoreBackup(data: data); goal = store.library.dailyGoal; localError = nil } catch { localError = error.localizedDescription }
                restoreData = nil
            }
        } message: { Text("\(restoreSummary)\n\nDie aktuelle Bibliothek wird ersetzt. Die bisherige Datei bleibt zusätzlich im Datenordner erhalten.") }
    }
    private func chooseBackup() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json, .data]; panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            do {
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 100 * 1024 * 1024 else { throw ImportError.invalid("Die Sicherung ist größer als 100 MB.") }
                let data = try Data(contentsOf: url); let library = try LibraryRepository.decodeBackup(data)
                restoreSummary = "\(library.modules.count) Module · \(library.cards.count) Karten · \(library.reviews.count) Wiederholungen"
                restoreData = data; localError = nil
            } catch { localError = "Ungültige Sicherung: \(error.localizedDescription)" }
        }
    }
}
