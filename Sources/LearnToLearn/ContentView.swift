import SwiftUI
import LearnCore
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @State private var dropTargeted = false
    var body: some View {
        HStack(spacing: 0) {
            SidebarView().frame(width: 235)
            Rectangle().fill(Theme.border).frame(width: 1)
            VStack(spacing: 0) {
                topBar
                Rectangle().fill(Theme.border).frame(height: 1)
                Group {
                    if !store.search.isEmpty { SearchResultsView() }
                    else {
                        switch store.destination {
                        case .home: DashboardView()
                        case .allSets: LibraryView(moduleID: nil)
                        case .due: DueView()
                        case .module(let id): LibraryView(moduleID: id)
                        case .set(let module, let set): SetDetailView(moduleID: module, setID: set).id(set)
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }.background(Theme.background)
        }
        .foregroundStyle(Theme.text).background(Theme.sidebar)
        .overlay(alignment: .bottom) {
            if let toast = store.toast {
                Label(toast, systemImage: "checkmark.circle.fill").font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 20).padding(.vertical, 13).background(Theme.raised, in: Capsule()).overlay(Capsule().stroke(Theme.green.opacity(0.3))).padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity)).allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.toast)
        .sheet(item: $store.sheet) { sheet in
            Group {
                switch sheet {
                case .module(let id): ModuleEditor(module: id.flatMap(store.module))
                case .set(let module, let set): SetEditor(moduleID: module, set: set.flatMap { store.set($0, module: module) })
                case .card(let module, let set, let card): CardEditor(moduleID: module, setID: set, card: card.flatMap(store.card))
                case .importer: ImportView()
                case .settings: SettingsView()
                case .study(let request): StudyView(request: request)
                }
            }.environmentObject(store).preferredColorScheme(.dark).tint(Theme.accent)
                .alert("Das hat nicht geklappt", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("OK", role: .cancel) { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
        .alert(store.deletion?.title ?? "Löschen?", isPresented: Binding(get: { store.deletion != nil }, set: { if !$0 { store.deletion = nil } })) {
            Button("Abbrechen", role: .cancel) { store.deletion = nil }
            Button("Löschen", role: .destructive) { if let target = store.deletion { store.delete(target) } }
        } message: { Text(store.deletion?.detail ?? "") }
        .alert("Das hat nicht geklappt", isPresented: Binding(get: { store.error != nil && store.sheet == nil }, set: { if !$0 { store.error = nil } })) {
            Button("OK", role: .cancel) { store.error = nil }
        } message: { Text(store.error ?? "") }
        .onChange(of: store.destination) { _, _ in store.search = "" }
    }
    private var topBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "square.grid.2x2").foregroundStyle(Theme.muted)
                Text(breadcrumb).font(.system(size: 12, weight: .medium))
            }
            Spacer()
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                TextField("Module, Sets und Karten suchen", text: $store.search).textFieldStyle(.plain).font(.system(size: 12))
                if !store.search.isEmpty { Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(Theme.muted) }
            }.padding(.horizontal, 12).padding(.vertical, 9).frame(width: 290).background(Theme.sidebar.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            Button { store.sheet = .importer } label: { Label("Importieren", systemImage: "square.and.arrow.down").font(.system(size: 12, weight: .medium)) }.buttonStyle(.plain).help("Lerninhalte importieren (⌘I)")
        }.padding(.horizontal, 32).frame(height: 66)
    }
    private var breadcrumb: String {
        switch store.destination {
        case .home: return "Dein Lernraum"
        case .allSets: return "Bibliothek / Alle Lernsets"
        case .due: return "Lernen / Heute fällig"
        case .module(let id): return "Module / \(store.module(id)?.title ?? "Modul")"
        case .set(let mi, let si): return "\(store.module(mi)?.title ?? "Modul") / \(store.set(si, module: mi)?.title ?? "Lernset")"
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "square.stack.3d.up.fill").font(.system(size: 23)).foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Learn to Learn").font(.system(size: 15, weight: .semibold))
                    Text("DEIN WISSEN. DEIN TEMPO.").font(.system(size: 7.5, weight: .medium)).tracking(1.1).foregroundStyle(Theme.muted)
                }
            }.padding(.top, 48).padding(.bottom, 36).padding(.horizontal, 22)
            VStack(spacing: 5) {
                nav("Übersicht", icon: "square.grid.2x2", destination: .home)
                nav("Heute fällig", icon: "sun.max", destination: .due, count: store.dueCards.count)
                nav("Alle Lernsets", icon: "rectangle.stack", destination: .allSets)
            }.padding(.horizontal, 12)
            HStack {
                Text("DEINE MODULE").font(.system(size: 9, weight: .semibold)).tracking(1.6).foregroundStyle(Theme.muted)
                Spacer()
                Button { store.sheet = .module(nil) } label: { Image(systemName: "plus").font(.system(size: 13)).frame(width: 22, height: 22) }.buttonStyle(.plain).help("Neues Modul")
            }.padding(.horizontal, 23).padding(.top, 34).padding(.bottom, 11)
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(store.library.modules) { module in
                        nav(module.title, icon: module.icon, destination: .module(module.id), color: Theme.color(module.color))
                            .contextMenu {
                                Button("Modul bearbeiten") { store.sheet = .module(module.id) }
                                Button("Lernset hinzufügen") { store.sheet = .set(module.id, nil) }
                                Button("Exportieren …") { store.exportContent(modules: [module]) }
                                Divider()
                                Button("Modul löschen", role: .destructive) { store.deletion = .module(module) }
                            }
                    }
                }.padding(.horizontal, 12)
            }
            Spacer(minLength: 20)
            Button { store.sheet = .importer } label: {
                VStack(alignment: .leading, spacing: 11) {
                    Image(systemName: "sparkles").font(.system(size: 17)).foregroundStyle(Theme.accent)
                    Text("Vom Skript zum Lernset").font(.system(size: 12, weight: .semibold))
                    Text("Lass deine Modulinhalte aufbereiten und importiere sie hier.").font(.system(size: 11)).foregroundStyle(Theme.muted).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    HStack { Text("Inhalte importieren"); Image(systemName: "arrow.up.right") }.font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.accent)
                }.padding(17).frame(maxWidth: .infinity, alignment: .leading).background(Theme.surface, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            }.buttonStyle(.plain).padding(.horizontal, 16).padding(.bottom, 22)
            Rectangle().fill(Theme.border).frame(height: 1)
            HStack {
                Circle().fill(Theme.green).frame(width: 5, height: 5)
                Text("Lokal gespeichert").font(.system(size: 10)).foregroundStyle(Theme.muted)
                Spacer()
                Button { store.sheet = .settings } label: { Image(systemName: "gearshape").font(.system(size: 14)).foregroundStyle(Theme.muted) }.buttonStyle(.plain).help("Einstellungen")
            }.padding(.horizontal, 22).padding(.vertical, 20)
        }.background(Theme.sidebar)
    }
    private func nav(_ title: String, icon: String, destination: Destination, count: Int? = nil, color: Color = Theme.muted) -> some View {
        let selected = isSelected(destination)
        return Button { store.search = ""; store.destination = destination } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(selected ? Theme.accent : color).frame(width: 19)
                Text(title).font(.system(size: 12, weight: selected ? .semibold : .regular)).lineLimit(1)
                Spacer(minLength: 2)
                if let count, count > 0 { Text("\(count)").font(.system(size: 10, weight: .semibold)).foregroundStyle(selected ? Theme.accent : Theme.muted).padding(.horizontal, 6).padding(.vertical, 3).background(Theme.raised, in: RoundedRectangle(cornerRadius: 4)) }
            }.foregroundStyle(selected ? Theme.text : Theme.muted).padding(.horizontal, 12).frame(height: 40)
                .background(selected ? Theme.raised.opacity(0.7) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
    private func isSelected(_ destination: Destination) -> Bool {
        if destination == store.destination { return true }
        if case .module(let id) = destination, case .set(let module, _) = store.destination { return id == module }
        return false
    }
}

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE"))).uppercased()).font(.system(size: 10, weight: .medium)).tracking(1.8).foregroundStyle(Theme.muted)
                        Text("Schön, dass du da bist.").font(.system(size: 28, weight: .semibold))
                    }
                    Spacer()
                    Label("\(store.library.streak().counted("Tag", "Tage")) in Folge", systemImage: "flame").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.accent).padding(.horizontal, 13).padding(.vertical, 9).background(Theme.accent.opacity(0.08), in: Capsule())
                }
                hero
                HStack(spacing: 16) {
                    metric(value: "\(store.dueCards.count)", title: "Heute fällig", icon: "sun.max", color: Theme.accent, caption: "Bereit für eine Wiederholung")
                    metric(value: "\(store.library.cards.filter(\.isMastered).count)", title: "Sicheres Wissen", icon: "checkmark.seal", color: Theme.green, caption: "Karten langfristig gefestigt")
                    metric(value: "\(store.library.cards.count)", title: "In deiner Bibliothek", icon: "rectangle.stack", color: Theme.color("blue"), caption: "\(store.library.sets.count.counted("Lernset", "Lernsets")) · \(store.library.modules.count.counted("Modul", "Module"))")
                }
                HStack(alignment: .top, spacing: 22) {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack {
                            SectionHeading(title: "Deine Module", caption: "\(store.library.modules.count)")
                            Button { store.sheet = .module(nil) } label: { Label("Neues Modul", systemImage: "plus").font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted) }.buttonStyle(.plain)
                        }
                        if store.library.modules.isEmpty {
                            EmptyState(icon: "books.vertical", title: "Platz für neues Wissen", message: "Lege dein erstes Modul an oder importiere ein fertiges Lernpaket.", actionTitle: "Modul anlegen", action: { store.sheet = .module(nil) }).panel(padding: 0)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 205), spacing: 14)], spacing: 14) {
                                ForEach(store.library.modules) { module in ModuleTile(module: module) }
                            }
                        }
                        HStack { SectionHeading(title: "Deine Lernsets"); Button("Alle ansehen") { store.destination = .allSets }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Theme.accent) }.padding(.top, 10)
                        VStack(spacing: 0) {
                            ForEach(Array(store.setRows.prefix(4).enumerated()), id: \.element.set.id) { index, row in
                                SetRow(module: row.module, set: row.set)
                                if index < min(4, store.setRows.count) - 1 { Divider().overlay(Theme.border).padding(.horizontal, 18) }
                            }
                            if store.setRows.isEmpty { Text("Deine Lernsets erscheinen hier.").font(.system(size: 12)).foregroundStyle(Theme.muted).padding(25) }
                        }.background(Theme.surface, in: RoundedRectangle(cornerRadius: 14)).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
                    }.frame(maxWidth: .infinity)
                    VStack(spacing: 17) {
                        DailyGoalView()
                        ActivityView()
                    }.frame(width: 245)
                }
                HStack(spacing: 8) { Image(systemName: "leaf"); Text("Ein kleiner Schritt heute. Mehr Wissen für morgen.") }.font(.system(size: 11)).foregroundStyle(Theme.muted.opacity(0.65)).frame(maxWidth: .infinity).padding(.top, 4)
            }.padding(32).frame(maxWidth: 1500)
        }
    }
    private var hero: some View {
        HStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 7) { Circle().fill(Theme.accent).frame(width: 5, height: 5); Text("DEIN TÄGLICHER WISSENSBOOST").tracking(1.7) }.font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.accent)
                Text("Wissen wächst.\nMit jeder Wiederholung.").font(.system(size: 36, weight: .regular, design: .serif)).lineSpacing(2)
                Text(store.dueCards.isEmpty ? "Alles wiederholt. Entdecke neue Inhalte oder übe ein Lernset." : "\(store.dueCards.count) Karten warten auf dich. Nimm dir einen Moment für dein Wissen.").font(.system(size: 12)).foregroundStyle(Theme.muted).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button { if store.dueCards.isEmpty { store.destination = .allSets } else { store.startStudy(cards: store.dueCards, title: "Deine tägliche Wiederholung") } } label: {
                        HStack(spacing: 18) { Text(store.dueCards.isEmpty ? "Lernsets entdecken" : "Jetzt lernen"); Image(systemName: "arrow.right") }
                    }.buttonStyle(PrimaryButtonStyle())
                    if !store.dueCards.isEmpty { Text("ca. \(max(1, store.dueCards.count / 3)) Minuten").font(.system(size: 11)).foregroundStyle(Theme.muted) }
                }.padding(.top, 3)
            }.frame(maxWidth: .infinity, alignment: .leading)
            KnowledgeOrbit().frame(width: 245, height: 230).accessibilityHidden(true)
        }.padding(30).background {
            RoundedRectangle(cornerRadius: 18).fill(LinearGradient(colors: [Color(hex: 0x292E26), Color(hex: 0x222824), Color(hex: 0x222823)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }.overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.green.opacity(0.12)))
    }
    private func metric(value: String, title: String, icon: String, color: Color, caption: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            IconBadge(icon: icon, color: color, size: 36)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 9) { Text(value).font(.system(size: 27, weight: .semibold, design: .rounded)); Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.muted) }
                Text(caption).font(.system(size: 10)).foregroundStyle(Theme.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
        }.panel(padding: 18).frame(maxWidth: .infinity)
    }
}

