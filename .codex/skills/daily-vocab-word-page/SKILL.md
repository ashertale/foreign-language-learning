---
name: daily-vocab-word-page
description: Prepare semantic JSON payloads or render/refine single-word foreign-language learning pages using the repo's quiet reading UI, concept-first prose, collocations with register, source notes, etymology, usage scenes, and neighbor-word distinctions. Use when Codex is asked to gather content for a new word page, create/refine one deep vocabulary page, or batch-render existing payload JSON.
---

# Daily Vocab Word Page

Use this project skill for one deep vocabulary word in this repo, or for a batch of independent one-word pages generated through the same content model. The target experience is a quiet, literary, paper-like learning page, not a landing page and not a slot-filled worksheet.

Default to Payload Mode: prepare one reusable JSON payload shaped like the semantic `page` model in [references/payload-shape.md](references/payload-shape.md). Only render files, update `prototypes/word-index.js`, run sync scripts, or browser-verify when the user explicitly asks to generate, create, render, or modify page files.

## Mode Selection

- Use Payload Mode for requests like "prepare content", "new word data", "JSON", or when the user wants to review the content before creating files.
- Use Render Mode when the user provides or references a payload and asks to create the final HTML page or add the word to the library.
- Use Render Mode when the user asks to "generate", "create", "新增", or "建立" one or more new word pages, even if no headword or payload is provided.
- Use UI refinement mode only when the request changes layout, CSS, interaction, responsive behavior, or single-word page structure.

## Source Policy

- Keep source selection on a fixed baseline. Do not pick different dictionaries ad hoc for each new word.
- Dictionary and pronunciation priority: `Cambridge Dictionary` first, `Merriam-Webster` second, then `Oxford Learner's Dictionaries` or `Britannica Dictionary` as tertiary fallback when the higher-priority source is missing, unclear, or insufficient.
- Etymology and history priority: `Online Etymology Dictionary` first, `Merriam-Webster` second.
- Modern/common-usage priority: `Merriam-Webster` first, `Cambridge Dictionary` second, `Britannica Dictionary` third.
- Level/frequency policy: Zipf comes from `wordfreq`; CEFR is a repo-calibrated study band, not a per-word external CEFR feed. Record this in `sourceAudit` as `wordfreq Zipf + repo CEFR calibration`.
- Keep `page.sources.dictionary`, `page.sources.modern`, and `sourceAudit` aligned to the actual selected source. Do not mix a Cambridge label with a Merriam URL, or vice versa.
- For source-policy cleanup across existing payload/page pairs, run `uv run python scripts/normalize_word_sources.py --check` first. Run it without `--check` only when intentionally normalizing both JSON payloads and rendered HTML pages.
- `scripts/generate_batch_word_pages.py` no longer writes learner-facing prose from TSV fields. Treat it as a batch validator/renderer for complete LLM-authored payload JSON files.

## Payload Mode

1. Confirm the target word(s), learner language, and any source expectations. If the user asks for N new words without naming them, read `prototypes/word-index.js` first and choose N non-duplicate, practical, concept-rich words.
2. Read [references/payload-shape.md](references/payload-shape.md). Treat it as a data-shape reference, not a prose template. Do not write `templatePlaceholders`.
3. Fill the payload around meaning-bearing sections: `page.hero`, `page.coreIdea`, `page.definition`, optional `page.origin`, `page.memory`, flexible `page.usage`, flexible `page.collocations.items`, `page.neighbors`, `page.modernUse`, and `page.sources`.
4. Format `page.pronunciation` as `ih-FEM-er-uhl · UK /.../ · US /.../`. Do not include the literal labels `Respelling`, `UK IPA`, or `US IPA`.
5. Prefer plain text values with light inline HTML such as `<code>` only where the learning object benefits from it.
6. Keep prose concept-first and reading-oriented. Do not write study-script lines such as `先讀搭配`, `如果你只能想起中文`, `最低摩擦入口`, or `這時重點是精準`.
7. Let the word decide the emphasis. `usage`, `collocations.items`, `neighbors.others`, and `modernUse` are containers, not quotas.
8. Fill `indexEntry` so it can later be copied into `prototypes/word-index.js`: `id`, `word`, `partOfSpeech`, `href`, `thesis`, `tags`, and `checks`.
9. Set `target.outputPath` to `prototypes/<word-slug>.html`. Persist reusable payload files under `data/word-payloads/<word-slug>.json` only when the user asks to save them.
10. Return the JSON payload plus at most a short note about unresolved assumptions. Do not edit files, run sync scripts, start a server, or parse existing word page HTML in this mode.

