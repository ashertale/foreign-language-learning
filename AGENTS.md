# AGENTS.md

## 使用者與環境

- 使用者作業系統為 Windows 11；預設使用 PowerShell 相容指令與 Windows 路徑。
- 預設以繁體中文回應；專業術語、函式庫、標準與檔名可保留英文。
- 本專案目前使用 Python 3.13；依賴由 `pyproject.toml` 與 `uv.lock` 描述。
- 若 `rg` 不可用，使用 `Get-ChildItem`、`Select-String` 等 PowerShell 原生命令。

## 專案定位

- 本專案是外文學習助手，目標是建立穩定、可持續、每天真的能用的學習流程。
- 目前重心是單一單詞深讀頁、單字庫、陌生字待補清單；每日頁與複習頁策略尚未定案，避免過早固定。
- 內容品質、記憶效果與學習節奏優先於功能數量。
- HTML 原型必須可實際用於學習或管理，不做純展示頁或行銷 landing page。

## 目前結構

- `prototypes/ephemeral.html`、`prototypes/liminal.html`：單一英文單詞深讀頁樣張。
- `prototypes/word-page.css`、`prototypes/word-page.js`：單詞頁共用視覺與互動。
- `prototypes/index.html`、`prototypes/manage-page.css`、`prototypes/manage-page.js`：單字庫與搜尋管理頁。
- `prototypes/backlog.html`、`prototypes/backlog-page.js`：陌生字待補清單，需避免和既有單字頁重複。
- `prototypes/word-index.js`：單字庫索引；`order` 是畫面上的 `Word NN` 編號。
- `scripts/sync_word_numbers.py`：同步 `word-index.js` 的 `order` 與各單詞頁 hero 的 `Word NN`。
- `.codex/skills/daily-vocab-word-page/`：本專案專用的單詞頁 skill。

## Skill 使用

- 建立、打磨或延伸「單一單詞頁面」時，使用 `$daily-vocab-word-page`：
  - 專案層級路徑：`.codex/skills/daily-vocab-word-page/SKILL.md`
  - 遵守它的內容模型、Reading Path、source notes、collocations、neighbors、active recall 與驗證要求。
- 若需求是正式新增或生成單詞頁，優先走該 skill 的 payload/render 流程，不手刻頁面或手動拼接索引。
- 管理頁、複習頁、待補清單、統計頁等產品功能，不要硬套單詞頁 skill；保留閱讀氣質，但依功能需求設計資訊架構。

## 單詞頁規則

- 教學重點是「概念、語氣、使用場景」，不是只給中文翻譯。
- 字源、歷史與現代用法要分清楚；記憶故事可以生動，但不可偽裝成史實。
- 單詞頁應包含核心概念、精簡定義、字源、記憶鉤子、情境例子、搭配詞、鄰近字辨析、來源備註、主動回想。
- 新增或調整單詞頁後，更新 `prototypes/word-index.js`，再執行：
  ```powershell
  uv run python scripts\sync_word_numbers.py
  ```

## UI 與產品方向

- 單詞頁維持安靜閱讀感：低對比墨色、溫暖紙底、細邊框、克制陰影、8px 以內圓角。
- 單詞頁不是 landing page；不要加入大型行銷 hero、裝飾性漸層球、重複導覽或無關視覺噪音。
- 管理頁重視掃描、搜尋、排序、狀態與低摩擦操作。
- 複習頁若重啟設計，應重視主動回想、錯題回流與低摩擦輸入。
- 響應式設計要檢查桌面與手機寬度，避免文字溢出、水平捲動、導覽遮住標題或互動狀態不明。

## 實作偏好

- 文字型成果、筆記、規格與學習材料優先使用 Markdown。
- 需要呈現 UI、視覺設計或互動流程時使用 HTML；先延續現有 HTML/CSS/JS 命名與版型。
- 新增 Python 腳本保持小而清楚；不隨意新增大型依賴。
- 不要把待補單字的資料主鍵和單字頁 `id` 混用；待補清單使用自己的 `backlogId`。

## 驗證與交付

- 修改 HTML/CSS/JS 後，盡量檢查瀏覽器 console、桌面/手機版面、anchor offset、搜尋/checkbox/發音按鈕。
- 修改單詞頁或 `word-index.js` 後，至少執行：
  ```powershell
  uv run python scripts\sync_word_numbers.py --check
  ```
- 若 `uv` 不在 PATH，先解析本機 mise 安裝的 `uv.exe` 路徑再執行驗證，不要直接跳過。
- 交付時簡短說明改了什麼、在哪裡、如何驗證；若未能驗證，要明確告知。
