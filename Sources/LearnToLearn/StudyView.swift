import SwiftUI
import LearnCore

struct StudyView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) var dismiss
    let request: StudyRequest
    @State private var queue: [CardLocation]
    @State private var index = 0
    @State private var ratings: [ReviewRating] = []
    @State private var start = Date()
    @State private var finishedAt: Date?
    @State private var confirmExit = false
    init(request: StudyRequest) { self.request = request; _queue = State(initialValue: request.cards) }
    private var completed: Bool { index >= queue.count }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                IconBadge(icon: request.practice ? "pencil.and.outline" : "sparkles", size: 37)
                VStack(alignment: .leading, spacing: 5) { Text(request.title).font(.system(size: 14, weight: .semibold)); Text(request.practice ? "Freies Üben · Wiederholungsplan bleibt erhalten" : "Fokuszeit · Dein Wissen wächst").font(.system(size: 10)).foregroundStyle(Theme.muted) }
                Spacer()
                if !completed { Text("\(index + 1) / \(queue.count)").font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(Theme.muted) }
                Button { if completed || index == 0 { dismiss() } else { confirmExit = true } } label: { Image(systemName: "xmark").frame(width: 30, height: 30).background(Theme.raised, in: Circle()) }.buttonStyle(.plain).help("Lerneinheit beenden")
            }.padding(.horizontal, 28).padding(.vertical, 22)
            GeometryReader { geo in ZStack(alignment: .leading) { Rectangle().fill(Theme.raised); Rectangle().fill(Theme.accent).frame(width: geo.size.width * CGFloat(index) / CGFloat(max(1, queue.count))) } }.frame(height: 3)
            if completed { summary }
            else {
                StudyQuestionView(location: queue[index], practice: request.practice) { rating in
                    let location = queue[index]
                    if !request.practice && !store.review(location.card.id, rating: rating) { return }
                    ratings.append(rating)
                    if rating == .again && !request.practice {
                        var repeated = location
                        if let latest = store.card(location.card.id) { repeated.card = latest }
                        queue.append(repeated)
                    }
                    index += 1
                    if index == queue.count { finishedAt = Date() }
                }.id(index)
            }
        }.frame(width: 960, height: 780).background(Theme.background).foregroundStyle(Theme.text)
        .interactiveDismissDisabled(!completed && index > 0)
        .alert("Lerneinheit beenden?", isPresented: $confirmExit) {
            Button("Weiterlernen", role: .cancel) { }
            Button("Beenden") { dismiss() }
        } message: { Text(request.practice ? "Du kannst später jederzeit eine neue Übung starten." : "Deine bisherigen Bewertungen sind bereits gespeichert. Die übrigen Karten bleiben fällig.") }
    }
    private var summary: some View {
        VStack(spacing: 24) {
            Spacer()
            ZStack { Circle().stroke(Theme.green.opacity(0.1), lineWidth: 1).frame(width: 130, height: 130); Circle().fill(Theme.green.opacity(0.08)).frame(width: 100, height: 100); Image(systemName: "checkmark.seal").font(.system(size: 45, weight: .light)).foregroundStyle(Theme.green) }
            VStack(spacing: 12) { Text("Ein Stück weiter.").font(.system(size: 40, weight: .regular, design: .serif)); Text(request.practice ? "Übung abgeschlossen. Dein Wiederholungsplan ist unverändert." : "Gut gemacht. Dein nächster Wiederholungsplan steht bereit.").font(.system(size: 14)).foregroundStyle(Theme.muted) }
            HStack(spacing: 45) {
                summaryMetric("\(ratings.count)", "Antworten")
                summaryMetric("\(ratings.filter { $0 == .good || $0 == .easy }.count)", "Gut oder leicht")
                summaryMetric(duration, "Fokuszeit")
            }.padding(.vertical, 18)
            Button("Zurück zum Lernraum") { dismiss() }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            if !request.practice { Text("Dein Fortschritt ist lokal gespeichert.").font(.system(size: 11)).foregroundStyle(Theme.muted) }
            Spacer()
        }.frame(maxWidth: .infinity)
    }
    private func summaryMetric(_ value: String, _ label: String) -> some View { VStack(spacing: 8) { Text(value).font(.system(size: 30, weight: .medium, design: .rounded)).foregroundStyle(Theme.accent); Text(label).font(.system(size: 11)).foregroundStyle(Theme.muted) } }
    private var duration: String { let seconds = Int((finishedAt ?? Date()).timeIntervalSince(start)); return seconds < 60 ? "\(seconds) s" : "\(seconds / 60) min" }
}

