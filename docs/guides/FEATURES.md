# KI-Anreicherungen – Was Hablará aus deiner Sprache macht

Hablará macht mehr als transkribieren: Es analysiert dein Sprechmuster in Echtzeit
und liefert psychologisch-informierten Output – lokal auf deinem Gerät.

---

## 1. Emotionsanalyse

### Dual-Track-Methode

Hablará kombiniert zwei unabhängige Analysepfade:

| Track | Gewichtung | Datenquelle | Stärke |
|-------|-----------|-------------|--------|
| **Audio-Track** | 40 % | Pitch, Energie, Sprechtempo, Pausen | Prosodische Nuancen |
| **Text-Track** | 60 % | Transkript → LLM-Analyse | Semantische Präzision |

Das Ergebnis ist eine **fusionierte Emotion** – z.B. primär *Aufregung* (Text) mit
sekundärer *Anspannung* (Audio), wenn die Stimme zittrig klingt, die Worte aber
begeistert sind. Typische Genauigkeit: ~85 %.

### Die 10 erkannten Emotionstypen

| Emotion | Typische Signale | Plutchik-Grundlage |
|---------|-----------------|-------------------|
| **Neutral** | Keine Auffälligkeiten | – |
| **Ruhig** | Tiefe Stimme, langsames Tempo | Joy (Serenity) |
| **Freude** | Mittlere Energie, Hochstimmung | Joy |
| **Aufregung** | Hohe Energie, schnelles Tempo | Anticipation (hoch) |
| **Überzeugung** | Stabile Energie, klare Aussprache | Trust + Anticipation |
| **Unsicherheit** | Variable Tonhöhe, lange Pausen | Fear + Surprise |
| **Zweifel** | Fragend, langsam, niedrige Energie | Sadness + Fear |
| **Frustration** | Abrupte Pausen, mittelhohe Energie | Anger (niedrig) |
| **Stress** | Hohe Energie, hohe Tonhöhe, schnell | Fear (hoch) |
| **Aggression** | Sehr hohe Energie, tiefe Stimme | Anger (Rage) |

**Theoretischer Rahmen:**
- **Plutchik's Wheel of Emotions** (1980) – 8 Basis-Emotionen mit Intensitätsstufen
- **Russell's Circumplex Model** (1980) – Valenz/Aktivierung als 2D-Raum

### Konfidenz-Werte verstehen

| Bereich | Bedeutung |
|---------|-----------|
| 0–40 % | Sehr unsicher – mit Vorsicht interpretieren |
| 40–60 % | Plausibel, aber unsicher |
| 60–80 % | Wahrscheinlich korrekt |
| 80–100 % | Sehr zuverlässig |

Hohe Konfidenz entsteht, wenn Audio und Text dieselbe Emotion signalisieren.

> **Hinweis:** Die Emotionsanalyse ist ein Reflexionswerkzeug zur Selbstwahrnehmung –
> kein klinisches Diagnoseinstrument und kein Therapieersatz.

---

## 2. Fehlschluss-Erkennung

Hablará erkennt argumentative Muster, die häufig zu Missverständnissen oder
unproduktivenGesprächen führen – in Diskussionen, Meetings oder beim eigenen Denken.

### Die 16 erkannten Fehlschlüsse

Hablará erkennt 16 Fehlschluss-Typen in zwei Stufen:

**Tier 1 – 6 Kern-Fehlschlüsse** (besonders häufig, hohe Erkennungsrate)

| Typ | Name | Beschreibung | Beispiel |
|-----|------|-------------|---------|
| `ad_hominem` | Ad Hominem | Angriff auf die Person statt das Argument | „Von dir kommt nichts Gutes." |
| `straw_man` | Strohmann | Argument des anderen verzerrt darstellen | „Du willst also gar keine Regeln." |
| `false_dichotomy` | Falsche Dichotomie | Nur zwei Optionen, obwohl mehr existieren | „Entweder bist du für uns oder gegen uns." |
| `appeal_authority` | Autoritätsargument | Aussage allein durch Verweis auf Autorität stützen | „Das sagen alle Experten." |
| `circular_reasoning` | Zirkelschluss | Schlussfolgerung ist gleichzeitig Prämisse | „Das stimmt, weil es so ist." |
| `slippery_slope` | Dammbruchargument | Kausalkette ohne Belege | „Wenn wir das erlauben, endet alles im Chaos." |

**Tier 2 – 10 weitere Typen** (hohe Sprach-Relevanz)