struct KnowledgeOrbit: View {
    var body: some View {
        ZStack {
            ForEach(0..<3) { index in Circle().stroke(Theme.green.opacity(0.08 + Double(index) * 0.015), lineWidth: 1).frame(width: CGFloat(125 + index * 55), height: CGFloat(125 + index * 55)) }
            RoundedRectangle(cornerRadius: 17).fill(Theme.green.opacity(0.07)).frame(width: 100, height: 120).rotationEffect(.degrees(-16)).offset(x: -12, y: 2).overlay(RoundedRectangle(cornerRadius: 17).stroke(Theme.green.opacity(0.15)).frame(width: 100, height: 120).rotationEffect(.degrees(-16)).offset(x: -12, y: 2))
            VStack(spacing: 17) {
                Image(systemName: "sparkle").font(.system(size: 34, weight: .light)).foregroundStyle(Theme.accent)
                HStack(spacing: 4) { ForEach(0..<3) { _ in Capsule().fill(Theme.green.opacity(0.4)).frame(width: 16, height: 3) } }
            }.frame(width: 100, height: 120).background(Color(hex: 0x353D30), in: RoundedRectangle(cornerRadius: 17)).overlay(RoundedRectangle(cornerRadius: 17).stroke(Theme.green.opacity(0.3))).rotationEffect(.degrees(9))
            Image(systemName: "checkmark").font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.green).frame(width: 38, height: 38).background(Color(hex: 0x303C2F), in: RoundedRectangle(cornerRadius: 12)).rotationEffect(.degrees(-10)).offset(x: 88, y: -63)
            Image(systemName: "plus").font(.system(size: 14, weight: .light)).foregroundStyle(Theme.accent.opacity(0.8)).offset(x: -91, y: -68)
            Circle().fill(Theme.accent).frame(width: 5, height: 5).offset(x: 61, y: 96)
            Circle().fill(Theme.green.opacity(0.7)).frame(width: 4, height: 4).offset(x: -103, y: 53)
        }
    }
}

