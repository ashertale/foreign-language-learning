# UI / UX Pattern

The page should feel like a quiet literary study sheet: soft paper background, restrained accents, generous but not empty spacing, and high readability.

## Layout

- Sticky topbar with brand/title linking to `#top` and one small `單字庫` link to `./index.html`.
- Hero uses full-width band, large serif word, IPA/listen row, and short thesis. The hero content is not inside a card.
- Main layout is two columns on desktop: left Reading Path and right article. Collapse to one column on tablets/mobile.
- Use section bands separated by fine top borders. Use cards only for repeated items and compact learning prompts.
- Keep cards at 8px radius or less.

## Navigation

- Reading Path links to section ids: `core`, `definition`, `origin`, `memory`, `usage`, `collocations`, `neighbors`, `modern`, `sources`, `practice`.
- Add `scroll-padding-top` to `html` and `scroll-margin-top` to anchor sections so sticky topbar does not cover headings.
- After adding/removing sections, update Reading Path and verify anchor positions.

## Interaction

- `data-speak` buttons use browser speech synthesis for quick pronunciation.
- `data-check` checkboxes persist active-recall state in `localStorage` keyed by page filename.
- Keep interactions optional. The page should still be useful when JavaScript is disabled, except for speech and saved checks.
- Do not add page-local search, flashcards, review queues, or dashboard controls to a single-word page. Those belong in management/review pages.

## Visual Style

- Palette: ink `#25302d`, muted `#66726d`, paper `#f5f6f1`, surface `#fffefb`, line `#d9dfd6`, accent around muted sage/blue.
- Typography: local Traditional Chinese sans for body, Georgia/Times for the English headword and IPA.
- Use fine texture via subtle repeating gradients only; do not use orbs, bokeh, loud gradients, or decorative illustrations.
- Keep buttons minimal and icon use restrained. The pronunciation button may use a small play symbol.

## Validation Checklist

- No topbar duplicate navigation when Reading Path already covers the same anchors.
- No horizontal page overflow on desktop or mobile.
- Tables may scroll inside `.table-wrap` on mobile.
- No console errors.
- Pronunciation button resets its label after playback or error.
- Active-recall checkbox state persists after reload and is scoped by filename.
- `Word NN` in the hero matches `prototypes/word-index.js` after running `uv run python scripts/sync_word_numbers.py --check`.
- Hard refresh or cache-busting may be needed while testing Live Server.

## Static Fallback Checklist

Use this when local browser or localhost verification is blocked by the environment. Report clearly that visual browser verification was not completed.

For each new page, check:

- `<title>`, `<h1>`, and hero `.kicker` match the chosen word, part of speech, and index order.
- `word-page.css` and `word-page.js` are linked externally.
- Reading Path contains links for `#core`, `#definition`, `#origin`, `#memory`, `#usage`, `#collocations`, `#neighbors`, `#modern`, `#sources`, and `#practice`.
- Each Reading Path link has a matching section id, with no duplicate ids.
- Exactly one pronunciation button has `data-speak`.
- Exactly three active-recall checkboxes have `data-check`.
- There are three source cards and three to five collocation cards.
- `prototypes/word-index.js` contains the matching `id`, `word`, `partOfSpeech`, `href`, `thesis`, `tags`, and `checks`.
- `uv run python scripts/sync_word_numbers.py --check` passes; if `uv` is not on PATH, resolve the mise-managed `uv.exe` path before giving up.