| Typ | Name | Beschreibung |
|-----|------|-------------|
| `red_herring` | Ablenkungsmanöver | Ablenkung vom eigentlichen Thema |
| `tu_quoque` | Tu Quoque | Hypocrisy als Gegenargument („Du doch auch") |
| `hasty_generalization` | Übergeneralisierung | Generalisierung aus unzureichender Stichprobe |
| `post_hoc` | Post Hoc | Zeitliche Abfolge wird als Kausalität fehlgedeutet |
| `bandwagon` | Mitläufereffekt | „Alle machen es, also ist es richtig" |
| `appeal_emotion` | Appell an Gefühle | Emotionale Manipulation statt logischer Argumente |
| `appeal_ignorance` | Appell an Unwissenheit | „Nicht bewiesen falsch" wird als wahr gewertet |
| `loaded_question` | Suggestivfrage | Frage mit kontroversen Vorannahmen |
| `no_true_scotsman` | Kein wahrer Schotte | Ad-hoc-Neudefinition zum Ausschluss von Gegenbeispielen |
| `false_cause` | Falsche Kausalität | Korrelation wird als Ursache fehlgedeutet |

**Klassifikation:** Alle 16 sind informale Fehlschlüsse gemäß Stanford Encyclopedia
of Philosophy (Fallacies of Relevance, Weak Induction und Presumption).

Erkannte Fehlschlüsse werden im Transkript **farblich hervorgehoben** und mit einer
Erklärung sowie einem Umformulierungsvorschlag versehen.

---

## 3. Psychologische Anreicherungen

### Gewaltfreie Kommunikation (GFK nach Rosenberg)

Analysiert das Transkript auf die vier GFK-Komponenten:

**Beobachtung → Gefühl → Bedürfnis → Bitte**

Hilfreich beim Erkennen, welche Sprache Verbindung fördert und welche sie unterbricht.

### Kognitive Verzerrungen (nach Beck)

Erkennt häufige Denkmuster aus der Kognitiven Verhaltenstherapie, darunter:

| Muster | Beispiel |
|--------|---------|
| Katastrophisieren | „Das geht garantiert schief." |
| Schwarz-Weiß-Denken | „Entweder perfekt oder wertlos." |
| Personalisieren | „Das ist alles meine Schuld." |
| Verallgemeinern | „Das klappt bei mir nie." |

> *Hablará benennt diese Muster zur Selbstreflexion – keine therapeutische Funktion.*

### Vier-Seiten-Modell (nach Schulz von Thun)

Analysiert Aussagen auf vier Ebenen:

| Seite | Was wird übermittelt? |
|-------|-----------------------|
| **Sachinhalt** | Reine Fachinformation |
| **Selbstoffenbarung** | Was der Sprecher über sich verrät |
| **Beziehung** | Wie der Sprecher zum Hörer steht |
| **Appell** | Was der Sprecher vom Hörer erwartet |

### Transaktionsanalyse (nach Eric Berne)

Zeigt, aus welchem Ich-Zustand heraus gesprochen wird:

| Ich-Zustand | Merkmale |
|-------------|---------|
| **Eltern-Ich (kritisch)** | Bewertend, fordernd, regelorientiert |
| **Eltern-Ich (fürsorglich)** | Schützend, unterstützend, anleitend |
| **Erwachsenen-Ich** | Sachlich, lösungsorientiert, offen |
| **Kind-Ich (frei)** | Spontan, kreativ, emotional |
| **Kind-Ich (angepasst)** | Gehorsam, zurückhaltend, konfliktscheu |

Zusätzlich erkennt Hablará den Transaktionstyp: **Komplementär** (reibungslose Kommunikation), **Überkreuz** (Missverständnis-Potenzial) oder **Verdeckt** (versteckte Botschaft).

> *Zur Selbstreflexion — kein therapeutisches Werkzeug.*

### Themenklassifikation

Jede Aufnahme wird einer von 7 Kategorien zugeordnet:
Arbeit, Beziehungen, Gesundheit, Finanzen, Persönliches, Lernen, Sonstiges.

---

## 4. Transkriptions-Provider

Hablará unterstützt vier Transkriptions-Engines, die in den Einstellungen gewählt werden können:

| Provider | Modus | Geschwindigkeit | Kosten | Empfehlung |
|----------|-------|----------------|--------|-----------|
| **whisper.cpp** | Lokal | ~1 s | Kostenlos | ✅ Standard (german-turbo) |
| **MLX-Whisper** | Lokal | ~1 s | Kostenlos | Apple Silicon (M1/M2/M3/M4) |
| **OpenAI Whisper-1** | Cloud | 1–3 s | $0,006/min | Zuverlässig, bewährt |
| **GPT-4o Mini Transcribe** | Cloud | 1–3 s | $0,003/min | Günstiger Cloud-Einstieg |

**Lokale Provider (Standard):** Alle Audiodaten bleiben auf dem Gerät. Keine Internetverbindung erforderlich.

**Cloud-Provider (OpenAI):** Der Transkripttext wird an OpenAI gesendet. Erfordert einen OpenAI API-Key (Settings → KI-Modelle). Bei Cloud-Transkription zeigt Hablará ein separates GDPR-Zustimmungs-Fenster.

> **Hinweis:** MLX-Whisper ist nur auf macOS verfügbar und wird automatisch als Option angeboten,
> wenn Apple Silicon erkannt wird.

### Diktat-Modus: Interpunktion per Sprachbefehl

Im Diktat-Modus erkennt Hablará gesprochene Satzzeichen und ersetzt sie automatisch im Transkript.

**Deutsche Befehle:**

| Gesprochen | Ergebnis |
|-----------|---------|
| „Komma" | `,` |
| „Punkt" | `.` |
| „Fragezeichen" | `?` |
| „Ausrufezeichen" | `!` |
| „Doppelpunkt" | `:` |
| „Semikolon" | `;` |
| „Absatz" | neue Absatzzeile |

**Unterstützte Sprachen:** DE, EN, ES, FR, IT, NL, PT, PL, SV, DA, NO, RU

**Aktivieren:** Settings → Transkription → „Interpunktions-Befehle" einschalten.

---

## 5. Datenschutz

| Modus | Datenverarbeitung | Geeignet für |
|-------|------------------|-------------|
| **Lokal (Standard)** | Alles auf dem Gerät (Ollama + Whisper) | Datenschutzkritische Inhalte |
| **Cloud (OpenAI / Anthropic)** | Transkripte werden an externe Server übertragen | Wenn Geschwindigkeit Priorität hat |

Bei Cloud-Nutzung erfordert Hablará eine explizite Zustimmung (GDPR Art. 6).
Audio-Dateien verlassen das Gerät **niemals** – nur der Transkripttext wird übertragen.

Weitere Informationen:
[Datenschutz](../legal/PRIVACY.md) · [Cloud-Provider einrichten](../reference/LLM_PROVIDERS.md) · [Ollama einrichten](../reference/OLLAMA_SETUP.md)
