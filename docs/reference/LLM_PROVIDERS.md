# Cloud LLM-Provider: OpenAI, Anthropic und Mistral

Hablará unterstützt vier LLM-Provider: Ollama (Standard, vollständig lokal),
OpenAI, Anthropic und Mistral. Diese Seite erklärt das Setup der drei Cloud-Optionen.

Auf Macs mit macOS 26 steht zusätzlich Apple Intelligence zur Wahl (auf dem Gerät, ohne
Download und ohne API-Key, Aufnahmen bis 5 Minuten). Die App-Store-Version wählt es bei der
Ersteinrichtung auf Macs mit höchstens 8 GB Arbeitsspeicher vor, sofern die App-Sprache
unterstützt wird; änderbar unter Einstellungen → KI-Modelle.

Für lokale Inferenz mit Ollama: [OLLAMA_SETUP.md](./OLLAMA_SETUP.md)

---

## Wann Cloud sinnvoll ist

| Kriterium | Lokal (Ollama) | Cloud (OpenAI / Anthropic / Mistral) |
|-----------|---------------|---------------------------|
| Datenschutz | ✅ Alles auf dem Gerät | ⚠️ Transkripte verlassen das Gerät |
| Geschwindigkeit | 2–4 s | 0,3–2 s |
| Kosten | Kostenlos | $0,0002–$0,012 pro Analyse |
| Setup | Modell-Download (~5 GB) | API-Key in den Einstellungen |
| Offline-Fähigkeit | ✅ | ❌ |

**Empfehlung:** Ollama für datenschutzsensible Inhalte; Cloud für maximale
Geschwindigkeit auf allen Geräten. Wer Cloud braucht, aber innerhalb der EU bleiben will,
nimmt Mistral (Verarbeitung in Paris).

---

## Datenschutz-Hinweis (GDPR)

> **Wichtig:** Bei Cloud-Providern werden Transkripte an externe Server übertragen.
> Audio-Dateien verlassen das Gerät **niemals** – nur der Transkripttext wird gesendet.
>
> Hablará zeigt beim ersten Wechsel auf einen Cloud-Provider ein Zustimmungs-Fenster
> (GDPR Art. 6(1)(a)). API-Keys werden verschlüsselt im OS-Schlüsselbund gespeichert:
> macOS Keychain (AES-256-GCM) / Windows Credential Manager / Linux Secret Service.

---

## Option A: OpenAI

### Account und API-Key