## Render Mode

1. If no payload is provided, read `prototypes/word-index.js`, choose non-duplicate word(s), then create payload file(s) under `data/word-payloads/<word-slug>.json` so rendering has an auditable input.
2. Use the repo script `uv run python scripts/render_word_page.py <payload.json>` for normal rendering. The renderer now builds HTML from semantic payload sections rather than an external prose template.
3. Before writing files, run `uv run python scripts/render_word_page.py <payload.json> --dry-run` to validate payload structure, slug, output path, duplicate `id`/`href`, and `indexEntry`.
4. New word pages live at `prototypes/<word-slug>.html`. The render script should stop instead of overwriting an existing page.
5. For a formal new word page, always add the payload's `indexEntry` to `prototypes/word-index.js`.
6. Keep shared UI in `prototypes/word-page.css` and shared interaction in `prototypes/word-page.js`; do not inline CSS/JS unless explicitly asked.
7. Run `uv run python scripts/sync_word_numbers.py` after rendering so `Word NN` and `word-index.js` stay contiguous.
8. After editing a word page or index, run `uv run python scripts/sync_word_numbers.py --check`.
9. After rendering or batch-editing payload/page pairs, run `uv run python scripts/validate_word_pages.py` to catch payload/page drift, old IPA labels, missing CEFR/Zipf metadata, and source-policy drift.
10. When you normalize legacy payloads or adjust source choices, update the corresponding rendered page too; do not stop at the JSON payload alone.

## Batch Spec Contract

Use a batch only when all of these are true:

- The user asks for multiple brand-new word pages, not a single payload or a UI change.
- The batch follows one shared content model, one page per word.
- The page copy is authored per word by LLM mode, then saved as complete payload JSON.

Keep batch inputs lightweight:

- Prefer complete payload JSON files under `data/word-payloads/*.json`.
- If a manifest is useful, store it under `data/word-batches/*.tsv` and include only a `payload` column that points to payload JSON files.
- Treat `scripts/generate_batch_word_pages.py` as the execution source of truth.

When asking LLM mode to create payloads:

- Teach the concept, tone, register, usage boundary, and memory handle that fit this specific word.
- Let the word decide the emphasis; do not force every page to spend equal weight on the same subsection count.
- Use collocations as usage anchors and neighbors as confusion boundaries.
- Keep source notes factual and mnemonic images clearly separate from history.
- The final artifact still has to be a valid payload JSON because the renderer and validators need semantic structure, but that structure is not a prose template.

You can print the local guidance with:

```powershell
uv run python scripts\generate_batch_word_pages.py --print-llm-guidance
```

Render a directory of complete payloads:

```powershell
uv run python scripts\generate_batch_word_pages.py data\word-payloads
```

Or render a manifest that only lists payload paths:

```tsv
payload
data/word-payloads/abstain.json
```

## UI Refinement Mode

- Read `references/content-model.md` before changing the content sequence.
- Read `references/ui-ux-pattern.md` before changing layout, CSS, interaction, responsive behavior, sticky navigation, or pronunciation controls.
- Preserve the calm paper reading feel: low-contrast ink, warm off-white surfaces, muted sage/blue accents, 8px or smaller radius, fine borders, restrained shadows.
- Keep the topbar minimal. Brand text links to page top; keep only a small `單字庫` link back to `index.html`.
- Use the left Reading Path for section anchors and set scroll offset so sticky UI does not cover headings.
- Do not add decorative blobs, oversized toolbars, marketing copy, nested cards, or multiple competing navigation systems.
- Keep text legible and uncrowded on mobile.

## Content Rules

- Teach concept, tone, and use, not just translation.
- Separate collocations from neighbor-word distinctions. Collocations answer "what words naturally pair with this word?" Neighbor distinctions answer "what similar words should not be confused with it?"
- Keep `indexEntry.checks` concise and useful because the separate review page still uses them.
- Do not force the headword into every paragraph. Use it when it clarifies the concept, but let scenes and collocations carry the explanation when they do the job better.
- Keep hero metadata compact: respelling plus `UK /.../` and `US /.../`, then CEFR and Zipf frequency in the hero aside.
- If you do not have real origin information, omit `page.origin` instead of filling the section with meta guidance or mnemonic-only prose.
- Source notes should be transparent but unobtrusive.
- Treat memory hooks as learning aids, not historical claims.
