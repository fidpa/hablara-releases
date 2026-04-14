# Ground-Truth Annotation – KI-Ergebnisse manuell validieren

**Zielgruppe:** Forscher, Psychologen, Qualitätsprüfer
**Voraussetzung:** Aufnahme mit mindestens einer abgeschlossenen KI-Analyse

---

## Wozu Ground-Truth Annotation?

Hablará analysiert Aufnahmen automatisch. Wie jedes KI-System liegt es gelegentlich falsch –
Ground-Truth Annotation gibt dir die Möglichkeit, pro Analyse-Dimension manuell zu bestätigen
oder zu korrigieren, was die KI erkannt hat.

Typische Anwendungsfälle:

- **Wissenschaftliche Benchmarks** — Annotierte Daten als Gold-Standard für Accuracy-Messungen (z.B. für DFKI- oder Fraunhofer-Kooperationen)
- **Interne Qualitätssicherung** — Systematische Erfassung von KI-Fehlern über einen Datensatz
- **Multi-Annotator-Studien** — Mehrere Personen annotieren dieselben Aufnahmen unabhängig voneinander; Inter-Annotator Agreement wird über das `Annotator ID`-Feld ermöglicht

---

## Schritt für Schritt

### 1. Aufnahme öffnen

In der **Aufnahmen-Bibliothek** (Archiv-Symbol in der Seitenleiste) eine analysierte Aufnahme
aufrufen und **„Details anzeigen"** klicken.

### 2. Annotationsbereich öffnen

Am Ende der aufgeklappten Details erscheint der Bereich **„Ground-Truth Annotation"**
(Klemmbrett-Symbol). Ein Klick darauf öffnet ihn.

> Der Bereich erscheint nur, wenn die Aufnahme mindestens eine KI-Analyse enthält.

### 3. Dimensionen annotieren

Für jede verfügbare Analyse-Dimension zeigt Hablará eine Zeile mit dem KI-Ergebnis:

```
Emotion:   stress (85%)   [✓] [✗]   +Notiz
```

| Element | Bedeutung |
|---------|-----------|
| **KI-Ergebnis** | Was die KI erkannt hat (mit Konfidenzwert) |
| **✓ Korrekt** | Die KI hatte Recht – Annotation bestätigt das Ergebnis |
| **✗ Inkorrekt** | Die KI lag falsch – ein Korrektur-Dropdown erscheint |
| **+Notiz** | Optionales Freitextfeld für Begründung oder Anmerkung |

**Verfügbare Dimensionen** (jeweils nur sichtbar, wenn die Aufnahme analysiert wurde):

| Dimension | Korrektur-Option |
|-----------|-----------------|
| Emotion | Dropdown: korrekte Emotion auswählen |
| Trugschlüsse | Multi-Select: korrekte Fallacy-Typen auswählen |
| Thema | Dropdown: korrektes Thema auswählen |
| GFK (Gewaltfreie Kommunikation) | Freitext-Notiz |
| Kognitive Verzerrungen | Freitext-Notiz |
| Vier-Seiten-Modell | Freitext-Notiz |
| Ton | Freitext-Notiz |

### 4. Annotator ID eintragen (optional)

Für Multi-Annotator-Studien: Trage deine persönliche ID in das Feld **„Annotator ID"** ein,
z.B. `psych-01` oder `rater-A`. Das Feld bleibt leer, wenn es nicht relevant ist.

### 5. Speichern

Klick auf **„Speichern"** – die Annotation wird direkt in die Metadaten der Aufnahme geschrieben
und die Liste aktualisiert sich automatisch.

Gespeicherte Annotationen zeigen im Bereichs-Header die Anzahl annotierter Dimensionen:

```
Ground-Truth Annotation   3 annotiert   ▾
```

### 6. Annotation zurücksetzen

**„Zurücksetzen"** löscht alle Annotationen dieser Aufnahme vollständig.

---

## Export mit Ground-Truth-Daten

Annotierte Aufnahmen lassen sich mit vollständigen Ground-Truth-Daten exportieren –
sowohl als JSON als auch als CSV.

### JSON-Export

Das exportierte JSON enthält ein `groundTruth`-Objekt mit allen annotierten Dimensionen
und ISO-Zeitstempel der Annotation:

```json
{
  "id": "abc-123",
  "primaryEmotion": "stress",
  "groundTruth": {
    "emotion": {
      "correct": false,
      "correctEmotion": "frustration",
      "annotatedAt": "2026-03-13T10:00:00Z",
      "annotatorConfidence": 0.9
    },
    "topic": {
      "correct": true,
      "annotatedAt": "2026-03-13T10:00:00Z"
    },
    "annotatorId": "psych-01"
  }
}
```

### CSV-Export

Der CSV-Export enthält 12 zusätzliche `gt_*`-Spalten (kompatibel mit Excel, R, Python/pandas):

| Spalte | Inhalt |
|--------|--------|
| `gtEmotionCorrect` | `true` / `false` / leer |
| `gtEmotionLabel` | Korrigierte Emotion (falls angegeben) |
| `gtFallaciesCorrect` | `true` / `false` / leer |
| `gtFallacyTypes` | Korrekte Typen, `\|`-getrennt |
| `gtMissedFallacyTypes` | Fehlende Typen, `\|`-getrennt |
| `gtGfkCorrect` | `true` / `false` / leer |
| `gtCognitiveCorrect` | `true` / `false` / leer |
| `gtFourSidesCorrect` | `true` / `false` / leer |
| `gtToneCorrect` | `true` / `false` / leer |
| `gtTopicCorrect` | `true` / `false` / leer |
| `gtTopicLabel` | Korrigiertes Thema (falls angegeben) |
| `gtAnnotatorId` | Annotator ID |

---

## Tipps für Forschungsprojekte

**Inter-Annotator Agreement (IAA):**

1. Jede annotierenden Person vergibt eine eindeutige `Annotator ID`
2. Dieselben Aufnahmen von mehreren Personen unabhängig annotieren lassen
3. CSV-Export → Cohen's Kappa oder Fleiss' Kappa in R oder Python berechnen

**Forschungskompatibilität:**

- Das JSON-Format orientiert sich am **W3C Web Annotation Data Model** (Provenance: Ersteller + Zeitstempel)
- Das `dimensional`-Feld im `emotion`-Objekt unterstützt Valence/Arousal/Dominance-Werte –
  kompatibel mit **IEMOCAP**- und **EmoDB**-Datensätzen
- Einzelne JSON-Exporte lassen sich zu JSONL zusammenführen (**EmoBox**-kompatibel)

**Annotator-Konfidenz:**

Das optionale Feld `annotatorConfidence` (0.0–1.0) im JSON-Export dokumentiert,
wie sicher du dir bei deiner eigenen Einschätzung warst – nützlich für gewichtete
Inter-Annotator-Analysen.

---

## Häufige Fragen

**Der Bereich „Ground-Truth Annotation" erscheint nicht.**
Die Aufnahme enthält noch keine KI-Analyse. Lass die Aufnahme zuerst analysieren –
dazu muss ein LLM-Provider konfiguriert sein (Einstellungen → LLM).

**Ich sehe nur manche Dimensionen, andere fehlen.**
Nur Dimensionen, für die Analysedaten vorliegen, werden angezeigt. Wurde z.B.
GFK in den Einstellungen deaktiviert, erscheint sie hier nicht.

**Die Annotation verschwindet nach einem Neustart.**
Prüfe, ob **Automatische Speicherung** in den Einstellungen aktiviert ist.
Ohne diese Einstellung werden keine Metadaten-Dateien auf der Festplatte angelegt.