struct DailyGoalView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        let today = store.library.todayReviews(); let goal = store.library.dailyGoal
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("Dein Tagesziel").font(.system(size: 13, weight: .semibold)); Spacer(); Button { store.sheet = .settings } label: { Image(systemName: "slider.horizontal.3").foregroundStyle(Theme.muted) }.buttonStyle(.plain).help("Tagesziel ändern") }
            ZStack {
                Circle().stroke(Theme.raised, lineWidth: 7)
                Circle().trim(from: 0, to: min(1, CGFloat(today) / CGFloat(goal))).stroke(Theme.green, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                VStack(spacing: 4) { Text("\(today)").font(.system(size: 35, weight: .medium, design: .rounded)); Text("von \(goal) Wiederholungen").font(.system(size: 9)).foregroundStyle(Theme.muted) }
            }.frame(width: 132, height: 132).frame(maxWidth: .infinity).padding(.vertical, 4)
            Text(today >= goal ? "Tagesziel erreicht. Gut gemacht!" : "Jeder Abruf zählt. Bleib neugierig.").font(.system(size: 10)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
        }.panel(padding: 20)
    }
}

struct ActivityView: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        let days = (0..<7).map { Calendar.current.date(byAdding: .day, value: $0 - 6, to: Date())! }
        let counts = days.map { day in store.library.reviews.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.count }
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Deine Woche").font(.system(size: 13, weight: .semibold)); Spacer(); Image(systemName: "chart.bar.xaxis").foregroundStyle(Theme.muted) }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).fill(index == 6 ? Theme.accent : Theme.green.opacity(counts[index] == 0 ? 0.09 : 0.5)).frame(height: max(5, CGFloat(counts[index]) / CGFloat(max(1, counts.max() ?? 1)) * 55))
                        Text(days[index].formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "de_DE")))).font(.system(size: 9)).foregroundStyle(index == 6 ? Theme.accent : Theme.muted)
                    }.frame(maxWidth: .infinity).help("\(counts[index]) Wiederholungen")
                }
            }.frame(height: 78, alignment: .bottom)
            Text("\(counts.reduce(0, +)) Wiederholungen in 7 Tagen").font(.system(size: 10)).foregroundStyle(Theme.muted)
        }.panel(padding: 20)
    }
}

