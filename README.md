# Foreign Language Learning

一個以「每天真的能用」為目標的英文單字深讀與複習原型。它不是傳統後端服務，而是靜態 HTML 學習介面、可審核 JSON payload、Python 產生/驗證工具與瀏覽器 `localStorage` 狀態的組合。

目前 repo 的主要成果是約 500 個單字 payload/page pairs、單字庫搜尋管理頁、陌生字待補清單，以及主動回想式複習頁。

## 快速開始

安裝依賴：

```powershell
uv sync
```

啟動靜態檔案伺服器：

```powershell
uv run python -m http.server 4173
```

打開：

```text
http://127.0.0.1:4173/prototypes/index.html
```

`prototypes/review.html` 會用 `fetch()` 讀取單字頁核心概念，建議用本機 HTTP server 開啟，不要直接用 `file://`。

## 架構總覽

```text
data/word-payloads/*.json
  -> scripts/render_word_page.py
  -> .codex/skills/daily-vocab-word-page/assets/template/word-page-template.html
  -> prototypes/<slug>.html
  -> prototypes/word-index.js
  -> prototypes/index.html / backlog.html / review.html
```

核心設計是「內容來源」和「可閱讀頁面」分離：

- `data/word-payloads/*.json` 是單字頁的可審核輸入。
- `.codex/skills/daily-vocab-word-page/assets/template/word-page-template.html` 是單字頁 HTML contract。
- `prototypes/<slug>.html` 是由 payload 產生的閱讀頁。
- `prototypes/word-index.js` 是單字庫、搜尋、複習與重複檢查共用的索引。
- `scripts/*.py` 負責生成、同步、驗證與來源政策正規化。

## 主要功能

單字深讀頁：

- 呈現核心概念、語氣、短定義、字源、記憶鉤子、使用情境、collocations、neighbor distinctions、source notes 與 active recall。
- 使用 `prototypes/word-page.css` 維持安靜紙感閱讀 UI。
- 使用 `prototypes/word-page.js` 提供 Web Speech API 發音與 checkbox 記憶狀態。

單字庫：

- `prototypes/index.html` 讀取 `window.WORD_INDEX`，支援搜尋、排序、隨機閱讀與 keyboard navigation。
- 搜尋範圍刻意收斂在 word 與 tags，避免 thesis 造成過寬匹配。
- 排序支援原始 `Word NN`、A-Z、字長、CEFR、Zipf。

陌生字：

- `prototypes/backlog.html` 使用 `localStorage` key `vocab-backlog:v1`。
- 每筆待補資料使用 `backlogId`，不要和單字頁 `id` 混用。
- 新增時會檢查是否已存在於 `word-index.js` 或待補清單。

複習：

- `prototypes/review.html` 使用 `localStorage` key `vocab-review:v1`。
- 每輪最多 8 張，到期卡片優先，並用 Zipf / order 作為排序輔助。
- 流程是先回想、輸入或心中作答，再翻面確認，最後用 `Again`、`Hard`、`Good`、`Easy` 安排下一次複習。

## 常用工作流程

新增單一單字頁：

```powershell
uv run python scripts\render_word_page.py data\word-payloads\<slug>.json --dry-run
uv run python scripts\render_word_page.py data\word-payloads\<slug>.json
uv run python scripts\sync_word_numbers.py
uv run python scripts\validate_word_pages.py data\word-payloads\<slug>.json
uv run python scripts\sync_word_numbers.py --check
```

批次產生單字頁：

```powershell
uv run python scripts\generate_batch_word_pages.py data\word-batches\<batch-name>.tsv
```

只產生 payload 並 dry-run：

```powershell
uv run python scripts\generate_batch_word_pages.py data\word-batches\<batch-name>.tsv --payload-only
```

檢查來源政策 drift：

```powershell
uv run python scripts\normalize_word_sources.py --check
```

完整驗證既有 payload/page pairs：

```powershell
uv run python scripts\validate_word_pages.py
uv run python scripts\sync_word_numbers.py --check
```

## 資料與 contract

`data/word-payloads/<slug>.json` 包含：

- `target`：word、slug、輸出路徑。
- `templatePlaceholders`：對應 template 的所有 placeholder。
- `indexEntry`：要加入 `prototypes/word-index.js` 的搜尋與複習資料。
- `sourceAudit`：dictionary、level/frequency、etymology、modern usage 的來源軌跡。

`data/word-batches/*.tsv` 是批次 spec input，使用 `|` 作為 delimiter。實際 required columns 以 `scripts/generate_batch_word_pages.py` 為準。批次腳本會拒絕覆寫既有 rendered page，也會檢查 `id`、`href` 與 displayed word 是否重複。

## 來源政策

單字頁不是只靠自由生成文字；source-sensitive claims 要能追到穩定來源：

- Dictionary/pronunciation：優先 `Cambridge Dictionary`，其次 `Merriam-Webster`，再用 `Oxford Learner's Dictionaries` 或 `Britannica Dictionary`。
- Etymology/history：優先 `Online Etymology Dictionary`，其次 `Merriam-Webster`。
- Modern/common usage：優先 `Merriam-Webster`，其次 `Cambridge Dictionary` 或 `Britannica Dictionary`。
- Level/frequency：Zipf 參考 `wordfreq`；CEFR 是 repo-calibrated study band。

`templatePlaceholders.*SOURCE*`、`REFERENCE_*` 與 `sourceAudit` 必須保持一致。

## Repository Map

```text
.codex/skills/daily-vocab-word-page/
  Project-specific skill, template, payload skeleton, and word-page rules.

data/word-payloads/
  Durable JSON inputs for generated word pages.

data/word-batches/
  Optional pipe-delimited batch specs for generating many payloads/pages.

prototypes/
  Static learning app, generated word pages, shared CSS/JS, library, backlog, review.

scripts/
  Render, batch generation, numbering sync, validation, and source normalization.

pyproject.toml / uv.lock
  Python 3.13 project dependency metadata.
```

## 開發注意事項

- 修改前先看 `git status --short`，避免覆蓋或提交無關變更。
- 單字頁細節以 `$daily-vocab-word-page` skill 為準；根層文件只保留專案方向與 workflow。
- `prototypes/word-index.js` 的 `order` 是畫面上的 `Word NN`，新增或移動頁面後要同步。
- 修改 Markdown 後至少跑 `git diff --check`。
- 修改 HTML/CSS/JS 後建議用本機 HTTP server 檢查桌面與手機版面、console、搜尋、checkbox、發音與複習互動。
