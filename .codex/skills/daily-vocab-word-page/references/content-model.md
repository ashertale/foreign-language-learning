# Content Model

Use this sequence unless the user asks for a different learning flow. It reflects the current `prototypes/ephemeral.html` and `prototypes/liminal.html` style, but the payload is now semantic rather than placeholder-based.

1. Topbar: brand/title linking to page top, plus a small `單字庫` link back to `index.html`.
2. Hero: `Word NN / partOfSpeech`, headword, compact pronunciation (`respelling · UK /.../ · US /.../`), listen button, concise thesis in Traditional Chinese, plus CEFR and Zipf metadata.
3. Reading Path: sticky left navigation for core sections.
4. Core Idea: one strong paragraph capturing the word's conceptual center.
5. Definition: short definition plus one likely confusion word and a compact flow.
6. Origin: optional. Include only when there is real history worth keeping.
7. Memory Hook: one concrete image or metaphor plus one explanatory paragraph.
8. Usage Scenarios: one or more real scenes. Let the word decide whether the useful split is daily/work/product/literary/engineering.
9. Collocations: natural phrase pairings, each with register/domain and an optional use note.
10. Neighbors: table contrasting the headword with one or more nearby concepts.
11. Modern Use: one or more contemporary paragraphs about how the word shows up in real discourse.
12. Source Notes: dictionary source note and modern-usage source note.
13. Reference: external link reusing the dictionary source.

## Payload Rules

- `page` is the content body. Treat it as a semantic container, not a slot-by-slot prose mold.
- `usage`, `collocations.items`, `neighbors.others`, and `modernUse` are variable-length arrays. Use as many items as the word genuinely needs.
- `page.origin` is optional. Omit it rather than padding the page with thin historical filler.
- `page.sources.dictionary` and `page.sources.modern` are learner-facing. `sourceAudit` is the machine-checkable trail for source policy.

See [payload-shape.md](payload-shape.md) for the exact JSON structure.

## Index Entry Rules

Every word page needs a matching `prototypes/word-index.js` entry:

- `id`: page slug, normally filename without `.html`.
- `word`: display headword.
- `partOfSpeech`: matches the hero kicker after `Word NN /`.
- `href`: `./<word-slug>.html`.
- `order`: do not hand-maintain; run `uv run python scripts/sync_word_numbers.py`.
- `thesis`: same conceptual thesis used in the hero.
- `tags`: include Chinese meanings, English search terms, domains, collocations, and part of speech.
- `checks`: concise review cues for meaning distinction, origin/story memory, and sentence production on the separate review page.

After editing `word-index.js` or adding a page, run `uv run python scripts/sync_word_numbers.py --check`; if it reports drift, run it without `--check`.

## Content Quality Rules

- Define the concept before giving translations.
- Separate etymology/history from modern extension. Product or engineering usage belongs in Modern Use unless it is historically attested.
- Include one likely confusion word in the definition section, then fuller distinctions in Neighbors.
- Keep prose concept-first and direct. Avoid study-script phrasing such as `先讀搭配`, `如果你只能想起中文`, `最低摩擦入口`, or `這時重點是精準`.
- Memory hooks may be imaginative, but source notes must not present them as historical fact.
