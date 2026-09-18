# rusty_foundationmodels 0.2.0 — modified for Hablará

This directory is the Source Code Form of `rusty_foundationmodels` as shipped in Hablará,
published to meet Section 3.2(a) of the Mozilla Public License 2.0 (see `LICENSE`).

- **Upstream:** https://crates.io/crates/rusty_foundationmodels/0.2.0
  (repository https://github.com/undivisible/rusty_foundationmodels, archived)
- **License:** MPL-2.0, unchanged. Only the files below differ from upstream; all other
  files are the published 0.2.0 sources.
- **First shipped in:** the Hablará release after 1.7.7 (macOS, Apple Silicon)

## Modifications

Fixed value sets for string properties in structured output:

| File | Change |
|------|--------|
| `src/lib.rs` | `SchemaProperty` gets an optional `choices: Option<Vec<String>>` field and a `choices()` builder; it is serialised as `choices` when set. |
| `bridge.swift` | `SchemaPropertyDesc` decodes `choices`; a string property with choices is built as `DynamicGenerationSchema(name:anyOf:)`, so the model can only produce one of these values. |

Changed lines are marked with `Hablará patch`.