struct StudyQuestionView: View {
    @EnvironmentObject var store: AppStore
    let location: CardLocation
    let practice: Bool
    let onRate: (ReviewRating) -> Void
    @State private var revealed = false
    @State private var correct: Bool?
    @State private var selected: Set<Int> = []
    @State private var typed = ""
    @State private var truth: Bool?
    @State private var order: [Int] = []
    @State private var optionOrder: [Int] = []
    @State private var rightOrder: [Int] = []
    @State private var matches: [Int: Int] = [:]
    @State private var showHint = false
    @FocusState private var textFocused: Bool
    private var card: LearningCard { location.card }
    private var canCheck: Bool {
        switch card.type {
        case .flashcard, .ordering: return true
        case .multipleChoice: return !selected.isEmpty
        case .textInput, .cloze: return !typed.trimmed.isEmpty
        case .trueFalse: return truth != nil
        case .matching: return (card.pairs ?? []).indices.allSatisfy { (matches[$0] ?? -1) >= 0 }
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 8) {
                        Pill(text: card.type.title, color: Theme.color(location.module.color))
                        Text("\(location.module.title) / \(location.set.title)").font(.system(size: 10)).foregroundStyle(Theme.muted).lineLimit(1)
                        Spacer()
                        if card.isNew { Pill(text: "Neu") }
                    }
                    Text(.init(card.prompt.replacingOccurrences(of: "{{blank}}", with: "________"))).font(.system(size: 27, weight: .medium)).lineSpacing(7).textSelection(.enabled).fixedSize(horizontal: false, vertical: true).padding(.vertical, 6)
                    if !revealed { interaction }
                    else { result }
                    if !revealed, let hint = card.hint, !hint.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Button { showHint.toggle() } label: { Label(showHint ? "Hinweis ausblenden" : "Kleiner Hinweis?", systemImage: "lightbulb").font(.system(size: 11)).foregroundStyle(Theme.accent) }.buttonStyle(.plain)
                            if showHint { Text(.init(hint)).font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4) }
                        }.padding(.top, 5)
                    }
                }.padding(32).frame(maxWidth: 800).frame(maxWidth: .infinity, alignment: .center)
            }
            Divider().overlay(Theme.border)
            footer.padding(.horizontal, 40).padding(.vertical, 23).background(Theme.sidebar.opacity(0.4))
        }
        .onAppear {
            optionOrder = Array((card.options ?? []).indices).shuffled()
            order = shuffled(Array((card.options ?? []).indices))
            rightOrder = shuffled(Array((card.pairs ?? []).indices))
            if card.type == .textInput || card.type == .cloze { textFocused = true }
        }
    }
    @ViewBuilder private var interaction: some View {
        switch card.type {
        case .flashcard:
            VStack(spacing: 15) { Image(systemName: "brain.head.profile").font(.system(size: 28, weight: .light)).foregroundStyle(Theme.accent.opacity(0.7)); Text("Nimm dir einen Moment.\nWas fällt dir aus dem Kopf dazu ein?").font(.system(size: 14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).lineSpacing(5) }.frame(maxWidth: .infinity, minHeight: 180).background(Theme.surface, in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Theme.border))
        case .multipleChoice:
            VStack(alignment: .leading, spacing: 13) {
                Text((card.correctIndices?.count ?? 0) > 1 ? "Mehrere Antworten sind richtig. Wähle alle passenden aus." : "Wähle eine Antwort.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                ForEach(optionOrder, id: \.self) { index in
                    Button {
                        if (card.correctIndices?.count ?? 0) == 1 { selected = [index] }
                        else if selected.contains(index) { selected.remove(index) } else { selected.insert(index) }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: selected.contains(index) ? "checkmark.square.fill" : "square").font(.system(size: 18)).foregroundStyle(selected.contains(index) ? Theme.accent : Theme.muted)
                            Text(card.options?[index] ?? "").font(.system(size: 14)).multilineTextAlignment(.leading)
                            Spacer()
                        }.padding(17).background(selected.contains(index) ? Theme.accent.opacity(0.08) : Theme.surface, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(selected.contains(index) ? Theme.accent.opacity(0.5) : Theme.border))
                    }.buttonStyle(.plain)
                }
            }
        case .textInput, .cloze:
            VStack(alignment: .leading, spacing: 12) {
                Text("DEINE ANTWORT").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(Theme.muted)
                TextField(card.type == .cloze ? "Welcher Begriff fehlt?" : "Schreibe deine Antwort …", text: $typed).font(.system(size: 19)).fieldStyle().focused($textFocused).onSubmit { if canCheck { check() } }
                Text("Schreibweisen werden mit der Musterantwort und ihren Varianten verglichen.").font(.system(size: 10)).foregroundStyle(Theme.muted)
            }.padding(.vertical, 20)
        case .trueFalse:
            HStack(spacing: 18) {
                truthButton("Wahr", value: true, icon: "checkmark")
                truthButton("Falsch", value: false, icon: "xmark")
            }.padding(.vertical, 20)
        case .ordering:
            VStack(alignment: .leading, spacing: 11) {
                Text("Bringe die Elemente mit den Pfeilen in die richtige Reihenfolge.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                ForEach(Array(order.enumerated()), id: \.element) { position, item in
                    HStack(spacing: 14) {
                        Text("\(position + 1)").font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(Theme.accent).frame(width: 22)
                        Text(card.options?[item] ?? "").font(.system(size: 13)); Spacer()
                        Button { order.swapAt(position, position - 1) } label: { Image(systemName: "chevron.up").frame(width: 27, height: 27) }.buttonStyle(.plain).disabled(position == 0).help("Nach oben")
                        Button { order.swapAt(position, position + 1) } label: { Image(systemName: "chevron.down").frame(width: 27, height: 27) }.buttonStyle(.plain).disabled(position == order.count - 1).help("Nach unten")
                    }.padding(12).background(Theme.surface, in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.border))
                }
            }
        case .matching:
            VStack(alignment: .leading, spacing: 13) {
                Text("Wähle zu jedem Begriff die passende Zuordnung.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                ForEach(Array((card.pairs ?? []).enumerated()), id: \.offset) { index, pair in
                    HStack(spacing: 16) {
                        Text(pair.left).font(.system(size: 13, weight: .medium)).frame(width: 200, alignment: .leading)
                        Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(Theme.muted)
                        Picker("Zuordnung für \(pair.left)", selection: Binding(get: { matches[index] ?? -1 }, set: { matches[index] = $0 })) {
                            Text("Zuordnung wählen …").tag(-1)
                            ForEach(rightOrder, id: \.self) { right in Text(card.pairs?[right].right ?? "").tag(right) }
                        }.labelsHidden().frame(maxWidth: .infinity)
                    }.padding(16).background(Theme.surface, in: RoundedRectangle(cornerRadius: 9))
                }
            }
        }
    }
    private func truthButton(_ title: String, value: Bool, icon: String) -> some View {
        Button { truth = value } label: {
            VStack(spacing: 14) { Image(systemName: icon).font(.system(size: 25, weight: .light)); Text(title).font(.system(size: 17, weight: .medium)) }.frame(maxWidth: .infinity, minHeight: 130).foregroundStyle(truth == value ? Theme.accent : Theme.text).background(truth == value ? Theme.accent.opacity(0.08) : Theme.surface, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(truth == value ? Theme.accent.opacity(0.5) : Theme.border))
        }.buttonStyle(.plain)
    }
    private var result: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let correct {
                HStack(spacing: 10) { Image(systemName: correct ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill"); Text(correct ? "Richtig. Gut erinnert!" : "Noch nicht ganz. Schau dir die Lösung an.").font(.system(size: 14, weight: .medium)) }.foregroundStyle(correct ? Theme.green : Theme.accent)
            }
            if [.textInput, .cloze].contains(card.type) { Text("Deine Antwort: \(typed)").font(.system(size: 12)).foregroundStyle(Theme.muted) }
            if card.type == .multipleChoice {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(optionOrder, id: \.self) { index in
                        let right = (card.correctIndices ?? []).contains(index)
                        HStack(spacing: 11) { Image(systemName: right ? "checkmark.circle.fill" : selected.contains(index) ? "xmark.circle" : "circle").foregroundStyle(right ? Theme.green : selected.contains(index) ? Theme.red : Theme.muted); Text(card.options?[index] ?? "").font(.system(size: 13)); Spacer(); if selected.contains(index) { Text("gewählt").font(.system(size: 9)).foregroundStyle(Theme.muted) } }.padding(12).background(right ? Theme.green.opacity(0.06) : Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 13) {
                    Text(card.type == .flashcard ? "ANTWORT" : "MUSTERLÖSUNG").font(.system(size: 9, weight: .semibold)).tracking(1.8).foregroundStyle(Theme.green)
                    Text(.init(card.solution)).font(.system(size: card.type == .flashcard ? 22 : 17)).lineSpacing(7).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).panel(padding: 24)
            }
            if let explanation = card.explanation, !explanation.isEmpty {
                HStack(alignment: .top, spacing: 12) { Image(systemName: "lightbulb").foregroundStyle(Theme.accent); Text(.init(explanation)).font(.system(size: 13)).foregroundStyle(Theme.muted).lineSpacing(5).textSelection(.enabled) }.padding(.vertical, 8)
            }
            if correct == false && [.textInput, .cloze].contains(card.type) {
                Button { correct = true } label: { Label("Meine Antwort ist sinngemäß richtig", systemImage: "checkmark.circle").font(.system(size: 11)).foregroundStyle(Theme.accent) }.buttonStyle(.plain).help("Bei nicht hinterlegten Schreibweisen kannst du selbst bewerten.")
            }
        }
    }
    @ViewBuilder private var footer: some View {
        if !revealed {
            HStack {
                Text(card.type == .flashcard ? "Erst erinnern, dann aufdecken." : "Nimm dir die Zeit, die du brauchst.").font(.system(size: 11)).foregroundStyle(Theme.muted)
                Spacer()
                if card.type != .flashcard { Button("Weiß ich noch nicht") { correct = false; revealed = true; textFocused = false }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.muted).padding(.trailing, 12) }
                Button(action: check) { Label(card.type == .flashcard ? "Antwort aufdecken" : "Antwort prüfen", systemImage: card.type == .flashcard ? "eye" : "checkmark") }.buttonStyle(PrimaryButtonStyle()).disabled(!canCheck).keyboardShortcut(.return, modifiers: [])
            }.frame(height: 50)
        } else if practice {
            HStack { Text("Freies Üben verändert deinen Lernplan nicht.").font(.system(size: 11)).foregroundStyle(Theme.muted); Spacer(); if card.type == .flashcard { Button("Noch unsicher") { onRate(.again) }.buttonStyle(QuietButtonStyle()); Button("Gewusst") { onRate(.good) }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction) } else { Button("Weiter") { onRate(correct == true ? .good : .again) }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction) } }
        } else {
            VStack(spacing: 13) {
                Text(correct == false ? "Diese Karte kommt in dieser Einheit noch einmal dran." : "Wie sicher war deine Antwort?").font(.system(size: 11)).foregroundStyle(Theme.muted)
                HStack(spacing: 12) {
                    ForEach(Array(ReviewRating.allCases.enumerated()), id: \.element) { position, rating in
                        Button { onRate(rating) } label: {
                            VStack(spacing: 7) {
                                HStack(spacing: 8) { Text(rating.title).font(.system(size: 13, weight: .semibold)); Text("\(position + 1)").font(.system(size: 9, design: .monospaced)).opacity(0.5) }
                                Text(Scheduler.intervalLabel(store.card(card.id)?.progress ?? card.progress, rating: rating)).font(.system(size: 10)).opacity(0.65)
                            }.foregroundStyle(ratingColor(rating)).frame(maxWidth: .infinity).padding(.vertical, 13).background(ratingColor(rating).opacity(0.08), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(ratingColor(rating).opacity(0.16)))
                        }.buttonStyle(.plain).keyboardShortcut(KeyEquivalent(Character("\(position + 1)")), modifiers: []).disabled(correct == false && rating != .again)
                    }
                }
            }
        }
    }
    private func ratingColor(_ rating: ReviewRating) -> Color { switch rating { case .again: return Theme.red; case .hard: return Theme.accent; case .good: return Theme.green; case .easy: return Theme.color("blue") } }
    private func check() {
        guard canCheck else { return }
        switch card.type {
        case .flashcard: correct = nil
        case .multipleChoice: correct = AnswerChecker.multipleChoice(selected, for: card)
        case .textInput, .cloze: correct = AnswerChecker.accepts(typed, for: card)
        case .trueFalse: correct = truth == (card.answer == "true")
        case .ordering: correct = AnswerChecker.ordering(order, for: card)
        case .matching: correct = AnswerChecker.matching(matches, for: card)
        }
        revealed = true; textFocused = false
    }
    private func shuffled(_ indices: [Int]) -> [Int] {
        guard indices.count > 1 else { return indices }
        let result = indices.shuffled(); return result == indices ? Array(indices.dropFirst()) + [indices[0]] : result
    }
}
