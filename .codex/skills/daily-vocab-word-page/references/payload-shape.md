# Payload Shape

單字頁 payload 使用語意資料模型。

重點：

- `page` 是內容主體；把它當成段落與區塊的語意容器，不是逐格填空。
- `usage`、`collocations.items`、`neighbors.others`、`modernUse` 都是可伸縮陣列；依單字本身決定重點，不要為了湊版面硬塞句子。
- `usage` 是整張卡片的語意單位，`label + body` 共同提供學習語境；body 應保持自然例句，不需要為了含中文而補固定句尾。
- 不要把語意欄位寫成模板提示或空話；禁止 `這裡放在...情境時`、`這個搭配常用來寫...`、`用在「...」這類判斷上`、`本頁把...整理成...學習概念` 這類文字。
- 同一頁內不要反覆用同一種解釋句型。`coreIdea`、`usage`、`collocations`、`neighbors`、`modernUse` 應各自承擔不同功能。
- `page.sources.dictionary` 與 `page.sources.modern` 是 learner-facing source notes；`sourceAudit` 則是驗證與追蹤來源政策用的機器可檢查資料。
- 參考框使用 `page.sources.dictionary` 作為唯一的 learner-facing dictionary source 欄位。

```json
{
  "target": {
    "word": "Ephemeral",
    "slug": "ephemeral",
    "outputPath": "prototypes/ephemeral.html"
  },
  "page": {
    "partOfSpeech": "adjective",
    "pronunciation": "ih-FEM-er-uhl · UK /ɪˈfem.ər.əl/ · US /əˈfem.ɚ.əl/",
    "hero": {
      "thesis": "不是單純的「短暫」，而是短到讓你意識到時間正在流走。",
      "cefrLevel": "C2",
      "zipfFrequency": "2.99"
    },
    "coreIdea": "<code>ephemeral</code> 描述那些不會久留的事物；正因為它們短暫，反而逼你在當下看見它們的重量。",
    "definition": {
      "summary": "形容存在時間很短、很快消逝的事物。它常帶有詩意，不只是「短」，還有「稍縱即逝」的感覺。",
      "contrast": {
        "word": "Temporary",
        "note": "<code>temporary</code> 偏向功能性的暫時；<code>ephemeral</code> 更像晨霧、花期、限時訊息：短暫本身就是它的氣質。"
      },
      "flow": [
        "出現",
        "短暫閃耀",
        "消失"
      ]
    },
    "origin": {
      "history": "<code>ephemeral</code> 來自 Greek <code>ephēmeros</code>，意思接近「只持續一天」。",
      "memoryLens": "它不是冷冰冰地說某物很短，而是提醒你：有些東西從一開始就帶著結束的影子。"
    },
    "memory": {
      "hook": "<code>ephemeral</code> 是早晨玻璃上的霧氣：你看見它時，它已經正在消失。",
      "explanation": "這個字的美感在於張力：越短暫，越需要被注意。"
    },
    "usage": [
      {
        "label": "日常版",
        "body": "夕陽、花火、旅行中的偶遇，都可以是 <code>ephemeral</code>：短暫，但因為短暫而鮮明。"
      },
      {
        "label": "數位 / 專業版",
        "body": "限時動態、閱後即焚訊息、即時熱搜，都帶著 <code>ephemeral</code> 的特性：出現很快，退場也很快。"
      }
    ],
    "collocations": {
      "note": "這裡放自然搭配；相似字的概念邊界留到辨析表處理。",
      "items": [
        {
          "phrase": "ephemeral beauty",
          "register": "文學 / 藝評 / 自然書寫",
          "note": "適合寫花期、晨霧、夕陽、舞台表演，語感柔和、有審美距離。"
        },
        {
          "phrase": "ephemeral moment",
          "register": "敘事 / 日常書寫",
          "note": "比 <code>short moment</code> 更有「一閃即逝但值得記住」的味道。"
        }
      ]
    },
    "neighbors": {
      "self": {
        "meaning": "短暫存在，快速消逝，常帶有詩意或脆弱感",
        "use": "描述自然現象、情緒、潮流、數位內容或短生命週期工程資源。"
      },
      "others": [
        {
          "word": "Temporary",
          "meaning": "暫時使用或暫時存在，語氣較中性、功能性",
          "use": "描述暫時安排、暫時狀態或功能性的短期存在。"
        }
      ]
    },
    "modernUse": [
      "在現代生活裡，<code>ephemeral</code> 常跟會快速消失的內容一起出現，讓注意力本身也帶上時間壓力。",
      "在科技語境中，像 ephemeral environments、ephemeral ports、ephemeral keys，都暗示這些東西不該被長期依賴。"
    ],
    "sources": {
      "dictionary": {
        "note": "定義、音標與核心義主要參考 Cambridge Dictionary；例句與近義詞只作語感輔助。",
        "url": "https://dictionary.cambridge.org/dictionary/english/ephemeral",
        "label": "Cambridge Dictionary"
      },
      "modern": {
        "note": "社群限時內容與工程 ephemeral resources 屬現代用法延伸，不當作古典字源。",
        "url": "https://www.merriam-webster.com/dictionary/ephemeral",
        "label": "Merriam-Webster"
      }
    }
  },
  "indexEntry": {
    "id": "ephemeral",
    "word": "Ephemeral",
    "partOfSpeech": "adjective",
    "href": "./ephemeral.html",
    "thesis": "不是單純的「短暫」，而是短到讓你意識到時間正在流走。",
    "tags": [
      "短暫",
      "詩意",
      "temporary",
      "transient",
      "adjective"
    ]
  },
  "sourceAudit": [
    {
      "category": "dictionary-pronunciation",
      "label": "Cambridge Dictionary",
      "url": "https://dictionary.cambridge.org/dictionary/english/ephemeral",
      "usedFor": "definition, pronunciation, and dictionary sense support"
    },
    {
      "category": "level-frequency",
      "label": "wordfreq Zipf + repo CEFR calibration",
      "url": "https://github.com/rspeer/wordfreq",
      "usedFor": "Zipf frequency reference and repo-calibrated CEFR study band"
    },
    {
      "category": "etymology-history",
      "label": "Online Etymology Dictionary",
      "url": "https://www.etymonline.com/word/ephemeral",
      "usedFor": "etymology and word-history support"
    },
    {
      "category": "modern-common-usage",
      "label": "Merriam-Webster",
      "url": "https://www.merriam-webster.com/dictionary/ephemeral",
      "usedFor": "modern usage examples and current usage boundaries"
    }
  ]
}
```
