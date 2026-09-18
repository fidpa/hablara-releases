# Häufig gestellte Fragen (FAQ)

Schnelle Lösungen für die 16 häufigsten Probleme.

---

## 1. Ollama nicht verfügbar

**Symptom:** "LLM nicht verfügbar" oder "Ollama antwortet nicht"

**Lösung:**
```bash
# Ollama starten
ollama serve

# Model herunterladen
ollama pull qwen3:4b-thinking-2507-q4_K_M
```

> **Hinweis:** Das Setup-Skript von Hablará erstellt automatisch ein `qwen3:4b-custom` Modell
> mit optimierten Parametern (Temperature 0.3, reduzierter Kontext). Hablará nutzt intern
> `qwen3:4b-custom`, nicht das Basis-Modell. Wer das Skript nicht genutzt hat: einmal
> `setup-ollama-mac.sh` (macOS), `setup-ollama-linux.sh` (Linux) bzw. `setup-ollama-win.ps1`
> (Windows) ausführen, siehe [Ollama Setup](../reference/OLLAMA_SETUP.md).

**Alternative:** Cloud-LLM verwenden (Settings → KI-Modelle → OpenAI/Anthropic/Mistral)

---

## 2. Transkription fehlgeschlagen

**Symptom:** "0% Speech detected" oder leerer Transkript-Text

**Ursachen & Lösungen:**

| Ursache | Lösung |
|---------|--------|
| Zu leise gesprochen | Lauter sprechen, näher ans Mikrofon |
| Hintergrundgeräusche | Ruhige Umgebung wählen |
| Mikrofon-Permission fehlt | Systemeinstellungen → Datenschutz → Mikrofon |

**Prüfen:** LED-Meter sollte 4-6 grüne Segmente zeigen → [Aufnahme-Qualität optimieren](./RECORDING_QUALITY.md)

---

## 3. Hotkey reagiert nicht

**Symptom:** `Ctrl+Shift+D` löst nichts aus

**Lösungen:**

1. **Shortcut-Konflikt:** Anderes Programm belegt denselben Hotkey
   - **Prüfen:** Systemeinstellungen → Tastatur → Tastatur-Kurzbefehle
   - **Lösung:** Alternative wählen → [Hotkeys konfigurieren](../reference/HOTKEYS.md)

2. **Permission fehlt:** macOS Bedienungshilfen
   - **Prüfen:** Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen
   - **Lösung:** Hablará aktivieren

3. **Nur im Browser:** Tauri Dev Mode starten
   - **Lösung:** App richtig starten (nicht im Browser öffnen)

---

## 4. Aufnahmen werden nicht gespeichert

**Symptom:** Keine Dateien im Aufnahme-Ordner

