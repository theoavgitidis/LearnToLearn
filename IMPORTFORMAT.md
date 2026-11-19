# Lerninhalte für Learn to Learn

Schicke deine Modulinhalte im Chat mit dem Wunsch: „Erstelle daraus ein Learn-to-Learn-Lernpaket gemäß IMPORTFORMAT.md“. Das Ergebnis kannst du als JSON direkt in **Importieren** einfügen oder als UTF-8-Datei mit `.json` oder `.txt` öffnen. Eine kopierbare Chat-Vorlage findest du auch in der App und in [Examples/Chat-Vorlage.txt](Examples/Chat-Vorlage.txt).

Die App benötigt keine KI-Verbindung und kein Konto. Der Chat bereitet Inhalte auf; die App übernimmt Prüfung, Speicherung und Lernen.

## Grundstruktur (Version 1)

```json
{
  "format": "learn-to-learn",
  "version": 1,
  "modules": [
    {
      "title": "Technische Mechanik",
      "subtitle": "1. Semester",
      "color": "blue",
      "icon": "atom",
      "sets": [
        {
          "title": "Kräfte",
          "description": "Begriffe und Grundlagen",
          "cards": [
            {
              "type": "flashcard",
              "prompt": "Welche SI-Einheit hat eine Kraft?",
              "answer": "Newton (N)",
              "explanation": "1 N = 1 kg · m / s².",
              "tags": ["Einheiten"]
            }
          ]
        }
      ]
    }
  ]
}
```

Pflichtfelder: `format`, `version`, `modules`; pro Modul `title` und `sets`; pro Set `title` und `cards`; pro Karte `type`, `prompt` und die passenden Antwortfelder. Mindestens ein Modul, ein Set je Modul und eine Karte je Set. Keine IDs oder Lernfortschritte angeben. Zusätzliche unbekannte Felder werden ignoriert.

`subtitle`, `description`, `color` und `icon` sind optional. Farben: `orange`, `blue`, `purple`, `green`, `pink`, `yellow`. Icons sind SF-Symbolnamen, z. B. `books.vertical`, `sparkles`, `atom`, `function`, `terminal`, `chart.xyaxis.line`. Standard: orange und books.vertical.

## Die sieben Fragetypen

| type | Benötigte Antwortfelder | Verhalten |
| --- | --- | --- |
| `flashcard` | `answer`: Text | Antwort aufdecken und selbst bewerten |
| `multipleChoice` | `options`: 2–12 Texte, `correctIndices`: Liste gültiger Indizes | Eine oder mehrere richtige Antworten; Zählung ab **0** |
| `textInput` | `answer`: Text oder nichtleere `acceptedAnswers`: Textliste | Texteingabe mit Vergleich gegen Muster und Varianten |
| `trueFalse` | `answer`: **Text** `"true"` oder `"false"` | Wahr/Falsch, kein JSON-Boolean |
| `cloze` | `prompt` mit genau einem `{{blank}}`; Antwort wie textInput | Ein Lückenfeld pro Karte |
| `ordering` | `options`: 2–12 Texte **in korrekter Reihenfolge** | App mischt; mit Pfeilen sortieren |
| `matching` | `pairs`: 2–10 Objekte aus `left` und `right` | Zusammengehörige Begriffe auswählen |

Alle Optionen einer Aufgabe müssen eindeutig und nicht leer sein. Bei `matching` gilt das für die linken und rechten Begriffe jeweils getrennt. `correctIndices` darf keine Duplikate oder ungültigen Indizes enthalten.

Optional bei jeder Karte: `explanation` (Erklärung nach dem Auflösen), `hint` (einblendbarer Hinweis), `tags` (Textliste). Einfache Markdown-Formatierung in Frage, Antwort und Erklärung funktioniert. Formeln als lesbarer Unicode-/Klartext angeben; die App hat keinen LaTeX-Renderer und keinen Medienimport.

Bei Texteingaben werden Groß-/Kleinschreibung, diakritische Zeichen sowie überflüssige Leerzeichen ignoriert. Inhaltliche oder sprachliche Gleichwertigkeit wird nicht automatisch erkannt. Ergänze `acceptedAnswers` für alternative Begriffe, Einheiten oder Schreibweisen. Nach einer nicht erkannten Texteingabe lässt sich „Meine Antwort ist sinngemäß richtig“ wählen.

Ein vollständiges, importierbares Beispiel mit allen sieben Typen steht in [Examples/Alle-Fragetypen.json](Examples/Alle-Fragetypen.json).

## Import und Daten

Vor dem Import prüft die App Struktur und Aufgaben und zeigt die enthaltenen Module, Sets und Kartenzahlen. Maximal 25 MB, 200 Module und 50.000 Karten pro Import. JSON-Codeblöcke aus der Zwischenablage werden erkannt; reines JSON ist vorzuziehen.

Du kannst **neue Module** anlegen oder **alle enthaltenen Sets einem vorhandenen Modul hinzufügen**. Ein Import erzeugt neue IDs. Bestehende Inhalte und Lernfortschritte werden nicht überschrieben oder automatisch zusammengeführt. Wiederholter Import erzeugt zusätzliche Inhalte, auch bei gleichen Titeln.

Der Export von Lerninhalten ist dasselbe portable Format, ohne Lernfortschritt. Eine **Sicherung** aus den Einstellungen ist ein anderes Format und enthält die vollständige Bibliothek einschließlich Fortschritt und Statistik. Sicherungen ausschließlich über **Einstellungen → Wiederherstellen** einlesen; sie ersetzen nach Bestätigung die Bibliothek. Die bisherige Datei wird zur Wiederherstellung aufbewahrt.

Ein Inhalts-Export setzt nichtleere Module und Sets voraus. Bei noch leeren Sets nutze die vollständige Sicherung oder exportiere gezielt ein ausgefülltes Lernset.
