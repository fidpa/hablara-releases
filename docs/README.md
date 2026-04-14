# Hablará Documentation

End-user documentation for Hablará: guides, reference, and legal information.

---

## Quick Navigation

| I want to... | Document |
|---|---|
| Troubleshoot Linux | [guides/LINUX_TROUBLESHOOTING.md](./guides/LINUX_TROUBLESHOOTING.md) |
| Optimize recording quality | [guides/RECORDING_QUALITY.md](./guides/RECORDING_QUALITY.md) |
| Manage recordings | [guides/STORAGE.md](./guides/STORAGE.md) |
| Solve common problems | [guides/FAQ.md](./guides/FAQ.md) |
| Understand AI enrichments | [guides/FEATURES.md](./guides/FEATURES.md) |
| Annotate Ground Truth data | [guides/GROUND_TRUTH_ANNOTATION.md](./guides/GROUND_TRUTH_ANNOTATION.md) |
| Set up Ollama | [reference/OLLAMA_SETUP.md](./reference/OLLAMA_SETUP.md) |
| Set up OpenAI or Anthropic | [reference/LLM_PROVIDERS.md](./reference/LLM_PROVIDERS.md) |
| Configure hotkeys | [reference/HOTKEYS.md](./reference/HOTKEYS.md) |
| Check model–language compatibility | [reference/MODEL_COMPATIBILITY.md](./reference/MODEL_COMPATIBILITY.md) |
| Legal information | [legal/](./legal/) |

---

## Structure

```
docs/
├── guides/                # How-To guides
│   ├── RECORDING_QUALITY.md   # LED meter, microphone tips, speech ratio
│   ├── STORAGE.md             # Managing recordings, WAV export
│   ├── FAQ.md                 # 10 most common issues
│   ├── LINUX_TROUBLESHOOTING.md  # Ubuntu/Linux troubleshooting
│   ├── FEATURES.md            # AI enrichments: emotions, fallacies, psychology
│   └── GROUND_TRUTH_ANNOTATION.md  # Annotating recordings for model evaluation
├── reference/             # Reference documentation
│   ├── OLLAMA_SETUP.md        # Ollama setup scripts (CLI reference)
│   ├── LLM_PROVIDERS.md       # Cloud LLM setup: OpenAI & Anthropic
│   ├── HOTKEYS.md             # Keyboard shortcuts & configuration
│   └── MODEL_COMPATIBILITY.md # Model–language compatibility matrix (→ SSOT + website)
└── legal/                 # Privacy, licenses, support
    ├── PRIVACY.md
    ├── SECURITY.md
    ├── SUPPORT.md
    └── THIRD_PARTY_LICENSES.md
```

---

## Guides

- [Optimize Recording Quality](./guides/RECORDING_QUALITY.md) — LED meter, microphone settings, speech ratio
- [Manage Recordings](./guides/STORAGE.md) — Auto-save, recordings library, WAV export
- [FAQ](./guides/FAQ.md) — 10 most common issues and solutions
- [Linux Troubleshooting](./guides/LINUX_TROUBLESHOOTING.md) — Ubuntu 20.04+, .deb/.rpm, AppImage, audio, hotkeys
- [AI Features](./guides/FEATURES.md) — Emotion analysis, fallacy detection, GFK, cognitive distortions
- [Ground Truth Annotation](./guides/GROUND_TRUTH_ANNOTATION.md) — Annotating recordings for model evaluation

---

## Reference

- [Ollama Setup Scripts](./reference/OLLAMA_SETUP.md) — CLI reference for `--status`, `--diagnose`, `--cleanup`, model variants
- [Cloud LLM Providers](./reference/LLM_PROVIDERS.md) — OpenAI and Anthropic setup, model selection, GDPR
- [Hotkeys](./reference/HOTKEYS.md) — Customize keyboard shortcuts, avoid conflicts
- [Model–Language Compatibility](./reference/MODEL_COMPATIBILITY.md) — Which analyses work per model and language

---

## Legal

- [Privacy Policy](./legal/PRIVACY.md)
- [Security Policy](./legal/SECURITY.md)
- [Support & Contact](./legal/SUPPORT.md)
- [Third-Party Licenses](./legal/THIRD_PARTY_LICENSES.md)
