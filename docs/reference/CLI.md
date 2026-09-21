# hablara-cli: Batch-Transkription und Analyse ohne Oberfläche

`hablara-cli` transkribiert Audiodateien mit whisper.cpp und analysiert Texte mit denselben
16 Methoden wie die Desktop-App, komplett im Terminal. Gedacht für Forschung, Batch-Auswertungen
und Pipelines in R oder Python. Ergebnisse gehen als JSON, JSONL, CSV oder Text auf stdout,
Fortschritt und Fehler auf stderr.

Version dieser Referenz: hablara-cli 1.7.6 und neuer.

---

## Schnellstart

```bash
# 1. Binary aus dem Release laden und in den PATH legen (siehe Installation)
# 2. Konfiguration anlegen
hablara-cli config init

# 3. Text analysieren (Ollama läuft lokal, Standard)
echo "Ich freue mich, dass das Projekt endlich fertig ist." | hablara-cli analyze --stdin -m emotion,tone

# 4. Audio transkribieren und analysieren
hablara-cli process interview.wav -m emotion,topic,summary --segments -o jsonl > interview.jsonl
```

---

## Installation

### Download

Jedes Release unter [github.com/fidpa/hablara-releases/releases](https://github.com/fidpa/hablara-releases/releases)
enthält:

| Plattform | Asset |
|-----------|-------|
| macOS (Apple Silicon und Intel) | `hablara-cli-macos-universal.tar.gz` |
| Linux x86_64 | `hablara-cli-linux-x86_64.tar.gz` |
| Windows x64 | `hablara-cli-windows-x86_64.zip` |

Neben jedem Asset liegt eine `.sha256`-Datei zur Prüfung.

```bash
# macOS / Linux
tar xzf hablara-cli-macos-universal.tar.gz
shasum -a 256 -c hablara-cli-macos-universal.tar.gz.sha256
mkdir -p ~/.local/bin && mv hablara-cli ~/.local/bin/
export PATH="$HOME/.local/bin:$PATH"
hablara-cli --version
```

```powershell
# Windows (PowerShell)
Expand-Archive hablara-cli-windows-x86_64.zip -DestinationPath "$env:LOCALAPPDATA\Programs\hablara"
$env:PATH += ";$env:LOCALAPPDATA\Programs\hablara"
hablara-cli --version
```

**macOS Gatekeeper:** Das Binary ist mit einer Developer-ID signiert, aber nicht notarisiert.
Meldet macOS beim ersten Start, das Programm könne nicht geprüft werden, hilft:

```bash
xattr -d com.apple.quarantine ~/.local/bin/hablara-cli
```

### Whisper (nur für `transcribe` und `process`)

`hablara-cli` ruft ein `whisper-cli`-Binary von [whisper.cpp](https://github.com/ggml-org/whisper.cpp)
auf und braucht ein ggml-Modell.

```bash
# macOS
brew install whisper-cpp

# Linux: whisper.cpp aus dem Quellcode bauen, whisper-cli in den PATH legen
```

Modelle sind `ggml-*.bin`-Dateien, etwa von [huggingface.co/ggerganov/whisper.cpp](https://huggingface.co/ggerganov/whisper.cpp/tree/main).
Für Deutsch empfiehlt sich `german-turbo`, für andere Sprachen `large-v3-turbo`. Den Modellordner
kennt die CLI über eine dieser drei Angaben (in dieser Reihenfolge):

1. `--models-dir <ordner>`
2. Umgebungsvariable `HABLARA_MODELS_DIR`
3. `[whisper] models_dir` in `cli.toml`

Ohne Angabe sucht sie `<whisper-binary>/../../models`. Bei Homebrew gibt es diesen Ordner nicht;
dann ist eine der drei Angaben Pflicht, die Fehlermeldung nennt sie.

Das Whisper-Binary findet die CLI in dieser Reihenfolge: `--whisper-path`, `HABLARA_WHISPER_PATH`,
`[whisper] path`, Datenordner (`~/Library/Application Support/hablara/bin`, `~/.local/share/hablara/bin`,
`%LOCALAPPDATA%\hablara\bin`; Dateinamen `whisper-cli`, `whisper`, `whisper-cpp`), zuletzt dieselben
Namen im PATH.

### LLM-Provider

| Provider | Wo läuft es | Einrichtung |
|----------|-------------|-------------|
| `ollama` (Standard) | lokal | [Ollama-Setup](./OLLAMA_SETUP.md); die CLI prüft vor jedem Lauf, ob das Modell installiert ist |
| `apple-intelligence` (`apple`) | lokal, macOS 26.4+ auf Apple Silicon | keine |
| `openai`, `anthropic` | Cloud, USA | API-Key im Schlüsselbund und Zustimmung, siehe unten |
| `mistral` | Cloud, EU (Paris) | API-Key im Schlüsselbund und Zustimmung, siehe unten |

API-Keys liegen im Schlüsselbund des Betriebssystems, im selben Eintrag wie bei der Desktop-App.
Einrichten über die Desktop-App (Einstellungen) oder im Terminal:

```bash
# macOS
security add-generic-password -s hablara -a openai-api-key -w <KEY>
# Linux (Secret Service)
secret-tool store --label 'hablara' service hablara username openai-api-key target default
```

```powershell
# Windows
cmdkey /generic:openai-api-key.hablara /user:openai-api-key /pass:<KEY>
```

Für Anthropic und Mistral entsprechend `anthropic-api-key` und `mistral-api-key`. Modelle und Kosten:
[LLM_PROVIDERS.md](./LLM_PROVIDERS.md).

---

## Zustimmung zur Cloud-Verarbeitung

OpenAI, Anthropic und Mistral erhalten den Transkripttext. Audio verlässt den Rechner nie.
Die Desktop-App holt die Zustimmung in einem Dialog ein (DSGVO Art. 6 Abs. 1 a); die CLI
verlangt sie in der Konfigurationsdatei:

```toml
[cloud]
processing_consent = true
```

Ohne diesen Schlüssel bricht die CLI bei Cloud-Providern mit Exit-Code 2 ab und nennt Anbieter
und Zielregion. Mit Zustimmung schreibt sie einmal pro Lauf einen Hinweis auf stderr. Für
personenbezogene Daten Dritter bleibt Ollama die datenschutzfreundliche Wahl, Mistral die
EU-Option. Details: [Datenschutz](../legal/PRIVACY.md).

---

## Befehle

```
hablara-cli transcribe [OPTIONEN] <DATEIEN>...   Audio transkribieren
hablara-cli analyze    [OPTIONEN] [DATEIEN]...   Text analysieren (oder --stdin)
hablara-cli process    [OPTIONEN] <DATEIEN>...   Transkribieren und analysieren
hablara-cli config show | init [--force]         Konfiguration anzeigen oder anlegen
```

Globale Optionen: `--config <datei>` (Konfigurationsdatei, sonst `HABLARA_CLI_CONFIG`), `-q` (kein
Fortschrittsbalken), `-v` / `-vv` (Log-Level info / debug auf stderr; `RUST_LOG` hat Vorrang).
`hablara-cli <befehl> --help` zeigt je Befehl drei Beispiele.

Umgebungsvariablen: `HABLARA_CLI_CONFIG`, `HABLARA_WHISPER_PATH`, `HABLARA_MODELS_DIR`,
`HABLARA_OLLAMA_URL` (vor `[ollama] base_url`), `RUST_LOG`. Reihenfolge überall: Kommandozeile vor
Umgebung vor `cli.toml` vor eingebautem Standard.

### Optionen

| Option | Befehle | Bedeutung | Konfiguration |
|--------|---------|-----------|---------------|
| `-m, --methods <liste>` | analyze, process | Methoden, kommagetrennt, oder `all` | Standard `emotion` |
| `--provider <name>` | analyze, process | `ollama`, `openai`, `anthropic`, `mistral`, `apple-intelligence` | `[default] provider` |
| `--model <name>` (`--llm-model`) | analyze, process | LLM-Modell | `[default] model`, sonst `[<provider>] model` |
| `--prompt-language de\|en` | analyze, process | Sprache der Analyse-Prompts | `[default] prompt_language` |
| `-o, --output json\|jsonl\|csv\|text` | alle | Ausgabeformat | `[default] output` |
| `-j, --jobs <n>` | alle | Dateien parallel | `[default] jobs` |
| `--stdin` | analyze | Text von stdin statt aus Dateien | |
| `--whisper-path <pfad>` | transcribe, process | whisper-cli-Binary | `[whisper] path` |
| `--whisper-model <name>` (`--model` bei transcribe) | transcribe, process | ggml-Modell, etwa `german-turbo` | `[whisper] model` |
| `--models-dir <ordner>` | transcribe, process | Ordner mit `ggml-*.bin` | `HABLARA_MODELS_DIR`, `[whisper] models_dir` |
| `--language <code>` | transcribe, process | Sprache für Whisper (ISO 639-1 oder `auto`) | Standard `de` |
| `--segments` | transcribe, process | Zeitgestempelte Segmente mit Konfidenz ausgeben | |
| `--guard` | analyze, process | Analyse-Wächter: Texte unter der Mindestwortzahl ohne LLM-Aufruf überspringen | |
| `--guard-min-words <n>` | analyze, process | Mindestwortzahl für den Wächter | Standard 10 |

Reihenfolge bei allen Optionen mit Konfigurationsgegenstück: Kommandozeile vor Umgebungsvariable
vor `cli.toml` vor eingebautem Standard.

### Methoden

`emotion`, `argument` (`fallacy`), `tone`, `gfk`, `cognitive`, `foursides`, `topic`, `summary`,
`transactional_analysis` (`ta`), `appraisal`, `regulatory_focus`, `speaker_segmentation`,
`cognitive_debrief` (`debrief`), `bible_impulse` (`bible`), `prayer`, `punctuation`; `all` für alle.
Was die Methoden liefern: [FEATURES.md](../guides/FEATURES.md). `summary`, `cognitive_debrief` und
`prayer` bauen auf den Ergebnissen der anderen Methoden auf und laufen deshalb zuletzt.

Leere Eingaben (auch nur Leerzeichen) gehen nie ans LLM; alle Methoden erscheinen dann als
`{"skipped": true, "reasonCode": "input_too_short"}`.

---

## Konfiguration

`hablara-cli config init` legt `cli.toml` an, `config show` zeigt Pfad und Inhalt:

| Plattform | Pfad |
|-----------|------|
| macOS | `~/Library/Application Support/hablara/cli.toml` |
| Linux | `~/.config/hablara/cli.toml` |
| Windows | `%APPDATA%\hablara\cli.toml` |

```toml
[default]
provider = "ollama"          # ollama | openai | anthropic | mistral | apple-intelligence
# model = "qwen2.5:7b-custom" # gilt für jeden Provider; sonst [<provider>] model
output = "json"              # json | jsonl | csv | text
jobs = 1
prompt_language = "de"       # de | en

[ollama]
base_url = "http://127.0.0.1:11434"
model = "qwen3:4b-custom"

[openai]
model = "gpt-4o-mini"

[anthropic]
model = "claude-sonnet-4-20250514"

[mistral]
model = "mistral-small-latest"

[whisper]
# path = "/opt/homebrew/bin/whisper-cli"
model = "german-turbo"
# models_dir = "/Users/me/whisper-models"

[cloud]
processing_consent = false
```

Unbekannte Schlüssel sind ein Fehler, damit ein Tippfehler sofort auffällt. `config init` überschreibt
eine vorhandene Datei nur mit `--force`.

---

## Ausgabe

### JSON (Standard) und JSONL

Ein Objekt je Datei. `meta` ist immer dabei, damit sich ein Ergebnis reproduzieren lässt;
`segments` nur mit `--segments`.

```json
[
  {
    "file": "interview.wav",
    "transcription": "Heute ist Sonntag!",
    "segments": [
      { "start": 0.0, "end": 2.12, "text": "Heute ist Sonntag!", "confidence": 0.797 }
    ],
    "analyses": {
      "emotion": { "primary": "joy", "confidence": 0.85, "granularity": "medium", "markers": ["Sonntag"] },
      "topic": { "topic": "creativity_hobbies", "confidence": 0.7, "keywords": ["Sonntag"] },
      "summary": "Du wirkst gelöst ..."
    },
    "meta": {
      "cliVersion": "1.7.6",
      "createdAt": "2026-09-13T18:58:23Z",
      "provider": "ollama",
      "model": "qwen3:4b-custom",
      "promptLanguage": "de",
      "whisperModel": "german-turbo-q8_0",
      "language": "de"
    }
  }
]
```

Fehlgeschlagene Dateien tragen `error` statt `transcription`/`analyses`; einzelne Methoden können
`{"error": "..."}` enthalten, wenn das LLM keine gültige Antwort geliefert hat.

JSONL schreibt dasselbe Objekt je Zeile und eignet sich für große Batches:

```r
library(jsonlite)
d <- stream_in(file("interview.jsonl"))
```

```python
import pandas as pd
df = pd.read_json("interview.jsonl", lines=True)
```

### CSV (Long-Format)

Eine Zeile je Wert, Spalten `file,method,field,value`. Verschachtelte Felder als Punkt-Pfad,
Arrays als JSON-Text, Segmente als `segments,0.start` usw.

```csv
file,method,field,value
interview.wav,meta,cliVersion,1.7.6
interview.wav,transcription,,Heute ist Sonntag!
interview.wav,emotion,confidence,0.85
interview.wav,emotion,primary,joy
interview.wav,gfk,reasonCode,input_too_short
interview.wav,gfk,skipped,true
interview.wav,summary,text,Du wirkst gelöst ...
```

Ins Breitformat: `tidyr::pivot_wider(names_from = c(method, field), values_from = value)` bzw.
`df.pivot(index="file", columns=["method", "field"], values="value")`.

### Text

Menschlich lesbar: Transkription je Datei, darunter je Methode eine eingerückte Zeile.

```
Heute ist Sonntag!
  emotion: joy (85%)
  gfk: skipped (input_too_short)
  summary: Du wirkst gelöst.
  topic: creativity_hobbies (70%)
```

---

## Exit-Codes

| Code | Bedeutung |
|------|-----------|
| `0` | Alle Dateien erfolgreich (Wächter-Skips zählen als Erfolg) |
| `1` | Teilerfolg: mindestens eine Datei fehlgeschlagen, mindestens eine erfolgreich |
| `2` | Alle Dateien fehlgeschlagen, oder ein Fehler vor der Verarbeitung: Konfiguration, Argumente, fehlende Cloud-Zustimmung, Provider nicht erreichbar oder Modell nicht installiert |

Eine unlesbare Eingabedatei zählt als fehlgeschlagen und steht mit `error` in der Ausgabe. Bricht der
Leser die Pipe ab (`| head`), bleibt der Exit-Code der der Verarbeitung.

---

## Beispiele

```bash
# Alle WAV-Dateien eines Ordners, vier parallel, alle Methoden, JSONL in eine Datei
hablara-cli process aufnahmen/*.wav -j 4 -m all --guard -o jsonl > ergebnisse.jsonl

# Englische Interviews mit englischen Prompts und Segment-Zeitstempeln
hablara-cli process interviews/*.wav --language en --prompt-language en --segments

# Vorhandene Transkripte nur analysieren, EU-Cloud
hablara-cli analyze transkripte/*.txt -m emotion,gfk,ta --provider mistral

# Homebrew-Whisper mit eigenem Modellordner
hablara-cli transcribe --models-dir ~/whisper-models --whisper-model large-v3-turbo vortrag.mp3
```

Ein fertiges Batch-Skript mit Ausgabebenennung je Datei liegt im Quell-Repository unter
`examples/research/`.

---

## Fehlerbilder

| Meldung | Ursache und Abhilfe |
|---------|---------------------|
| `Whisper binary not found` | `brew install whisper-cpp` oder `--whisper-path` setzen |
| `Model not found: german-turbo in /opt/homebrew/models` | Modellordner angeben: `--models-dir`, `HABLARA_MODELS_DIR` oder `[whisper] models_dir` |
| `ollama not reachable ... Is ollama serve running?` | Ollama starten: `ollama serve` |
| `Model 'x' is not installed in Ollama` | `ollama pull x` oder eines der aufgelisteten Modelle wählen |
| `Cloud processing requires consent` | `[cloud] processing_consent = true` in `cli.toml` |
| `No API key found for openai in keychain` | Key wie oben im Schlüsselbund hinterlegen |
| `Config already exists` | `config init --force` überschreibt bewusst |
| `unknown field` beim Laden der Konfiguration | Tippfehler in `cli.toml`, die Meldung nennt Zeile und Schlüssel |

Whisper liest `wav`, `mp3`, `ogg` und `flac`; `m4a`/`aac` vorher konvertieren, etwa mit
`ffmpeg -i datei.m4a -ar 16000 -ac 1 datei.wav`.