struct ModuleTile: View {
    @EnvironmentObject var store: AppStore
    let module: LearningModule
    var body: some View {
        Button { store.search = ""; store.destination = .module(module.id) } label: {
            VStack(alignment: .leading, spacing: 17) {
                HStack { IconBadge(icon: module.icon, color: Theme.color(module.color), size: 38); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 10)).foregroundStyle(Theme.muted) }
                VStack(alignment: .leading, spacing: 5) { Text(module.title).font(.system(size: 15, weight: .semibold)).lineLimit(1); Text("\(module.sets.count.counted("Lernset", "Lernsets")) · \(module.cards.count.counted("Karte", "Karten"))").font(.system(size: 10)).foregroundStyle(Theme.muted) }
                GeometryReader { geo in ZStack(alignment: .leading) { Capsule().fill(Theme.raised); Capsule().fill(Theme.color(module.color).opacity(0.65)).frame(width: geo.size.width * CGFloat(module.cards.filter(\.isMastered).count) / CGFloat(max(1, module.cards.count))) } }.frame(height: 3)
            }.panel(padding: 18)
        }.buttonStyle(.plain).contextMenu {
            Button("Modul bearbeiten") { store.sheet = .module(module.id) }
            Button("Lernset hinzufügen") { store.sheet = .set(module.id, nil) }
            Button("Modul löschen", role: .destructive) { store.deletion = .module(module) }
        }
    }
}

struct SetRow: View {
    @EnvironmentObject var store: AppStore
    let module: LearningModule
    let set: LearningSet
    var body: some View {
        Button { store.search = ""; store.destination = .set(module.id, set.id) } label: {
            HStack(spacing: 13) {
                IconBadge(icon: "rectangle.stack", color: Theme.color(module.color), size: 35)
                VStack(alignment: .leading, spacing: 5) { Text(set.title).font(.system(size: 12, weight: .medium)); Text("\(module.title) · \(set.cards.count) Karten").font(.system(size: 10)).foregroundStyle(Theme.muted) }
                Spacer()
                if set.dueCount() > 0 { Pill(text: "\(set.dueCount()) fällig", color: Theme.accent) }
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Theme.muted).padding(.leading, 6)
            }.padding(17).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}
