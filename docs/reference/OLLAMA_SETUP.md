# Ollama Setup Scripts

Automatisierte Einrichtung von [Ollama](https://ollama.com) mit optimiertem Hablará-Modell (qwen2.5 / qwen3).

## Schnellstart

```bash
# macOS
curl -fsSL https://raw.githubusercontent.com/fidpa/hablara-releases/main/scripts/setup-ollama-mac.sh | bash

# Linux
curl -fsSL https://raw.githubusercontent.com/fidpa/hablara-releases/main/scripts/setup-ollama-linux.sh | bash
```

```powershell
# Windows (PowerShell)
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/fidpa/hablara-releases/main/scripts/setup-ollama-win.ps1" -OutFile "$env:TEMP\setup-ollama-win.ps1"; & "$env:TEMP\setup-ollama-win.ps1"
```

## Optionen

| Flag | PowerShell | Beschreibung |
|------|------------|--------------|
| `-m, --model <variant>` | `-Model <Variante>` | Modell-Variante wählen |
| `--lang <code>` | `-Lang <code>` | Skriptsprache festlegen (z.B. `de`, `en`, `fr`) |
| `--update` | `-Update` | Hablará-Modell aktualisieren |
| `--status` | `-Status` | Health-Check (7-Punkte-Prüfung) |
| `--diagnose` | `-Diagnose` | Support-Report für GitHub Issues |
| `--cleanup` | `-Cleanup` | Installierte Modelle aufräumen |
| `--help` | `-Help` | Hilfe anzeigen |

Ohne Flags startet ein interaktives Menü. Die Skriptsprache wird automatisch aus der System-Locale ermittelt; `--lang` überschreibt das manuell.

## Modell-Varianten

| Variante | Modell | Download | Empfehlung |
|----------|--------|----------|------------|
| `1.5b` | qwen2.5:1.5b | ~1 GB | Schwache Hardware (unter 150 GB/s Speicherbandbreite); eingeschränkte Genauigkeit, die App weist bei Fehlschluss-Erkennung und Transaktionsanalyse darauf hin |
| **`qwen3-4b`** | **qwen3:4b-thinking-2507-q4_K_M** | **~2,5 GB** | **Standard, empfohlen ab 150 GB/s Speicherbandbreite** |
| `7b` | qwen2.5:7b | ~4,7 GB | Höhere Genauigkeit, empfohlen ab 300 GB/s |
| `qwen3-8b` | qwen3:8b | ~5,2 GB | Premium, empfohlen ab 500 GB/s |

Die frühere Variante `3b` (qwen2.5:3b, nicht kommerzielle Lizenz) unterstützen Skript und App seit Skriptversion 1.8.2 nicht mehr; die App wechselt gespeicherte Einstellungen beim Start auf das Standardmodell. Ein vorhandenes Modell lässt sich bei Bedarf mit `ollama rm qwen2.5:3b-custom` und `ollama rm qwen2.5:3b` entfernen.

Das Skript misst die Speicherbandbreite und markiert die passende Variante im Menü mit `★`, nach denselben Stufen wie die App. Unter 50 GB/s empfiehlt es zusätzlich einen Cloud-Anbieter. Ohne Terminal (etwa per Pipe ohne TTY) installiert es den Standard.

Das Setup erstellt zusätzlich ein `*-custom` Modell (z.B. `qwen3:4b-custom`) mit optimierten Parametern für Hablará (reduzierter Context, Temperature 0.3).

## Beispiele

```bash
# Standardmodell installieren
./setup-ollama-mac.sh --model qwen3-4b

# Premium-Variante installieren
./setup-ollama-mac.sh --model qwen3-8b

# Skript auf Deutsch ausführen
./setup-ollama-mac.sh --lang de

# Hablará-Modell nach Script-Update aktualisieren
./setup-ollama-mac.sh --update

# Installation prüfen
./setup-ollama-mac.sh --status

# Diagnose-Report für Bug-Report erstellen
./setup-ollama-mac.sh --diagnose

# Variante wechseln
./setup-ollama-mac.sh --cleanup
./setup-ollama-mac.sh --model qwen3-8b

# Via Pipe mit Argument
curl -fsSL URL | bash -s -- --model qwen3-4b
curl -fsSL URL | bash -s -- --lang de
```

```powershell
# Windows — Variante und Sprache festlegen
.\setup-ollama-win.ps1 -Model qwen3-8b -Lang de
```

## --status (Health-Check)

Prüft 7 Punkte mit ✓/✗:

1. Ollama installiert + Version
2. Server erreichbar
3. GPU-Erkennung
4. Basis-Modell vorhanden
5. Hablará-Modell vorhanden
6. Modell antwortet (Inference-Test)
7. Speicherverbrauch

## --diagnose (Support-Report)

Generiert einen kopierbaren Plain-Text-Report für GitHub Issues:

```
=== Hablará Diagnose-Report ===

System:
  OS:           macOS 26.2 (arm64)
  RAM:          64 GB (20 GB verfügbar)
  Speicher:     97 GB frei
  Shell:        bash 5.3.9

Ollama:
  Version:      0.15.5
  Server:       läuft
  API-URL:      http://localhost:11434
  GPU:          Apple Silicon (Metal)

Hablará-Modelle:
    qwen3:4b-thinking-2507-q4_K_M 2.5 GB  ✓
    qwen3:4b-custom     2.5 GB  ✓ (antwortet)

Speicher (Hablará):  ~5.0 GB

Ollama-Log (letzte Fehler):
    [keine Fehler gefunden]

---
Erstellt: 2026-03-25 14:30:12
Script:   setup-ollama-mac.sh v1.8.2
```

Der Report enthält keine ANSI-Farben — direkt in GitHub Issues einfügbar.

## --cleanup (Modelle aufräumen)

Interaktives Menü zum Entfernen installierter Hablará-Varianten. Löscht jeweils Basis- und Custom-Modell gemeinsam. Erfordert eine interaktive Sitzung (kein Pipe-Modus).

## Plattform-Unterschiede

| Aspekt | macOS | Linux | Windows |
|--------|-------|-------|---------|
| GPU | Apple Silicon (Metal) | NVIDIA (CUDA), AMD (ROCm), Intel (oneAPI) | NVIDIA (CUDA), AMD (ROCm) |
| Ollama-Log | `~/.ollama/logs/server.log` | `journalctl -u ollama` | `%USERPROFILE%\.ollama\logs\server.log` |
| Ollama-Daten | `~/.ollama/` | `$XDG_DATA_HOME/ollama/` | `%USERPROFILE%\.ollama\` |
| Server-Start | Ollama.app / launchd / nohup | systemd / nohup | Ollama App / `ollama serve` |
| Paketmanager | Homebrew | curl-Installer | winget |

## Exit Codes

| Code | Bedeutung |
|------|-----------|
| 0 | Erfolg |
| 1 | Allgemeiner Fehler |
| 2 | Nicht genügend Speicherplatz |
| 3 | Keine Netzwerkverbindung |
| 4 | Falsche Plattform |

## App-Einstellungen nach Setup

Nach dem Setup in Hablará einstellen:

- **Provider:** Ollama
- **Modell:** `qwen3:4b-custom` (oder gewählte Variante + `-custom`)
- **Base URL:** `http://localhost:11434`

## Hinweis: Auto-generierte Scripts

Die Skriptdateien (`setup-ollama-mac.sh`, `setup-ollama-linux.sh`, `setup-ollama-win.ps1`) werden aus Vorlagen erzeugt und hier nur veröffentlicht. Änderungen an den Dateien in diesem Repository gehen beim nächsten Abgleich verloren; Fehler und Wünsche bitte als [Issue](https://github.com/fidpa/hablara-releases/issues) melden.
