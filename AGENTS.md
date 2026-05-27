# AGENTS.md

## 使用者與環境

- 使用者是 Firmware Engineer；預設用繁體中文回應，必要時保留英文技術詞、檔名、函式名與命令。
- 使用者作業系統為 Windows 11；預設提供 PowerShell 相容指令與 Windows 路徑。
- 本專案使用 Python 3.13，依賴由 `pyproject.toml` 與 `uv.lock` 管理。
- 若 `uv` 不在 PATH，先解析本機 mise 安裝的 `uv.exe` 路徑再執行驗證，不要直接跳過。
- 若 `rg` 不可用，改用 `Get-ChildItem`、`Select-String` 等 PowerShell 原生命令。

## 專案定位

- 本專案是外文學習助手，核心目標是建立穩定、可持續、每天真的能用的英文單字深讀與複習流程。
- 目前主軸是單一單詞深讀頁、單字庫管理、陌生字待補清單與低摩擦複習頁。
- 內容品質、概念理解、記憶效果與學習節奏優先於功能數量。
- HTML 原型必須可實際用於學習或管理，不做純展示頁、行銷 landing page 或與學習無關的視覺噪音。

## 架構總覽

- `data/word-payloads/*.json`：單字頁的可審核內容來源；每個 payload 對應一個 `prototypes/<slug>.html`。
- `data/word-batches/*.tsv`：批次產生用的 `|` 分隔 spec input；不是 runtime asset，也不是 payload 的替代品。
- `.codex/skills/daily-vocab-word-page/assets/template/`：單字頁 template 與 payload skeleton 的實際 contract 來源。
- `prototypes/<slug>.html`：由 payload + template 生成的單字深讀頁。
- `prototypes/word-index.js`：單字庫索引與畫面上的 `Word NN` 編號來源；`order` 必須連續。
- `prototypes/word-page.css`、`prototypes/word-page.js`：所有單字頁共用的閱讀版型、發音與 active recall checkbox persistence。
- `prototypes/index.html`、`prototypes/manage-page.*`：單字庫、搜尋、排序、隨機閱讀入口。
- `prototypes/backlog.html`、`prototypes/backlog-page.js`：陌生字待補清單，使用 `localStorage`，並避免與既有單字頁重複。
- `prototypes/review.html`、`prototypes/review-page.js`：主動回想複習頁，依 local review state 排程下一次複習。
- `scripts/*.py`：payload render、批次產生、編號同步、payload/page 驗證與來源政策正規化工具。

## Skill 使用邊界

- 建立、打磨或延伸「單一單詞頁面」時，使用 `$daily-vocab-word-page`。
- 該 skill 的路徑是 `.codex/skills/daily-vocab-word-page/SKILL.md`；單字頁內容模型、source policy、Reading Path、collocations、neighbors、active recall 與驗證要求都以它為準。
- 正式新增或生成單字頁時，優先走 payload/render 流程，不手刻完整頁面、不手動拼接索引。
- 管理頁、複習頁、待補清單、統計頁等產品功能，不要硬套單字頁 skill；保留閱讀氣質，但依功能需求設計資訊架構。
- 根層 `AGENTS.md` 只放專案方向、架構邊界、工作流程與驗證原則；單字頁細節留在 `$daily-vocab-word-page`。

## 單字頁內容規則

- 教學重點是「概念、語氣、使用場景」，不是只給中文翻譯。
- 字源、歷史與現代用法要分清楚；記憶故事可以生動，但不可偽裝成史實。
- 單字頁應包含核心概念、精簡定義、字源、記憶鉤子、情境例子、搭配詞、鄰近字辨析、來源備註與主動回想。
- `IPA` 使用精簡格式，例如 `ih-FEM-er-uhl · UK /.../ · US /.../`；不要回到 `Respelling`、`UK IPA`、`US IPA` 這種舊標籤。
- CEFR 是 repo-calibrated study band；Zipf 參考 `wordfreq`，不要寫成外部單一字典給出的 CEFR 真值。
- 來源欄位、`REFERENCE_*` 與 `sourceAudit` 必須互相一致；不要混用 label 與 URL。

