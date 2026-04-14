# Hilfe erhalten

## Dokumentation

Bevor Sie ein Issue öffnen, prüfen Sie bitte:

- **[README.md](../README.md)** - Übersicht & Navigation
- **[FAQ](../guides/FAQ.md)** - Häufige Fragen & Lösungen
- **[Guides](../guides/)** - Anleitungen (Recording, Linux, Storage, Features)
- **[Reference](../reference/)** - Hotkeys, LLM-Provider, Modell-Kompatibilität

## Community

- **[GitHub Discussions](https://github.com/fidpa/hablara-releases/discussions)** - Fragen stellen, Ideen teilen
- **[Issue Tracker](https://github.com/fidpa/hablara-releases/issues)** - Fehler melden, Features anfragen

## Bevor Sie ein Issue öffnen

1. **Bestehende Issues durchsuchen** - Ihre Frage wurde möglicherweise bereits beantwortet
2. **Dokumentation lesen** - Prüfen Sie die [Guides](../guides/) zu Ihrem Thema
3. **Details angeben** - Nutzen Sie Issue-Vorlagen (Umgebung, Reproduktionsschritte, Logs)

## Wie Sie Hilfe erhalten

### Fragen & Diskussionen

Nutzen Sie [GitHub Discussions](https://github.com/fidpa/hablara-releases/discussions) für:
- "Wie mache ich...?"-Fragen
- Feature-Ideen
- Allgemeines Feedback

### Fehlerberichte

Nutzen Sie den [Issue Tracker](https://github.com/fidpa/hablara-releases/issues/new?template=bug_report.md) für:
- Unerwartetes Verhalten
- Abstürze oder Fehler
- Performance-Probleme

**Bitte angeben:**
- Hablará-Version
- macOS-Version (Chip: M-Series vs Intel)
- Schritte zur Reproduktion
- Logs (Developer Tools Console: Cmd+Shift+I, Terminal-Ausgabe)

### Feature-Anfragen

Nutzen Sie den [Issue Tracker](https://github.com/fidpa/hablara-releases/issues/new?template=feature_request.md) für:
- Neue Features
- Verbesserungen bestehender Features

## Sicherheitsprobleme

Erstellen Sie **KEINE** öffentlichen Issues für Sicherheitslücken.

Siehe [SECURITY.md](./SECURITY.md) für den Prozess zur verantwortungsvollen Offenlegung.

## Antwortzeiten

Dies ist ein Challenge-Projekt mit begrenzten Ressourcen:
- **Issues:** Antwort innerhalb von 1-3 Tagen
- **PRs:** Review innerhalb von 1-3 Tagen
- **Sicherheit:** Bestätigung innerhalb von 48 Stunden (siehe [SECURITY.md](./SECURITY.md))

## Häufige Probleme

### Audio-Aufnahmeprobleme
- **Mikrofon nicht erkannt:** Prüfen Sie Systemeinstellungen → Datenschutz & Sicherheit → Mikrofon
- **Kein Audio-Pegel:** App neu starten

### Transkriptionsprobleme
- **Modell nicht gefunden:** Stellen Sie sicher, dass das Whisper-Modell heruntergeladen ist
- **MLX-Whisper schlägt fehl:** Normal, falls nicht konfiguriert - whisper.cpp ist der Standard

### LLM-Integrationsprobleme
- **Ollama antwortet nicht:** Prüfen Sie mit `ollama list`, ob Modelle angezeigt werden
- **OpenAI/Anthropic-Fehler:** API-Schlüssel in den App-Einstellungen prüfen (Einstellungen → KI-Modelle; gesichert im OS-Schlüsselbund)

---

Vielen Dank, dass Sie Hablará nutzen!

---

**Version:** 1.1.0
