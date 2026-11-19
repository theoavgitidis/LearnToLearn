import Foundation

public enum Demo {
    public static var library: LearningLibrary {
        let learning = LearningSet(title: "Lernen, das bleibt", description: "Entdecke alle sieben Fragetypen – und lerne dabei, wie Lernen funktioniert.", cards: [
            .init(type: .flashcard, prompt: "Was bedeutet **Active Recall**?", answer: "Wissen aktiv aus dem Gedächtnis abrufen, ohne die Antwort vorher nachzulesen.", explanation: "Schließe das Skript und erkläre einen Begriff aus dem Kopf. Genau diesen Abruf trainierst du hier.", tags: ["Lernstrategie"]),
            .init(type: .multipleChoice, prompt: "Welche Methoden fördern langfristiges Behalten?", options: ["Verteiltes Wiederholen", "Nur bunt markieren", "Aktives Abrufen", "Alles in einer Nacht lernen"], correctIndices: [0, 2], explanation: "Spaced Repetition verteilt Abrufe über die Zeit. Active Recall trainiert den Zugriff auf dein Wissen.", tags: ["Mehrfachauswahl"]),
            .init(type: .textInput, prompt: "Wie heißt das zeitlich verteilte Wiederholen auf Englisch?", answer: "Spaced Repetition", acceptedAnswers: ["spaced repetition", "spaced practice"], explanation: "Die Abstände werden länger, wenn du eine Karte sicher beherrschst.", hint: "Zwei Wörter, beginnend mit S und R."),
            .init(type: .trueFalse, prompt: "Sich mit einem Text vertraut zu fühlen bedeutet automatisch, ihn frei erklären zu können.", answer: "false", explanation: "Wiedererkennen und eigenständiger Abruf sind unterschiedliche Leistungen."),
            .init(type: .cloze, prompt: "Beim Active Recall rufst du Wissen aktiv aus dem {{blank}} ab.", answer: "Gedächtnis", acceptedAnswers: ["Gedaechtnis"], explanation: "Ein Abrufversuch kann auch dann hilfreich sein, wenn du danach die Lösung nachschlägst."),
            .init(type: .ordering, prompt: "Bringe einen sinnvollen Lernzyklus in die richtige Reihenfolge.", options: ["Inhalt verstehen", "Ohne Vorlage abrufen", "Antwort kontrollieren", "Später erneut wiederholen"], explanation: "Verstehen, Abruf, Feedback und ein späterer Abruf ergänzen sich."),
            .init(type: .matching, prompt: "Ordne die Lernmethoden ihrer Beschreibung zu.", pairs: [.init(left: "Active Recall", right: "Wissen aus dem Kopf abrufen"), .init(left: "Spaced Repetition", right: "Mit zeitlichen Abständen üben"), .init(left: "Interleaving", right: "Verwandte Aufgabentypen abwechseln")], explanation: "Die Methoden lassen sich kombinieren: verschiedene Aufgaben abrufen und später wiederholen.")
        ])
        let foundations = LearningSet(title: "Datenstrukturen", description: "Ein kleiner Einstieg in die Informatik.", cards: [
            .init(type: .flashcard, prompt: "Was unterscheidet **Stack** und **Queue**?", answer: "Stack: Last In, First Out (LIFO). Queue: First In, First Out (FIFO).", tags: ["Grundlagen"]),
            .init(type: .multipleChoice, prompt: "Welche Datenstruktur arbeitet nach dem LIFO-Prinzip?", options: ["Queue", "Stack", "Sortiertes Array"], correctIndices: [1], explanation: "Beim Stack wird das zuletzt abgelegte Element zuerst entnommen."),
            .init(type: .textInput, prompt: "Wie heißt die Operation, die ein Element auf einen Stack legt?", answer: "push", hint: "Das englische Wort für schieben."),
            .init(type: .matching, prompt: "Ordne die Laufzeiten zu (typische Implementierung, durchschnittlicher Fall).", pairs: [.init(left: "Array: Zugriff per Index", right: "O(1)"), .init(left: "Unsortierte Liste: Suche", right: "O(n)"), .init(left: "Balancierter Suchbaum: Suche", right: "O(log n)")])
        ])
        let statistics = LearningSet(title: "Die Mitte der Daten", description: "Mittelwert, Median und robuste Kennzahlen.", cards: [
            .init(type: .flashcard, prompt: "Wie berechnet man den arithmetischen Mittelwert?", answer: "Alle Werte addieren und die Summe durch die Anzahl der Werte teilen."),
            .init(type: .textInput, prompt: "Was ist der Median von 2, 3, 4, 8, 100?", answer: "4", explanation: "Der mittlere Wert der sortierten Liste ist 4. Der Ausreißer 100 verändert den Median hier nicht."),
            .init(type: .trueFalse, prompt: "Der Median ist gegenüber einzelnen extremen Ausreißern typischerweise robuster als der Mittelwert.", answer: "true")
        ])
        return .init(modules: [
            .init(title: "Lernen lernen", subtitle: "Dein erster Schritt · Beispielmodul", color: "orange", icon: "sparkles", sets: [learning]),
            .init(title: "Informatik", subtitle: "Grundlagen · Beispielmodul", color: "blue", icon: "terminal", sets: [foundations]),
            .init(title: "Statistik", subtitle: "Daten verstehen · Beispielmodul", color: "purple", icon: "chart.xyaxis.line", sets: [statistics])
        ])
    }
    public static var package: LearningPackage { LearningPackage(library: library) }
}
