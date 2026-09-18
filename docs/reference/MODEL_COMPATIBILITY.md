# Modell-Sprachkompatibilität

Nicht jede Kombination aus Modell und Analysesprache liefert gleich gute Ergebnisse.
Hablará prüft das für jede Kombination aus Analyse, Modell und Sprache und kennzeichnet
sie in den Einstellungen unter „Analyse".

## Die drei Kennzeichen

| Kennzeichen | Bedeutung | Folge in der App |
|---|---|---|
| **Gesperrt** | Das Modell liefert in dieser Sprache keine verwertbare Antwortstruktur (unter 78 % gültige Antworten). | Die Analyse lässt sich nicht einschalten. |
| **Langsam** | Die Antwort dauert im Mittel über 5 Sekunden, bei der Nachbesprechung über 10 Sekunden. | Die Analyse läuft, die Karte weist auf die Wartezeit hin. |
| **Genauigkeit** | Die Antwort kommt zuverlässig, trifft aber oft die falsche Kategorie. | Die Analyse läuft, die Karte nennt die gemessene Trefferquote. |

Gesperrt heißt: gar nicht. Die beiden anderen Kennzeichen sind Hinweise, keine Sperren;
die Analyse läuft, und die Entscheidung bleibt bei dir.

## Was heute gilt

Gemessen werden 12 Analysen gegen 5 lokale Ollama-Modelle in 15 Sprachen.

- **Keine Sperren mehr bei den lokalen Modellen.** Seit die App das Antwortformat als
  Struktur vorgibt, halten alle fünf Modelle die Form in allen 15 Sprachen ein. Die
  früheren Sperren betrafen die Form der Antwort, nicht das Sprachverständnis.
- **Genauigkeitshinweise trägt nur das kleinste Modell** (`qwen2.5:1.5b-custom`), und zwar
  bei der Fehlschluss-Erkennung und der Transaktionsanalyse. Es bleibt der Einstieg für
  schwache Hardware; wer diese beiden Analysen braucht, nimmt ein größeres Modell.
- **Langsam-Hinweise** hängen an Modell und Sprache. Tschechisch, Rumänisch und Polnisch
  brauchen durchweg mehr Zeit als Deutsch oder Englisch.
- **Cloud-Anbieter** (OpenAI, Anthropic, Mistral) tragen keine Einschränkungen.
- **Apple Intelligence** unterstützt Tschechisch, Polnisch, Rumänisch und Russisch nicht;
  in diesen Sprachen ist keine Analyse verfügbar. In den übrigen Sprachen laufen die
  Standard-Analysen, seit September 2026 auch Transaktionsanalyse und Appraisal. Gesperrt
  bleiben je nach Sprache einzelne Analysen (Kognitive Verzerrungen, Bibelimpuls,
  Fehlschluss-Erkennung, im Japanischen auch GFK und Coaching).

## Die vollständige Matrix

Alle Kombinationen mit Legende und Messdatum:

→ **https://hablara.de/technische-details**

Die App selbst zeigt dieselben Angaben dort, wo sie zählen: an der jeweiligen Analyse in
den Einstellungen.

---

Weitere Informationen:
[Ollama einrichten](./OLLAMA_SETUP.md) · [Cloud-Provider](./LLM_PROVIDERS.md) · [Features](../guides/FEATURES.md)