1. Account unter [platform.openai.com/signup](https://platform.openai.com/signup) erstellen
2. Login → **API Keys** → „Create new secret key"
3. Key kopieren (`sk-proj-...`) – er wird nur einmal angezeigt
4. Optional: Guthaben unter **Billing** aufladen ($5–10 reichen für Tausende Analysen)

### Einrichten in Hablará

1. Einstellungen öffnen (⚙️)
2. **LLM-Provider → OpenAI** wählen
3. Zustimmungs-Fenster bestätigen
4. API-Key eingeben
5. Modell auswählen (Empfehlung: `gpt-4o-mini`)
6. Speichern

### Modell-Auswahl

| Modell | Geschwindigkeit | Qualität | Kosten/Analyse | Empfehlung |
|--------|----------------|---------|---------------|-----------|
| `gpt-4o-mini` | ⚡⚡⚡ (0,3–1 s) | ⭐⭐⭐⭐ | ~$0,0002 | ✅ Standard |
| `gpt-4.1-nano` | ⚡⚡⚡ (0,3–1 s) | ⭐⭐⭐ | ~$0,0001 | Günstigste Option |
| `gpt-4.1-mini` | ⚡⚡ (0,5–2 s) | ⭐⭐⭐⭐⭐ | ~$0,0003 | Bestes Instruction-Following |

**Typische Kosten:** 1.000 Analysen mit `gpt-4o-mini` ≈ $0,20.

### Fehlerbehebung

| Problem | Lösung |
|---------|--------|
| „OpenAI API key not configured" | API-Key in den Einstellungen erneut eingeben und speichern |
| HTTP 429 (Rate Limit) | 60 s warten; bei dauerhaftem Limit: Tier upgraden |
| Langsame Antworten (>3 s) | Zu `gpt-4o-mini` oder `gpt-4.1-nano` wechseln oder temporär Ollama nutzen |

---

## Option B: Anthropic

### Account und API-Key

1. Account unter [console.anthropic.com](https://console.anthropic.com/) erstellen
2. Login → **Settings → API Keys** → „Create Key"
3. Key kopieren (`sk-ant-api...`)
4. Credits aufladen ($10–20 empfohlen für den Start)

### Einrichten in Hablará

1. Einstellungen öffnen (⚙️)
2. **LLM-Provider → Anthropic** wählen
3. Zustimmungs-Fenster bestätigen
4. API-Key eingeben
5. Modell auswählen (Empfehlung: `claude-3-5-haiku-20241022`)
6. Speichern

### Modell-Auswahl

| Modell | Geschwindigkeit | Qualität | Kosten/Analyse | Empfehlung |
|--------|----------------|---------|---------------|-----------|
| `claude-3-5-haiku-20241022` | ⚡⚡⚡ (0,3–1 s) | ⭐⭐⭐⭐ | ~$0,0003 | ✅ Budget |
| `claude-sonnet-4-20250514` | ⚡⚡ (0,5–2 s) | ⭐⭐⭐⭐⭐ | ~$0,0024 | Beste Balance |
| `claude-opus-4-20250514` | ⚡ (1–3 s) | ⭐⭐⭐⭐⭐ | ~$0,012 | Höchste Qualität |

**Besonderheit:** Claude-Modelle erkennen implizite Emotionen und Nuancen besonders
gut, insbesondere bei komplexen deutschen Sätzen.

**Typische Kosten:** 1.000 Analysen mit `claude-3-5-haiku-20241022` ≈ $0,30.

### Fehlerbehebung

| Problem | Lösung |
|---------|--------|
| „Anthropic API key not configured" | API-Key erneut eingeben und speichern |
| HTTP 429 (Rate Limit) | 60 s warten; mehr Credits kaufen |
| Hohe Kosten | Zu `claude-3-5-haiku-20241022` oder `gpt-4o-mini` wechseln |

---

## Option C: Mistral (EU)

Mistral AI verarbeitet in Paris. Für wen Cloud-Geschwindigkeit nötig ist, aber eine
Übertragung in die USA nicht in Frage kommt, ist das die naheliegende Wahl: keine
Standardvertragsklauseln, kein Drittlandtransfer.

### Account und API-Key

1. Account unter [console.mistral.ai](https://console.mistral.ai/) erstellen
2. Login → **API Keys** → „Create new key"
3. Key kopieren – er wird nur einmal angezeigt
4. Guthaben aufladen (Billing); für Tausende Analysen genügen wenige Euro

### Einrichten in Hablará

1. Einstellungen öffnen (⚙️)
2. **LLM-Provider → Mistral** wählen
3. Zustimmungs-Fenster bestätigen
4. API-Key eingeben
5. Modell auswählen (Empfehlung: `mistral-small-latest`)
6. Speichern

### Modell-Auswahl

| Modell | Geschwindigkeit | Qualität | Empfehlung |
|--------|----------------|---------|-----------|
| `mistral-small-latest` | ⚡⚡⚡ (0,5–2 s) | ⭐⭐⭐⭐ | ✅ Standard |
| `mistral-large-latest` | ⚡⚡ (1–3 s) | ⭐⭐⭐⭐⭐ | Höchste Qualität |

### Fehlerbehebung

| Problem | Lösung |
|---------|--------|
| „Mistral API key not configured" | API-Key in den Einstellungen erneut eingeben und speichern |
| HTTP 429 (Rate Limit) | 60 s warten; bei dauerhaftem Limit Guthaben oder Tier prüfen |
| Langsame Antworten (>3 s) | Zu `mistral-small-latest` wechseln oder temporär Ollama nutzen |

---

## Provider-Vergleich

| | Ollama | OpenAI `gpt-4o-mini` | Anthropic `claude-3-5-haiku-20241022` | Mistral `mistral-small-latest` |
|---|--------|---------------------|------------------------------|------------------------------|
| **Kosten/1.000 Analysen** | $0 | ~$0,20 | ~$0,30 | ~$0,10 |
| **Geschwindigkeit** | 2–4 s | 0,3–1 s | 0,3–1 s | 0,5–2 s |
| **Datenschutz** | ✅ Lokal | ⚠️ Cloud (USA) | ⚠️ Cloud (USA) | ⚠️ Cloud (EU, Paris) |
| **Qualität** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Offline-Fähigkeit** | ✅ | ❌ | ❌ | ❌ |
| **Setup** | Modell-Download | API-Key | API-Key | API-Key |

Die Kosten für Mistral sind aus den Listenpreisen der Konsole gerechnet (Stand September 2026), nicht aus einer eigenen Abrechnung.

---

## Zustimmung widerrufen

1. Einstellungen öffnen → LLM-Provider → **Ollama** wählen
2. Hablará verarbeitet ab sofort wieder vollständig lokal

Die gespeicherte Zustimmung bleibt erhalten, sodass ein späterer Wechsel ohne
erneutes Zustimmungs-Fenster möglich ist.

---

Weitere Informationen:
[Datenschutz](../legal/PRIVACY.md) · [Ollama Setup](./OLLAMA_SETUP.md) · [Features](../guides/FEATURES.md)
