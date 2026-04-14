# Modell-Sprachkompatibilität

Nicht jede Kombination aus Ollama-Modell und Analysesprache liefert zuverlässige
Ergebnisse. Hablará blendet Analysen, die ein Modell in einer bestimmten Sprache
nicht sicher beherrscht, automatisch aus (✗) oder kennzeichnet sie als eingeschränkt (⚠).

## Kompatibilitätsmatrix

Die vollständige Übersicht (7 Analysen × 4 Modelle × 13 Sprachen) mit Legende:

→ **https://hablara.app/technische-details**

## Technische Grundlage (SSOT)

Die Matrix wird zur Laufzeit aus dem Code gelesen — nicht aus der Website.
Änderungen müssen daher in der Quelldatei vorgenommen werden:

`src/lib/features/model-compatibility.ts`

Die Website `technische-details.astro` ist eine rein visuelle Darstellung dieser Daten.