**Speicherpfade (ab v1.0.4):**
- macOS (Direct): `~/Library/Application Support/Hablara/recordings/`
- macOS (App Store): `~/Documents/Hablara/recordings/`
- Linux: `~/.local/share/hablara/recordings/`
- Windows: `%LOCALAPPDATA%\Hablara\recordings\`

**Lösungen:**

1. **Auto-Save deaktiviert:**
   - Settings → Speicher → "Automatische Speicherung" aktivieren

2. **Ordner nicht erreichbar:**
   ```bash
   # macOS (Direct)
   mkdir -p ~/Library/Application\ Support/Hablara/recordings/

   # Linux
   mkdir -p ~/.local/share/hablara/recordings/
   ```

3. **Berechtigungen prüfen:**
   ```bash
   # macOS
   ls -la ~/Library/Application\ Support/Hablara/

   # Linux
   ls -la ~/.local/share/hablara/
   ```

**Details:** [Aufnahmen verwalten](./STORAGE.md)

---

## 5. Audio-Level zeigt 0

**Symptom:** LED-Meter bleibt auf 0, keine Balken

**Lösungen:**

| Ursache | Lösung |
|---------|--------|
| Mikrofon-Permission fehlt | Systemeinstellungen → Datenschutz → Mikrofon |
| Falsches Input-Device | Anderes Mikrofon in macOS wählen |
| Mikrofon-Lautstärke zu niedrig | Input-Level in Systemeinstellungen erhöhen |

**Test:** Andere App (z.B. QuickTime) → Aufnahme starten → funktioniert es dort?

---

## 6. LLM antwortet nicht

**Symptom:** Chat-Antwort bleibt aus oder "LLM-Fehler"

**Lösungen:**

1. **Ollama nicht gestartet:**
   ```bash
   ollama serve
   ```

2. **Model fehlt:**
   ```bash
   ollama pull qwen3:4b-thinking-2507-q4_K_M
   ```
   Danach Setup-Skript ausführen, damit `qwen3:4b-custom` erstellt wird
   (das ist das Modell, das Hablará tatsächlich nutzt).

3. **Cloud-LLM ohne API Key:**
   - Settings → KI-Modelle → API Key eingeben

4. **Offline (Cloud-Provider):**
   - Internetverbindung prüfen
   - Oder: Zu Ollama wechseln (offline-fähig)

---

## 7. Langsame Verarbeitung

**Symptom:** Transkription/Analyse dauert >10 Sekunden

**Optimierungen:**

| Problem | Lösung | Impact |
|---------|--------|--------|
| Cloud-LLM mit Netzwerk-Lag | Ollama lokal nutzen | -50% Latenz |
| Große Audio-Datei (>2 Min) | Kürzere Clips aufnehmen | -70% Zeit |
| Viele Analysen aktiviert | Unnötige Features deaktivieren | -30% Zeit |

**Settings optimieren:**
- Nur benötigte Analysen aktivieren (Emotion, GFK, etc.)
- MLX-Whisper nutzen (falls installiert) → schneller als whisper.cpp

---

## 8. PDF-Export wird blockiert

**Symptom:** "PDF-Export fehlgeschlagen" oder Browser-Download-Dialog öffnet sich nicht

**Ursachen:**

1. **Browser-Permission:** Download-Berechtigung fehlt
   - **Lösung:** Download in Browser erlauben

2. **Tauri File-Dialog Fehler:** Native Dialog schlägt fehl
   - **Lösung:** Anderer Speicherort (z.B. Desktop statt Network-Share)

**Alternative:** WAV-Export funktioniert immer → [Aufnahmen verwalten](./STORAGE.md)

---

## 9. App startet nicht

**Symptom:** Weißer Bildschirm oder "SyntaxError: Unexpected EOF"

**Lösungen:**

1. **Cache-Problem:**
   ```bash
   # macOS
   rm -rf ~/Library/WebKit/com.fidpa.hablara
   rm -rf ~/Library/Caches/com.fidpa.hablara
   ```

2. **Alte App-Version:**
   - Deinstallieren: `rm -rf /Applications/Hablara.app`
   - Neueste DMG von GitHub installieren

3. **macOS Gatekeeper:**
   - Rechtsklick auf App → "Öffnen"
   - Oder: Systemeinstellungen → Datenschutz → "Trotzdem öffnen"

---

## 10. Mikrofon-Berechtigung fehlt

**Symptom:** "Mikrofon-Zugriff verweigert" oder LED-Meter zeigt 0

**Lösung (macOS):**

1. **Systemeinstellungen** öffnen
2. **Datenschutz & Sicherheit** → **Mikrofon**
3. **Hablará** in der Liste aktivieren
4. **App neu starten**

**Berechtigung zurücksetzen:**
```bash
tccutil reset Microphone
```
(App erneut starten → Permission-Dialog erscheint)

---

## 11. Linux: AppImage startet nicht

**Symptom:** `./Hablara_*.AppImage` zeigt "FUSE error" oder startet nicht

**Lösungen:**

```bash
# 1. Ausführbar machen
chmod +x Hablara_*.AppImage

# 2. FUSE installieren (Ubuntu 22.04+)
sudo apt install libfuse2t64

# 3. Alternativ: Ohne FUSE extrahieren
./Hablara_*.AppImage --appimage-extract
./squashfs-root/AppRun
```

**Details:** [Linux Troubleshooting](./LINUX_TROUBLESHOOTING.md)

---

## 12. Linux: Hotkeys funktionieren nicht (Wayland)

**Symptom:** `Ctrl+Shift+D` löst keine Aufnahme aus

**Grund:** Wayland blockiert globale Hotkeys aus Sicherheitsgründen.

**Lösungen:**

1. **X11-Session verwenden (empfohlen):**
   - Beim Login: Zahnrad-Symbol → "Ubuntu on Xorg" wählen

2. **Session prüfen:**
   ```bash
   echo $XDG_SESSION_TYPE
   # wayland → Hotkeys nicht möglich
   # x11 → Hotkeys funktionieren
   ```

3. **Alternative:** Start-Button in der App verwenden

---

## 13. Windows SmartScreen Warnung

**Symptom:** "Windows hat Ihren PC geschützt" beim Installieren

**Grund:** Hablara ist neue Software ohne Code-Signing-Zertifikat. Windows SmartScreen baut Vertrauen über Download-Zahlen auf.

**Installation trotzdem sicher:**

1. **Klicke "Weitere Informationen"**
2. **Klicke "Trotzdem ausführen"**

**Ist Hablara sicher?**

✅ **Open Source** - Kompletter Code auf GitHub einsehbar
✅ **Keine Malware** - Code kann von jedem überprüft werden
✅ **Privacy-First** - Lokale Verarbeitung, keine Telemetrie
✅ **Aktiv entwickelt** - Regelmäßige Updates, Community-Support

**Warum keine Code-Signatur?**

Code-Signing-Zertifikate kosten $300-400/Jahr. Für ein junges Open-Source-Projekt ist das nicht wirtschaftlich. Die SmartScreen-Warnung verschwindet automatisch nach ~500-2.000 Downloads, wenn Windows Vertrauen aufbaut.

**Alternative: Microsoft Store**

Falls verfügbar: Die Store-Version ist von Microsoft signiert und zeigt keine Warnung.

**Vertrauen verifizieren:**

```powershell
# SHA256-Hash prüfen (Windows PowerShell)
Get-FileHash Hablara_*_x64-setup.exe -Algorithm SHA256

