---
name: daily-vocab-word-page
description: Prepare template-ready JSON payloads or create/refine single-word foreign-language learning pages using the repo's word-page-template.html, quiet literary UI, reading-focused content model, active recall, collocations with register, source notes, etymology, usage scenarios, and neighbor-word distinctions. Use when Codex is asked to gather content for a new word page, fill the word-page template, or polish one deep vocabulary page.
---

# Daily Vocab Word Page

Use this project skill for one deep vocabulary word in this repo. The target experience is a quiet, literary, paper-like learning page, not a landing page and not a multi-word dashboard.

Default to Payload Mode: collect the content that fits the skill directory's `assets/template/word-page-template.html` and return a reusable JSON object. Only render files, update `prototypes/word-index.js`, run sync scripts, or browser-verify when the user explicitly asks to render, generate, create, or modify page files.

## Mode Selection

- Use Payload Mode for requests like "prepare content", "new word data", "fill the template", "JSON", or when the user wants to avoid repeated page-generation context.
- Use Render Mode when the user provides or references a payload and asks to create the final HTML page or add the word to the library.
- Use Render Mode when the user asks to "generate", "create", "新增", or "建立" one or more new word pages, even if no headword or payload is provided.
- Use UI refinement mode only when the request changes layout, CSS, interaction, responsive behavior, pronunciation controls, or active-recall behavior.

## Source Policy

- Keep source selection on a fixed baseline. Do not pick different dictionaries ad hoc for each new word.
- Dictionary and pronunciation priority: `Cambridge Dictionary` first, `Merriam-Webster` second, then `Oxford Learner's Dictionaries` or `Britannica Dictionary` as tertiary fallback when the higher-priority source is missing, unclear, or does not provide the needed signal.
- Etymology and history priority: `Online Etymology Dictionary` first, `Merriam-Webster` second.
- Modern/common-usage priority: `Merriam-Webster` first, `Cambridge Dictionary` second, `Britannica Dictionary` third.
- Level/frequency policy: Zipf comes from `wordfreq`; CEFR is a repo-calibrated study band, not a per-word external CEFR feed. Record this in `sourceAudit` as `wordfreq Zipf + repo CEFR calibration`.
- `REFERENCE_LABEL` and `REFERENCE_URL` must mirror the selected dictionary/pronunciation source. Do not point the page reference box at a different site than the dictionary source card.
- Keep `templatePlaceholders.*SOURCE*`, `REFERENCE_*`, and `sourceAudit` aligned to the actual selected source. Do not mix a Cambridge label with a Merriam URL, or vice versa.
- For source-policy cleanup across existing payload/page pairs, run `uv run python scripts/normalize_word_sources.py --check` first. Run it without `--check` only when intentionally normalizing both JSON payloads and rendered HTML pages.

## Payload Mode

1. Confirm the target word(s), learner language, and any source expectations. If the user asks for N new words without naming them, read `prototypes/word-index.js` first and choose N non-duplicate, practical, etymology-rich words with varied concepts or domains.
2. Treat the skill directory's `assets/template/word-page-template.html` as the content contract. Use the skill directory's `assets/template/word-page-payload-template.json` as the output skeleton. Do not load existing word pages such as `prototypes/ephemeral.html` or `prototypes/liminal.html`; do not load `references/ui-ux-pattern.md` unless the user is changing UI.
3. Fill `templatePlaceholders` with exact placeholder keys from the template, for example `WORD_TITLE`, `IPA`, `CEFR_LEVEL`, `ZIPF_FREQUENCY`, `CORE_IDEA`, `COLLOCATION_1`, and `REFERENCE_URL`. Keep values concise, final, and ready to replace the corresponding `{{PLACEHOLDER}}`.
4. Format `IPA` as compact pronunciation metadata: `ih-FEM-er-uhl · UK /.../ · US /.../`. Do not include the literal labels `Respelling`, `UK IPA`, or `US IPA`.
5. Prefer plain text values. Use small inline HTML only when the template context benefits from it, such as `<code>` for literal terms; `CORE_IDEA` should include `<code>{word}</code>` for the literal headword. Do not paste large source excerpts.
6. Fill `indexEntry` so it can later be copied into `prototypes/word-index.js`: `id`, `word`, `partOfSpeech`, `href`, `thesis`, `tags`, and `checks`.
7. Set `target.outputPath` to `prototypes/<word-slug>.html`. Persist reusable payload files under `data/word-payloads/<word-slug>.json` only when the user asks to save them.
8. Follow the fixed source priority above. Only use a fallback source when the higher-priority source is missing, unclear, or insufficient, and then keep the selected source consistent across `DICTIONARY_*` / `ETYMOLOGY_*` / `MODERN_SOURCE_*`, `REFERENCE_*`, and `sourceAudit`.
9. Include `sourceAudit` with the dictionary, etymology/history, and modern/common-usage sources used to support source-sensitive claims. Keep source notes short and separated by claim type.
10. Return the JSON payload plus at most a short note about unresolved assumptions. Do not edit files, run `sync_word_numbers.py`, start a server, browser-verify, or parse existing word page HTML in this mode.