## 常用工作流程

### 新增單一單字頁

1. 先檢查 `prototypes/word-index.js`，避免 `id`、`href` 或 displayed word 重複。
2. 建立或保存 `data/word-payloads/<slug>.json`。
3. 先 dry-run：
   ```powershell
   uv run python scripts\render_word_page.py data\word-payloads\<slug>.json --dry-run
   ```
4. 正式 render：
   ```powershell
   uv run python scripts\render_word_page.py data\word-payloads\<slug>.json
   uv run python scripts\sync_word_numbers.py
   uv run python scripts\validate_word_pages.py data\word-payloads\<slug>.json
   uv run python scripts\sync_word_numbers.py --check
   ```

### 批次新增單字頁

1. 使用 `data/word-batches/*.tsv` 作為批次 spec，delimiter 是 `|`。
2. required columns 以 `scripts/generate_batch_word_pages.py` 為準。
3. 執行：
   ```powershell
   uv run python scripts\generate_batch_word_pages.py data\word-batches\<batch-name>.tsv
   ```
4. 若只要產生 payload 並 dry-run，不 render：
   ```powershell
   uv run python scripts\generate_batch_word_pages.py data\word-batches\<batch-name>.tsv --payload-only
   ```

### 正規化來源政策

- 先檢查 drift：
  ```powershell
  uv run python scripts\normalize_word_sources.py --check
  ```
- 只有在確定要同時更新 payload JSON 與 rendered HTML 時，才拿掉 `--check`。

## UI 與產品方向

- 單字頁維持安靜閱讀感：低對比墨色、溫暖紙底、細邊框、克制陰影、8px 以內圓角。
- 單字頁不是 landing page；不要加入大型行銷 hero、裝飾性漸層球、重複導覽或無關視覺噪音。
- 管理頁重視掃描、搜尋、排序、狀態與低摩擦操作。
- 複習頁重視主動回想、錯題回流與低摩擦輸入；先回想再翻面確認，不要變成被動瀏覽。
- 響應式設計要檢查桌面與手機寬度，避免文字溢出、水平捲動、導覽遮住標題或互動狀態不明。

## 實作偏好

- 修改前先看真實檔案與 `git status --short`；不要憑印象改 durable docs 或 workflow。
- 優先最小可行修改，避免一開始就大型重構。
- 文字型成果、筆記、規格與學習材料優先使用 Markdown。
- 需要呈現 UI、視覺設計或互動流程時使用 HTML，並延續現有 HTML/CSS/JS 命名與版型。
- 新增 Python 腳本保持小而清楚；不隨意新增大型依賴。
- 不要把待補單字的資料主鍵和單字頁 `id` 混用；待補清單使用自己的 `backlogId`。
- 若工作樹已有使用者或前一輪留下的變更，不要回復或順手整理無關檔案；提交時只 stage 本次任務相關檔案。

## 驗證與交付

- 修改 Markdown 文件後，至少執行：
  ```powershell
  git diff --check
  ```
- 修改 HTML/CSS/JS 後，盡量檢查瀏覽器 console、桌面/手機版面、anchor offset、搜尋、checkbox 與發音按鈕。
- 修改單字頁、payload 或 `word-index.js` 後，至少執行：
  ```powershell
  uv run python scripts\validate_word_pages.py
  uv run python scripts\sync_word_numbers.py --check
  ```
- 修改來源政策、render contract 或批次流程後，延伸執行：
  ```powershell
  uv run python scripts\normalize_word_sources.py --check
  uv run python scripts\validate_word_pages.py
  uv run python scripts\sync_word_numbers.py --check
  ```
- 交付時簡短說明改了什麼、在哪裡、如何驗證；若未能驗證，要明確告知。
