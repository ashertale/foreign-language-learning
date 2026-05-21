# Content Model

Use this sequence unless the user asks for a different learning flow. It reflects the current `prototypes/ephemeral.html` and `prototypes/liminal.html` structure.

1. Topbar: brand/title linking to page top, plus a small `單字庫` link back to `index.html`.
2. Hero: `Word NN / partOfSpeech`, word, IPA/pronunciation, listen button, concise thesis in Traditional Chinese.
3. Learning Position: short aside that frames the word as a memorable formula.
4. Reading Path: sticky left navigation for core sections.
5. Core Idea: one strong sentence that captures the word's conceptual center.
6. Cue Grid: 3 compact tiles: concept focus, tone/register, use warning.
7. Definition: short definition plus one contrast with the most likely confusing word.
8. Flow Formula: 3-step visual sequence for memory.
9. Origin / Story: etymology, historical anecdote, or semantic origin.
10. Memory Hook: one concrete image or metaphor plus one explanatory paragraph.
11. Usage Scenarios: daily, digital/professional, scientific/technical, or domain-relevant contexts.
12. Collocations: 3-5 natural phrase pairings, each with register/domain and use note.
13. Neighbors: table contrasting similar/opposite concepts.
14. Modern Use: how the word appears in contemporary discourse or work.
15. Source Notes: dictionary source, etymology/history source, common/modern usage note.
16. Active Recall: checkbox prompts plus one ready-to-practice sentence.
17. Reference: external dictionary/source link.

## Index Entry Rules

Every word page needs a matching `prototypes/word-index.js` entry:

- `id`: page slug, normally filename without `.html`.
- `word`: display headword.
- `partOfSpeech`: matches the hero kicker after `Word NN /`.
- `href`: `./<word-slug>.html`.
- `order`: do not hand-maintain; run `uv run python scripts/sync_word_numbers.py`.
- `thesis`: same conceptual thesis used in the hero.
- `tags`: include Chinese meanings, English search terms, domains, collocations, and part of speech.
- `checks`: mirror the three active-recall prompts: meaning distinction, origin/story, sentence production.

After editing `word-index.js` or adding a page, run `uv run python scripts/sync_word_numbers.py --check`; if it reports drift, run it without `--check`.

## Batch Generation Rules

When the user requests multiple new words without specifying exact targets:

- Read the existing index first and skip duplicate headwords or slugs.
- Choose words that are useful for daily learning and have enough conceptual depth for this page model.
- Prefer a balanced batch: different concept families, varied domains, and no repeated near-synonym cluster unless the user asks for that cluster.
- Make each hero thesis distinct enough that the index can be scanned quickly.
- Keep `checks` parallel across pages: meaning distinction, origin/story memory, and one sentence-production task.

## Source Research Rules

For each new word page, confirm at least these source categories before writing source-sensitive content:

- Dictionary and pronunciation: definition, part of speech, IPA, basic usage.
- Etymology/history: origin language, historical formation, coined story, or semantic development.
- Common/modern usage: practical domains such as work, engineering, product, science, social media, literature, or everyday speech.

Summarize sources in your own words. Do not copy long dictionary prose. Memory hooks may be imaginative, but source notes must not present them as historical facts.

## Collocation Rules

Collocations should be phrase-level and usage-oriented, for example `ephemeral content` or `ephemeral beauty`. Mark the most natural register/domain: literary, everyday narrative, academic, digital product, privacy, engineering, business, etc.

Do not repeat neighbor words as collocations. For example, `temporary` and `transient` belong in Neighbors, not Collocations.

## Source Notes Rules

Separate claims into:

- Dictionary source: definition, pronunciation, basic examples.
- Etymology/history: origin language, historical formation, attested story.
- Common/modern usage: product, engineering, science, social media, or common explanatory examples.

Avoid making invented memory stories look like historical fact. Label imaginative hooks by placement and tone, not by fake citation.

## Content Quality Rules

- Define the concept before giving translations.
- Separate etymology/history from modern extension. For example, engineering or social-media usage belongs in Modern Use unless it is historically attested.
- Include one likely confusion word in the definition section, then fuller distinctions in Neighbors.
- Prefer 3 compact cue tiles, 3 usage scenarios, 3-5 collocations, and 3 active-recall checks.