## Render Mode

1. If no payload is provided, read `prototypes/word-index.js`, choose non-duplicate word(s), then create payload file(s) under `data/word-payloads/<word-slug>.json` so rendering has an auditable input.
2. Use the repo script `uv run python scripts/render_word_page.py <payload.json>` for normal rendering. The script reads only the payload, the skill directory's `assets/template/word-page-template.html`, and `prototypes/word-index.js`.
3. Before writing files, run `uv run python scripts/render_word_page.py <payload.json> --dry-run` to validate placeholders, slug, output path, duplicate `id`/`href`, and `indexEntry`.
4. Render Mode must not parse existing word page HTML. Use `prototypes/word-index.js` only to detect duplicate `id`/`href` and append the new `indexEntry`.
5. New word pages live at `prototypes/<word-slug>.html`. The render script should stop instead of overwriting an existing page.
6. For a formal new word page, always add the payload's `indexEntry` to `prototypes/word-index.js`. Preserve `id`, `word`, `partOfSpeech`, `href`, `thesis`, `tags`, and `checks`.
7. Keep shared UI in `prototypes/word-page.css` and shared interaction in `prototypes/word-page.js`; do not inline CSS/JS unless explicitly asked.
8. Run `uv run python scripts/sync_word_numbers.py` after rendering so `Word NN` and `word-index.js` stay contiguous. If `uv` is not on PATH in this Windows/mise setup, resolve the installed `uv.exe` path instead of skipping the check.
9. After editing a word page or index, run `uv run python scripts/sync_word_numbers.py --check`.
10. After rendering or batch-editing payload/page pairs, run `uv run python scripts/validate_word_pages.py` to catch placeholder drift, old IPA labels, missing CEFR/Zipf metadata, and source-policy drift between payloads and rendered pages.
11. When you normalize legacy payloads or adjust source choices, update the corresponding rendered page too; do not stop at the JSON payload alone. Prefer `uv run python scripts/normalize_word_sources.py` for batch source-policy cleanup.
12. After rendering, do a minimal static contract check: confirm the new page has no unresolved `{{PLACEHOLDER}}`, confirm the hero `Word NN`, and confirm `prototypes/word-index.js` contains the new `id`, `href`, `order`, and `checks`.
13. Browser verification is not required for Payload Mode or Render Mode when the template, CSS, and JS are unchanged. Verify in a browser only when files or UI behavior changed.

## UI Refinement Mode

- Read `references/content-model.md` before changing the content sequence.
- Read `references/ui-ux-pattern.md` before changing layout, CSS, interaction, responsive behavior, sticky navigation, pronunciation controls, or active-recall behavior.
- Preserve the calm paper reading feel: low-contrast ink, warm off-white surfaces, muted sage/blue accents, 8px or smaller radius, fine borders, restrained shadows.
- Keep the topbar minimal. Brand text links to page top; keep only a small `單字庫` link back to `index.html`.
- Use the left Reading Path for section anchors and set scroll offset so sticky UI does not cover headings.
- Do not add decorative blobs, oversized toolbars, marketing copy, nested cards, or multiple competing navigation systems.
- Keep text legible and uncrowded on mobile. Tables may scroll horizontally, but the page itself should not overflow.

## Batch Word Selection

When generating multiple new pages and the user did not provide exact words:

- Avoid words already present in `prototypes/word-index.js` by both `id` and displayed `word`.
- Prefer words with a clear conceptual center, memorable origin, and useful modern contexts.
- Vary the set across meaning type, part of speech, and domain when possible, for example one discovery/idea word, one work-quality word, and one system/psychology word.
- Keep each page focused on one word; do not turn batch generation into a multi-word dashboard.

## Output Shape

In Payload Mode, return one JSON object:

- `target`: word, slug, and eventual output path.
- `templatePlaceholders`: exact keys for the skill directory's `assets/template/word-page-template.html`.
- `indexEntry`: future `prototypes/word-index.js` entry data.
- `sourceAudit`: concise source trail for dictionary, pronunciation, level/frequency, etymology/history, and modern/common usage.

In Render Mode, prefer these files for a standalone prototype:

- `prototypes/<word-slug>.html`: semantic content with placeholders replaced.
- `prototypes/word-index.js`: searchable index entry, with `order` maintained by `scripts/sync_word_numbers.py`.
- `prototypes/word-page.css`: shared visual system, responsive layout, sticky topbar, anchor offset.
- `prototypes/word-page.js`: pronunciation and active-recall checkbox persistence.

## Content Rules

- Teach concept, tone, and use, not just translation.
- Separate collocations from neighbor-word distinctions. Collocations answer "what words naturally pair with this word?" Neighbor distinctions answer "what similar words should not be confused with it?"
- Include active recall prompts that ask the learner to explain, remember origin/story, and produce a sentence.
- Keep hero metadata compact: respelling plus `UK /.../` and `US /.../`, then CEFR and Zipf frequency inside the learning-position aside.
- Source notes should be transparent but unobtrusive.
- Treat memory hooks as learning aids, not historical claims.