# Mit GitHub Release-Hash vergleichen
# https://github.com/fidpa/hablara-releases/releases
```

---

## 14. Interpunktion per Sprache einfügen (Diktat-Modus)

**Frage:** Kann ich Satzzeichen beim Diktieren sprechen?

**Ja.** Aktiviere in Settings → Transkription → „Interpunktions-Befehle". Danach kannst du
Befehle wie „Komma", „Punkt", „Absatz" oder „Fragezeichen" sprechen — sie werden automatisch
in das entsprechende Zeichen umgewandelt.

**Unterstützte Sprachen:** DE, EN, ES, FR, IT, NL, PT, PL, SV, DA, NO, RU

**Details:** [Features – Diktat-Modus](./FEATURES.md#diktat-modus-interpunktion-per-sprachbefehl)

---

## 15. Eine Analyse wurde übersprungen

**Symptom:** Im Ergebnis steht bei einer Analyse „Übersprungen" mit einer kurzen Begründung,
etwa „Zu wenig Text" oder „Keine Argumente erkennbar", statt eines Ergebnisses.

**Ursache:** Der Analyse-Wächter (Pro) hat entschieden, dass der Text für diese Analyse
nichts hergibt. Das ist kein Fehler: Eine Terminnotiz enthält keinen Konflikt, eine
Einkaufsliste kein Argument. Übersprungen wird in zwei Fällen:

- Der Text hat weniger als 10 Wörter, die Aufnahme besteht überwiegend aus Stille, oder die
  gesprochene Sprache passt nicht zur eingestellten.
- Bei mehreren gleichzeitig aktiven Analysen fragt ein kleines Modell zusätzlich, ob der Text
  zur jeweiligen Analyse passt.

**Lösung:**

| Ziel | Vorgehen |
|---|---|
| Analyse trotzdem erzwingen | Einstellungen → Analyse → „Analyse-Wächter" auf **Deaktiviert** |
| Mehr Substanz liefern | Länger und zusammenhängend sprechen; sehr kurze Aufnahmen tragen wenige Analysen |
| Sprache prüfen | Einstellungen → Transkription: eingestellte Sprache muss zur gesprochenen passen |

Ton und Thema werden nie übersprungen. Fehlt das kleine Prüfmodell oder antwortet es nicht,
laufen alle Analysen wie ohne Wächter.

**Details:** [Features – Übersprungene Analysen](./FEATURES.md#übersprungene-analysen-analyse-wächter-pro)

---

## 16. Hinweis „nur etwa … % Treffer" an einer Analyse

**Symptom:** In den Einstellungen trägt eine Analyse den Hinweis, das gewählte Modell treffe
in dieser Analyse nur etwa einen bestimmten Prozentsatz.

**Ursache:** Der Hinweis stammt aus einer Messung mit 10 Testtexten je Sprache und
20 Durchläufen. Er bedeutet: Das Modell antwortet zuverlässig in der richtigen Form, wählt
aber oft die falsche Kategorie. Betroffen ist heute nur das kleinste Modell
`qwen2.5:1.5b-custom`, dort bei der Fehlschluss-Erkennung (etwa 21 %) und der Transaktionsanalyse (etwa 46 %).

**Lösung:**

| Situation | Vorgehen |
|---|---|
| Hardware trägt mehr | Einstellungen → KI-Modelle → größeres Modell wählen (`qwen3:4b-custom` ist der Standard) |
| Hardware trägt nicht mehr | Analyse ausgeschaltet lassen oder die Ergebnisse als groben Anhaltspunkt lesen |
| Höchste Genauigkeit nötig | Cloud-Anbieter einrichten → [Cloud-Provider](../reference/LLM_PROVIDERS.md) |

Der Hinweis ist keine Sperre: Die Analyse läuft, die Entscheidung bleibt bei dir.

**Details:** [Modell-Sprachkompatibilität](../reference/MODEL_COMPATIBILITY.md)

---

## Weitere Hilfe

**Kontakt:** Siehe [Support & Kontakt](../legal/SUPPORT.md)

**Fehler melden:** [GitHub Issues](https://github.com/fidpa/hablara-releases/issues)

---

## Siehe auch

- [Aufnahme-Qualität optimieren](./RECORDING_QUALITY.md) - LED-Meter, Speech Ratio
- [Aufnahmen verwalten](./STORAGE.md) - Storage, Export
- [Hotkeys konfigurieren](../reference/HOTKEYS.md) - Tastenkürzel anpassen
- [Modell-Sprachkompatibilität](../reference/MODEL_COMPATIBILITY.md) - Sperren, Latenz- und Genauigkeitshinweise
- [KI-Anreicherungen](./FEATURES.md) - Analysen im Überblick, Analyse-Wächter


