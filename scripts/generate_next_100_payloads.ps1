$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$PayloadDir = Join-Path $Root "data\word-payloads"
$BatchDir = Join-Path $Root "data\word-batches"
$BatchPath = Join-Path $BatchDir "2026-06-06-next-100-501-600.tsv"

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Get-CoreIdea {
    param([hashtable]$Entry)

    $word = $Entry.word.ToLowerInvariant()

    switch ($Entry.partOfSpeech) {
        "adjective" {
            return "<code>$word</code> 描述一種「$($Entry.selfMeaning)」的狀態。它不只是在貼表面標籤，而是把氣壓、方向或隱含張力一起帶進來。"
        }
        "verb" {
            return "<code>$word</code> 表示把事情往「$($Entry.selfMeaning)」的方向推。重點不只在動作發生，而在那個動作怎麼改變局面。"
        }
        "noun" {
            return "<code>$word</code> 指那種「$($Entry.selfMeaning)」的狀態、力量、場面或事物。它常把抽象感受壓縮成一個可指認的名詞。"
        }
        default {
            throw "Unsupported part of speech: $($Entry.partOfSpeech)"
        }
    }
}

function Get-DefinitionSummary {
    param([hashtable]$Entry)

    switch ($Entry.partOfSpeech) {
        "adjective" {
            return "形容一種「$($Entry.selfMeaning)」的狀態、氣質或外觀。"
        }
        "verb" {
            return "表示把事情往「$($Entry.selfMeaning)」的方向推，或讓局面出現這種結果。"
        }
        "noun" {
            return "指那種「$($Entry.selfMeaning)」的狀態、力量、場面或事物。"
        }
        default {
            throw "Unsupported part of speech: $($Entry.partOfSpeech)"
        }
    }
}

function New-SourceNotes {
    param([hashtable]$Entry)

    $wordLower = $Entry.word.ToLowerInvariant()

    return [ordered]@{
        dictionary = [ordered]@{
            note = "定義、發音與核心義以 Merriam-Webster 為對照基準；本頁把 <code>$wordLower</code> 整理成「$($Entry.selfMeaning)」的學習概念。"
            url = "https://www.merriam-webster.com/dictionary/$wordLower"
            label = "Merriam-Webster"
        }
        modern = [ordered]@{
            note = "本頁用 Merriam-Webster 的現代定義與例句邊界，整理 <code>$wordLower</code> 在日常、工作與抽象討論裡最自然的落點。"
            url = "https://www.merriam-webster.com/dictionary/$wordLower"
            label = "Merriam-Webster"
        }
    }
}

function New-Tags {
    param([hashtable]$Entry)

    return @(
        $Entry.selfMeaning,
        $Entry.flow[0],
        $Entry.contrastWord.ToLowerInvariant(),
        $Entry.collocations[0].phrase,
        $Entry.collocations[1].phrase,
        $Entry.partOfSpeech
    )
}

function Get-UseFocus {
    param([string]$Use)

    $value = $Use.Trim()
    if ($value.StartsWith("用在")) {
        $value = $value.Substring(2)
    }
    $value = $value.TrimEnd([char[]]"。！？")
    if ($value.EndsWith("時")) {
        $value = $value.Substring(0, $value.Length - 1)
    }
    return $value.Trim()
}

function New-Origin {
    param([hashtable]$Entry)

    if ($Entry.ContainsKey("originHistory") -and -not [string]::IsNullOrWhiteSpace([string]$Entry.originHistory)) {
        return [ordered]@{
            history = [string]$Entry.originHistory
            memoryLens = [string]$Entry.originMemoryLens
        }
    }

    return [ordered]@{
        history = "N/A"
        memoryLens = ""
    }
}

function New-UsageItems {
    param([hashtable]$Entry)

    $focus = Get-UseFocus $Entry.selfUse
    $items = @()

    foreach ($item in $Entry.usage) {
        $body = [string]$item.body
        if ($body -notmatch '[一-龯]') {
            if ($body -notmatch '[.!?。！？]\s*$') {
                $body = "$body."
            }
            $body = "$body 這裡放在$($item.label)情境時，是在說$focus。"
        }
        $items += [ordered]@{
            label = $item.label
            body = $body
        }
    }

    return $items
}

function Get-CollocationSectionNote {
    param([hashtable]$Entry)

    $wordLower = $Entry.word.ToLowerInvariant()
    return "這裡放 <code>$wordLower</code> 最自然連在一起的說法；中文註解會補它落在哪種語境與語氣。"
}

function New-CollocationItems {
    param([hashtable]$Entry)

    $focus = Get-UseFocus $Entry.selfUse
    $items = @()

    foreach ($item in $Entry.collocations) {
        $items += [ordered]@{
            phrase = $item.phrase
            register = $item.register
            note = "這個搭配常用來寫$focus。"
        }
    }

    return $items
}

$entries = @(
    [ordered]@{
        slug = "morose"
        word = "Morose"
        partOfSpeech = "adjective"
        pronunciation = "muh-ROHS · UK /məˈrəʊs/ · US /məˈroʊs/"
        cefr = "C1"
        zipf = "2.71"
        thesis = "不是安靜，而是情緒像陰天一樣整片壓下來。"
        selfMeaning = "陰沉低落"
        selfUse = "用在心情悶下去、讓整體氣氛也變灰時。"
        contrastWord = "Sullen"
        contrastNote = "<code>sullen</code> 常帶不合作或怨氣；<code>morose</code> 更像整個人被低氣壓罩住。"
        neighborMeaning = "悶著怒氣或不合作"
        neighborUse = "若重點是怨氣卡住、表情發硬，用 <code>sullen</code> 更貼近。"
        flow = @("情緒往下沉", "話變少或表情收緊", "周圍氣氛一起變暗")
        hook = "把 <code>morose</code> 想成不是暴雨，而是整天不散的灰雲。"
        hookExplanation = "這個字不是一下子的生氣，而是持續壓低周圍光線的情緒。"
        usage = @(
            [ordered]@{ label = "人際"; body = "After the setback, he grew <code>morose</code> and stopped joking with the team." },
            [ordered]@{ label = "敘事"; body = "The novel opens with a <code>morose</code> winter mood that never quite lifts." }
        )
        collocations = @(
            [ordered]@{ phrase = "morose mood"; register = "敘事 / 心理" },
            [ordered]@{ phrase = "morose silence"; register = "人際 / 文學" }
        )
        modernUse = @(
            "在現代英文裡，<code>morose</code> 常用來寫人被挫折、疲憊或失落整片罩住的狀態，比 simply sad 更有氣壓感。"
        )
    }
    [ordered]@{
        slug = "moot"
        word = "Moot"
        partOfSpeech = "adjective"
        pronunciation = "MOOT · UK /muːt/ · US /muːt/"
        cefr = "C1"
        zipf = "3.32"
        thesis = "不是不重要，而是因為前提變了，爭論本身失去落點。"
        selfMeaning = "失去討論意義"
        selfUse = "用在爭點因情勢改變而不再需要真正裁決時。"
        contrastWord = "Irrelevant"
        contrastNote = "<code>irrelevant</code> 是本來就無關；<code>moot</code> 則是本來可談，但後來失去實際意義。"
        neighborMeaning = "本來就無關這個問題"
        neighborUse = "若重點是從一開始就扯不上關係，用 <code>irrelevant</code> 更準。"
        flow = @("本來有爭點", "前提被改寫", "辯論失去實際落點")
        hook = "把 <code>moot</code> 想成球場突然熄燈，球還在手上，比分卻已經不算。"
        hookExplanation = "這個字不是說話題笨，而是說情境變了，繼續吵也落不到結果上。"
        usage = @(
            [ordered]@{ label = "會議"; body = "The deadline extension made the original complaint <code>moot</code>." },
            [ordered]@{ label = "制度"; body = "Without enforcement, the policy debate becomes <code>moot</code>." }
        )
        collocations = @(
            [ordered]@{ phrase = "moot point"; register = "討論 / 辯論" },
            [ordered]@{ phrase = "render the issue moot"; register = "法律 / 管理" }
        )
        modernUse = @(
            "<code>moot</code> 很常出現在專案、政策與法律語境裡，用來指出問題不是被回答了，而是被情勢繞過了。"
        )
    }
    [ordered]@{
        slug = "multifaceted"
        word = "Multifaceted"
        partOfSpeech = "adjective"
        pronunciation = "mul-tee-FAS-uh-tid · UK /ˌmʌl.tiˈfæs.ɪ.tɪd/ · US /ˌmʌl.tiˈfæs.ə.t̬ɪd/"
        cefr = "C1"
        zipf = "2.94"
        thesis = "不是複雜而已，而是同一件事有多個面向同時成立。"
        selfMeaning = "多面向並存"
        selfUse = "用在一個人、問題或作品不能只用單一角度理解時。"
        contrastWord = "Complex"
        contrastNote = "<code>complex</code> 強調難解；<code>multifaceted</code> 強調可從多個面去看。"
        neighborMeaning = "結構複雜、難以處理"
        neighborUse = "若重點是難度與糾纏感，用 <code>complex</code> 更自然。"
        flow = @("不只一個面向", "每個面向都成立", "單一解讀不夠用")
        hook = "把 <code>multifaceted</code> 想成切面很多的寶石，轉一點角度就亮出不同面。"
        hookExplanation = "它不是把事情搞混，而是提醒你不要用一把尺量完整個對象。"
        usage = @(
            [ordered]@{ label = "人物"; body = "She is a <code>multifaceted</code> leader who can coach, negotiate, and design strategy." },
            [ordered]@{ label = "問題"; body = "Climate migration is a <code>multifaceted</code> issue with legal, economic, and human dimensions." }
        )
        collocations = @(
            [ordered]@{ phrase = "multifaceted issue"; register = "政策 / 分析" },
            [ordered]@{ phrase = "multifaceted personality"; register = "人物 / 評述" }
        )
        modernUse = @(
            "在現代分析語境裡，<code>multifaceted</code> 常用來提醒讀者：這不是一條因果線，而是一組互相牽動的面。"
        )
    }
    [ordered]@{
        slug = "mundane"
        word = "Mundane"
        partOfSpeech = "adjective"
        pronunciation = "mun-DAYN · UK /mʌnˈdeɪn/ · US /mʌnˈdeɪn/"
        cefr = "C1"
        zipf = "3.25"
        thesis = "不是普通，而是普通到幾乎沒有戲劇性。"
        selfMeaning = "平凡日常"
        selfUse = "用在缺少新鮮感、驚奇或浪漫色彩的日常細節時。"
        contrastWord = "Ordinary"
        contrastNote = "<code>ordinary</code> 比較中性；<code>mundane</code> 更帶日常磨耗感。"
        neighborMeaning = "一般、常見、不中性帶評價"
        neighborUse = "若只是說平常而不想帶乏味味道，用 <code>ordinary</code> 更穩。"
        flow = @("事情很日常", "沒有戲劇性亮點", "注意力容易滑過")
        hook = "把 <code>mundane</code> 想成桌上那堆每天都在處理、卻很少被記住的雜事。"
        hookExplanation = "這個字常把鏡頭拉回沒有光環的那一面。"
        usage = @(
            [ordered]@{ label = "工作"; body = "Much of engineering excellence lives in <code>mundane</code> habits like naming, logging, and cleanup." },
            [ordered]@{ label = "敘事"; body = "The film turns a <code>mundane</code> commute into a study of loneliness." }
        )
        collocations = @(
            [ordered]@{ phrase = "mundane task"; register = "工作 / 日常" },
            [ordered]@{ phrase = "mundane detail"; register = "敘事 / 評論" }
        )
        modernUse = @(
            "<code>mundane</code> 很常用來替日常勞動重新命名：它表面不起眼，卻往往是系統能不能穩定的真正底盤。"
        )
    }
    [ordered]@{
        slug = "murky"
        word = "Murky"
        partOfSpeech = "adjective"
        pronunciation = "MUR-kee · UK /ˈmɜː.ki/ · US /ˈmɝː.ki/"
        cefr = "C1"
        zipf = "2.91"
        thesis = "不是黑，而是混濁到你看不清底下到底是什麼。"
        selfMeaning = "混濁不明"
        selfUse = "用在資訊、動機、金流或局勢看不透時。"
        contrastWord = "Vague"
        contrastNote = "<code>vague</code> 偏模糊；<code>murky</code> 更像有東西藏在混水裡。"
        neighborMeaning = "只是說得不清楚"
        neighborUse = "若重點是表達不夠明確，用 <code>vague</code> 就夠了。"
        flow = @("表面看得到輪廓", "細節被混水遮住", "真正情況難以辨認")
        hook = "把 <code>murky</code> 想成踩進混水池，水面不是全黑，但你也不敢確定腳下有什麼。"
        hookExplanation = "它的危險感來自看不清，而不是完全看不見。"
        usage = @(
            [ordered]@{ label = "資訊"; body = "The ownership trail remained <code>murky</code> even after the audit." },
            [ordered]@{ label = "動機"; body = "Their reasons for delaying the release still feel <code>murky</code>." }
        )
        collocations = @(
            [ordered]@{ phrase = "murky details"; register = "調查 / 報導" },
            [ordered]@{ phrase = "murky waters"; register = "隱喻 / 評論" }
        )
        modernUse = @(
            "在現代評論與調查寫作裡，<code>murky</code> 常把「不透明」和「可能有問題」這兩層意思一起帶進來。"
        )
    }
    [ordered]@{
        slug = "muse"
        word = "Muse"
        partOfSpeech = "verb"
        pronunciation = "MYOOZ · UK /mjuːz/ · US /mjuːz/"
        cefr = "C1"
        zipf = "2.88"
        thesis = "不是立刻下結論，而是讓想法在腦中慢慢繞一圈。"
        selfMeaning = "沉思醞釀"
        selfUse = "用在不急著答、先讓問題在腦中發酵時。"
        contrastWord = "Ponder"
        contrastNote = "<code>ponder</code> 比較正式沉重；<code>muse</code> 常更輕、更帶自言自語感。"
        neighborMeaning = "認真而沉重地思量"
        neighborUse = "若你要的是較正式、較用力的思索感，用 <code>ponder</code> 更貼近。"
        flow = @("問題先停住", "想法慢慢繞開來", "答案未必立刻落下")
        hook = "把 <code>muse</code> 想成手上捧著一個問題，沒有立刻拆開，只先在手裡轉一轉。"
        hookExplanation = "這個字保留了思考的空氣感，不急著把一切壓成結論。"
        usage = @(
            [ordered]@{ label = "寫作"; body = "She paused to <code>muse</code> on why the memory still felt unfinished." },
            [ordered]@{ label = "會議後"; body = "On the walk home, he <code>mused</code> about what the product was really trying to become." }
        )
        collocations = @(
            [ordered]@{ phrase = "muse on the question"; register = "寫作 / 思辨" },
            [ordered]@{ phrase = "muse aloud"; register = "口語 / 敘事" }
        )
        modernUse = @(
            "<code>muse</code> 很適合用在設計、寫作與回顧情境裡，因為它讓思考保持開口，不急著被 KPI 或結論蓋死。"
        )
    }
    [ordered]@{
        slug = "muster"
        word = "Muster"
        partOfSpeech = "verb"
        pronunciation = "MUS-ter · UK /ˈmʌs.tə/ · US /ˈmʌs.tɚ/"
        cefr = "C1"
        zipf = "2.74"
        thesis = "不是突然變多，而是把零散的力氣硬是湊成可用的一股。"
        selfMeaning = "勉強湊出"
        selfUse = "用在把勇氣、能量、資源或支持一點點聚起來時。"
        contrastWord = "Gather"
        contrastNote = "<code>gather</code> 比較中性；<code>muster</code> 常帶費力、原本不夠的感覺。"
        neighborMeaning = "把東西集中起來"
        neighborUse = "若只是一般收集或聚集，不必特別突出勉強感，用 <code>gather</code> 即可。"
        flow = @("原本分散或不足", "用力把它們叫回來", "勉強形成可用份量")
        hook = "把 <code>muster</code> 想成只剩幾顆電池，還是硬把它們湊進手電筒裡照一段路。"
        hookExplanation = "這個字常帶出資源有限卻仍要撐出一點作用的味道。"
        usage = @(
            [ordered]@{ label = "勇氣"; body = "She finally <code>mustered</code> the courage to ask the harder question." },
            [ordered]@{ label = "資源"; body = "The team could barely <code>muster</code> enough evidence to justify a rollback." }
        )
        collocations = @(
            [ordered]@{ phrase = "muster the courage"; register = "人際 / 敘事" },
            [ordered]@{ phrase = "muster enough support"; register = "管理 / 政策" }
        )
        modernUse = @(
            "在現代英文裡，<code>muster</code> 很常用來寫人在資源不足時仍硬湊出一點行動能力。"
        )
    }
    [ordered]@{
        slug = "mutable"
        word = "Mutable"
        partOfSpeech = "adjective"
        pronunciation = "MYOO-tuh-buhl · UK /ˈmjuː.tə.bəl/ · US /ˈmjuː.t̬ə.bəl/"
        cefr = "B2"
        zipf = "3.18"
        thesis = "不是會動，而是可以被改成另一種樣子。"
        selfMeaning = "可被改寫"
        selfUse = "用在資料、狀態或安排能被後續修改時。"
        contrastWord = "Immutable"
        contrastNote = "<code>immutable</code> 是刻意不讓它變；<code>mutable</code> 則保留可被改寫的空間。"
        neighborMeaning = "建立後不再更動"
        neighborUse = "若重點是安全或一致性而故意鎖死，用 <code>immutable</code> 更精準。"
        flow = @("先有一個狀態", "之後仍可修改", "同一個東西持續被改寫")
        hook = "把 <code>mutable</code> 想成白板，不是石碑。"
        hookExplanation = "這個字的重點不是變化本身，而是它還開放給你改。"
        usage = @(
            [ordered]@{ label = "工程"; body = "A <code>mutable</code> object is easy to update but harder to reason about in concurrent code." },
            [ordered]@{ label = "制度"; body = "The schedule stayed <code>mutable</code> until the final supplier confirmed capacity." }
        )
        collocations = @(
            [ordered]@{ phrase = "mutable state"; register = "工程 / 軟體" },
            [ordered]@{ phrase = "mutable object"; register = "工程 / 程式設計" }
        )
        modernUse = @(
            "<code>mutable</code> 在工程語境特別常見，因為它直接碰到可改寫帶來的彈性與推理成本。"
        )
    }
    [ordered]@{
        slug = "myriad"
        word = "Myriad"
        partOfSpeech = "adjective"
        pronunciation = "MEER-ee-uhd · UK /ˈmɪr.i.əd/ · US /ˈmɪr.i.æd/"
        cefr = "C1"
        zipf = "2.86"
        thesis = "不是很多而已，而是多到像整片鋪開。"
        selfMeaning = "繁多鋪開"
        selfUse = "用在選項、原因、細節或變化多到一眼數不清時。"
        contrastWord = "Numerous"
        contrastNote = "<code>numerous</code> 是數量多；<code>myriad</code> 更像一整片鋪滿視野。"
        neighborMeaning = "很多、數量可觀"
        neighborUse = "若只要平實地說數量多，用 <code>numerous</code> 就夠。"
        flow = @("數量不只幾個", "一個接一個冒出來", "視野被整片鋪滿")
        hook = "把 <code>myriad</code> 想成不是幾盞燈，而是一整面夜景同時亮起。"
        hookExplanation = "它帶來的不是精算，而是量感鋪開的視覺衝擊。"
        usage = @(
            [ordered]@{ label = "原因"; body = "There are <code>myriad</code> reasons a migration can stall after kickoff." },
            [ordered]@{ label = "選項"; body = "Users face <code>myriad</code> choices before they even reach the core action." }
        )
        collocations = @(
            [ordered]@{ phrase = "myriad reasons"; register = "分析 / 寫作" },
            [ordered]@{ phrase = "myriad forms"; register = "評論 / 描述" }
        )
        modernUse = @(
            "<code>myriad</code> 常見於評論、學術與正式寫作，用來把「數量很多」寫得更有鋪陳感。"
        )
    }
    [ordered]@{
        slug = "myopic"
        word = "Myopic"
        partOfSpeech = "adjective"
        pronunciation = "my-OP-ik · UK /maɪˈɒp.ɪk/ · US /maɪˈɑː.pɪk/"
        cefr = "C1"
        zipf = "2.67"
        thesis = "不是看不到，而是只看得到眼前那一小段。"
        selfMeaning = "目光短淺"
        selfUse = "用在決策只顧眼前利益、忽略長線後果時。"
        contrastWord = "Short-term"
        contrastNote = "<code>short-term</code> 可以只是時間尺度；<code>myopic</code> 帶有判斷視野過窄的批評。"
        neighborMeaning = "只談短期安排"
        neighborUse = "若只是描述時程長短，不必批評視野，用 <code>short-term</code> 即可。"
        flow = @("只盯著眼前", "忽略遠處後果", "後續代價慢慢浮現")
        hook = "把 <code>myopic</code> 想成手電筒只照腳邊，前方路線整段留黑。"
        hookExplanation = "這個字的力度在於它批評的不只是短，而是短到不成比例。"
        usage = @(
            [ordered]@{ label = "策略"; body = "Cutting reliability work to hit one quarter of growth is a <code>myopic</code> move." },
            [ordered]@{ label = "管理"; body = "A <code>myopic</code> focus on output can quietly erode trust and learning." }
        )
        collocations = @(
            [ordered]@{ phrase = "myopic decision"; register = "策略 / 管理" },
            [ordered]@{ phrase = "myopic policy"; register = "政策 / 評論" }
        )
        modernUse = @(
            "<code>myopic</code> 在商業與公共討論裡常用來批評只顧短線數字、卻把長線風險往後丟的做法。"
        )
    }
    [ordered]@{
        slug = "nascent"
        word = "Nascent"
        partOfSpeech = "adjective"
        pronunciation = "NAY-suhnt · UK /ˈneɪ.sənt/ · US /ˈneɪ.sənt/"
        cefr = "C1"
        zipf = "2.68"
        thesis = "不是新，而是剛開始成形，還很脆弱。"
        selfMeaning = "初生未穩"
        selfUse = "用在新興產業、想法、習慣或制度剛冒出輪廓時。"
        contrastWord = "Emerging"
        contrastNote = "<code>emerging</code> 偏正在出現；<code>nascent</code> 更強調剛萌芽、還很脆弱。"
        neighborMeaning = "正在浮出水面"
        neighborUse = "若只想說正在出現，不特別強調脆弱期，用 <code>emerging</code> 更自然。"
        flow = @("剛冒出輪廓", "結構還不穩", "一碰就可能改形")
        hook = "把 <code>nascent</code> 想成剛破土的芽，已經出現，但還很容易折。"
        hookExplanation = "這個字的重點不是新鮮感，而是剛成形時那種未定與脆弱。"
        usage = @(
            [ordered]@{ label = "產業"; body = "The company entered a <code>nascent</code> market before standards had settled." },
            [ordered]@{ label = "習慣"; body = "A <code>nascent</code> writing routine needs protection before it can become durable." }
        )
        collocations = @(
            [ordered]@{ phrase = "nascent industry"; register = "商業 / 經濟" },
            [ordered]@{ phrase = "nascent stage"; register = "研究 / 分析" }
        )
        modernUse = @(
            "<code>nascent</code> 很常出現在新創、研究與制度討論裡，提醒你：這東西不是成熟前夜，而是還在萌芽期。"
        )
    }
    [ordered]@{
        slug = "nebulous"
        word = "Nebulous"
        partOfSpeech = "adjective"
        pronunciation = "NEB-yuh-lus · UK /ˈneb.jə.ləs/ · US /ˈneb.jə.ləs/"
        cefr = "C1"
        zipf = "2.63"
        thesis = "不是模糊，而是邊界像霧一樣抓不住。"
        selfMeaning = "邊界霧化"
        selfUse = "用在概念、責任、目標或規範沒有清楚邊界時。"
        contrastWord = "Vague"
        contrastNote = "<code>vague</code> 是說得不清楚；<code>nebulous</code> 更像整個輪廓本身散掉。"
        neighborMeaning = "表述不夠清楚"
        neighborUse = "若重點只是描述含糊，用 <code>vague</code> 足夠。"
        flow = @("輪廓先浮出", "邊界開始散開", "你很難畫出清楚外框")
        hook = "把 <code>nebulous</code> 想成霧裡的建築，知道它在那裡，卻抓不準邊線。"
        hookExplanation = "這個字的模糊感是形狀本身鬆掉，而不只是資訊不完整。"
        usage = @(
            [ordered]@{ label = "目標"; body = "The roadmap felt <code>nebulous</code> because no one could define success in operational terms." },
            [ordered]@{ label = "責任"; body = "Ownership stayed <code>nebulous</code> after the reorganization." }
        )
        collocations = @(
            [ordered]@{ phrase = "nebulous concept"; register = "學術 / 設計" },
            [ordered]@{ phrase = "nebulous goal"; register = "管理 / 產品" }
        )
        modernUse = @(
            "<code>nebulous</code> 很適合用來批評抽象討論沒有落成可操作輪廓，尤其在需求與策略文件裡。"
        )
    }
    [ordered]@{
        slug = "nefarious"
        word = "Nefarious"
        partOfSpeech = "adjective"
        pronunciation = "nih-FAIR-ee-us · UK /nɪˈfeə.ri.əs/ · US /nəˈfer.i.əs/"
        cefr = "C2"
        zipf = "2.38"
        thesis = "不是不好，而是壞得帶惡意、帶陰影。"
        selfMeaning = "陰狠邪惡"
        selfUse = "用在人、計畫或行動不只是有問題，而是帶明顯惡意時。"
        contrastWord = "Sinister"
        contrastNote = "<code>sinister</code> 偏不祥或讓人發毛；<code>nefarious</code> 更直接指出道德上的惡。"
        neighborMeaning = "讓人覺得不祥或陰森"
        neighborUse = "若重點是氛圍詭異、不安，用 <code>sinister</code> 更合適。"
        flow = @("意圖本身有惡意", "手段不只是灰色", "結果帶來實際傷害")
        hook = "把 <code>nefarious</code> 想成不是躲在暗處而已，而是暗處裡真的藏著刀。"
        hookExplanation = "這個字的力道很重，用上它通常代表你已經在做道德判斷。"
        usage = @(
            [ordered]@{ label = "計畫"; body = "The scam relied on a <code>nefarious</code> mix of fake urgency and forged trust." },
            [ordered]@{ label = "角色"; body = "He is not merely ambitious but <code>nefarious</code> in the way he targets the vulnerable." }
        )
        collocations = @(
            [ordered]@{ phrase = "nefarious scheme"; register = "報導 / 敘事" },
            [ordered]@{ phrase = "nefarious activity"; register = "法律 / 安全" }
        )
        modernUse = @(
            "<code>nefarious</code> 常用在犯罪、陰謀與道德評論裡，語氣比 bad 或 shady 重得多。"
        )
    }
    [ordered]@{
        slug = "negate"
        word = "Negate"
        partOfSpeech = "verb"
        pronunciation = "nih-GAYT · UK /nɪˈɡeɪt/ · US /nɪˈɡeɪt/"
        cefr = "C1"
        zipf = "2.87"
        thesis = "不是反對，而是把效果直接抵掉。"
        selfMeaning = "抵消作廢"
        selfUse = "用在某個條件、行動或發現讓原本的效果不再成立時。"
        contrastWord = "Deny"
        contrastNote = "<code>deny</code> 是否認；<code>negate</code> 是把效果、價值或結果抵掉。"
        neighborMeaning = "口頭上否認某件事"
        neighborUse = "若重點是立場否認，而不是效果被抵銷，用 <code>deny</code> 更準。"
        flow = @("原本有作用", "另一股條件介入", "效果被整體抵掉")
        hook = "把 <code>negate</code> 想成一個數字前面被放上負號，整個方向翻掉。"
        hookExplanation = "它關心的是結果失效，而不是誰在吵架。"
        usage = @(
            [ordered]@{ label = "效果"; body = "A noisy baseline can <code>negate</code> the value of an otherwise clever optimization." },
            [ordered]@{ label = "規則"; body = "One undocumented exception can <code>negate</code> months of training." }
        )
        collocations = @(
            [ordered]@{ phrase = "negate the benefit"; register = "分析 / 管理" },
            [ordered]@{ phrase = "negate the effect"; register = "技術 / 研究" }
        )
        modernUse = @(
            "<code>negate</code> 在工程、研究與政策寫作裡很實用，因為它精準描述『不是沒有，而是被抵掉』。"
        )
    }
    [ordered]@{
        slug = "nettle"
        word = "Nettle"
        partOfSpeech = "verb"
        pronunciation = "NET-uhl · UK /ˈnet.əl/ · US /ˈnet̬.əl/"
        cefr = "C2"
        zipf = "2.33"
        thesis = "不是一般冒犯，而是刺得人心裡發癢又發火。"
        selfMeaning = "刺得惱火"
        selfUse = "用在話語或舉動讓人煩躁、被刺到、難以平靜時。"
        contrastWord = "Irritate"
        contrastNote = "<code>irritate</code> 比較平；<code>nettle</code> 更像被帶刺的東西扎到。"
        neighborMeaning = "惹得不耐煩或不舒服"
        neighborUse = "若只要一般『惹煩』，用 <code>irritate</code> 即可。"
        flow = @("先被刺到一下", "心裡開始發癢發火", "情緒卡著不好消")
        hook = "把 <code>nettle</code> 想成衣服裡掉進細小刺草，不大，卻一直讓你坐立難安。"
        hookExplanation = "這個字的火氣不是爆炸型，而是持續扎著你的那種惱。"
        usage = @(
            [ordered]@{ label = "評論"; body = "The patronizing tone <code>nettled</code> the team more than the rejection itself." },
            [ordered]@{ label = "人際"; body = "He was visibly <code>nettled</code> by the suggestion that his work lacked rigor." }
        )
        collocations = @(
            [ordered]@{ phrase = "nettle the audience"; register = "評論 / 媒體" },
            [ordered]@{ phrase = "nettled by the remark"; register = "人際 / 敘事" }
        )
        modernUse = @(
            "<code>nettle</code> 在現代寫作裡不算高頻，但很適合捕捉那種『被刺到、不是大怒卻一直不舒服』的情緒。"
        )
    }
    [ordered]@{
        slug = "nexus"
        word = "Nexus"
        partOfSpeech = "noun"
        pronunciation = "NEK-sus · UK /ˈnek.səs/ · US /ˈnek.səs/"
        cefr = "B2"
        zipf = "3.18"
        thesis = "不是單純連接，而是多條線真正交會的樞紐點。"
        selfMeaning = "交會樞紐"
        selfUse = "用在多種力量、系統或議題不是並列，而是在一點上纏到一起時。"
        contrastWord = "Link"
        contrastNote = "<code>link</code> 是一條連線；<code>nexus</code> 更像多條線真正交會成樞紐。"
        neighborMeaning = "單一連接或關聯"
        neighborUse = "若只是 A 和 B 之間有關聯，用 <code>link</code> 就夠。"
        flow = @("不只兩條線", "多股因素交會", "某一點成為樞紐")
        hook = "把 <code>nexus</code> 想成地鐵換乘站，不是一條線，而是多條線都在那裡撞上。"
        hookExplanation = "這個字會把複數關係壓縮成一個中心交點。"
        usage = @(
            [ordered]@{ label = "政策"; body = "Housing sits at the <code>nexus</code> of wages, zoning, transit, and care work." },
            [ordered]@{ label = "工程"; body = "The incident was caused by a <code>nexus</code> of timing bugs rather than one isolated fault." }
        )
        collocations = @(
            [ordered]@{ phrase = "nexus of issues"; register = "分析 / 政策" },
            [ordered]@{ phrase = "causal nexus"; register = "法律 / 研究" }
        )
        modernUse = @(
            "<code>nexus</code> 很適合寫系統問題，因為它讓你強調的不是一條因果，而是交會點本身。"
        )
    }
    [ordered]@{
        slug = "nimble"
        word = "Nimble"
        partOfSpeech = "adjective"
        pronunciation = "NIM-buhl · UK /ˈnɪm.bəl/ · US /ˈnɪm.bəl/"
        cefr = "B2"
        zipf = "3.33"
        thesis = "不是快而已，而是轉向也快。"
        selfMeaning = "靈活敏捷"
        selfUse = "用在人、團隊或系統能迅速調整步伐與方向時。"
        contrastWord = "Agile"
        contrastNote = "<code>agile</code> 常可指方法或流程；<code>nimble</code> 更突出身段與反應的輕快。"
        neighborMeaning = "流程或方法上能快速迭代"
        neighborUse = "若重點是方法論與節奏，用 <code>agile</code> 更常見。"
        flow = @("感知變化快", "轉向成本低", "動作順而不笨重")
        hook = "把 <code>nimble</code> 想成腳步輕的人，不只是跑得快，而是轉彎也不拖泥帶水。"
        hookExplanation = "它把速度和轉向能力綁在一起。"
        usage = @(
            [ordered]@{ label = "團隊"; body = "A <code>nimble</code> team can change sequencing without losing the bigger thread." },
            [ordered]@{ label = "產品"; body = "The startup stayed <code>nimble</code> by keeping decision paths short." }
        )
        collocations = @(
            [ordered]@{ phrase = "nimble team"; register = "管理 / 產品" },
            [ordered]@{ phrase = "nimble response"; register = "營運 / 服務" }
        )
        modernUse = @(
            "<code>nimble</code> 在產品與組織語境裡常用來稱讚反應快又不笨重的能力，比 simply fast 更立體。"
        )
    }
    [ordered]@{
        slug = "nomadic"
        word = "Nomadic"
        partOfSpeech = "adjective"
        pronunciation = "noh-MAD-ik · UK /nəʊˈmæd.ɪk/ · US /noʊˈmæd.ɪk/"
        cefr = "C1"
        zipf = "2.56"
        thesis = "不是愛旅行，而是沒有長久固定駐點。"
        selfMeaning = "遷移不定"
        selfUse = "用在生活、工作或文化形態不長期固定於同一處時。"
        contrastWord = "Mobile"
        contrastNote = "<code>mobile</code> 是可移動；<code>nomadic</code> 更像生活方式本身在遷徙。"
        neighborMeaning = "可移動、可攜、可換位置"
        neighborUse = "若只談裝置或人能移動，用 <code>mobile</code> 比較中性。"
        flow = @("不長久定居", "位置持續變動", "遷移成為常態")
        hook = "把 <code>nomadic</code> 想成家不是一個地址，而是一種持續搬動的生活節奏。"
        hookExplanation = "這個字的焦點是『定點』被拿掉之後，人怎麼生活。"
        usage = @(
            [ordered]@{ label = "工作"; body = "His <code>nomadic</code> schedule made deep routine harder than he expected." },
            [ordered]@{ label = "文化"; body = "The book traces how <code>nomadic</code> traditions adapt to modern borders." }
        )
        collocations = @(
            [ordered]@{ phrase = "nomadic lifestyle"; register = "生活 / 報導" },
            [ordered]@{ phrase = "nomadic culture"; register = "歷史 / 人類學" }
        )
        modernUse = @(
            "<code>nomadic</code> 現在除了歷史與文化，也常拿來寫數位工作者與流動辦公，但語氣仍比 mobile 更有生活型態感。"
        )
    }
    [ordered]@{
        slug = "nonchalant"
        word = "Nonchalant"
        partOfSpeech = "adjective"
        pronunciation = "non-shuh-LAHNT · UK /ˈnɒn.ʃəl.ənt/ · US /ˌnɑːn.ʃəˈlɑːnt/"
        cefr = "C1"
        zipf = "2.73"
        thesis = "不是冷，而是像什麼都沒太放在心上。"
        selfMeaning = "漫不經心"
        selfUse = "用在人表面不慌不忙、帶點不在乎或故作輕鬆時。"
        contrastWord = "Calm"
        contrastNote = "<code>calm</code> 可以是真正平穩；<code>nonchalant</code> 常多一層『好像沒那麼在乎』。"
        neighborMeaning = "平穩、不驚慌"
        neighborUse = "若只是鎮定而不帶態度感，用 <code>calm</code> 更中性。"
        flow = @("局勢可能有重量", "表面卻很輕", "態度像沒被真正拉進去")
        hook = "把 <code>nonchalant</code> 想成火警旁邊還慢慢抖袖口的人。"
        hookExplanation = "這個字常在鎮定和不在乎之間留下一點曖昧。"
        usage = @(
            [ordered]@{ label = "人際"; body = "He gave a <code>nonchalant</code> shrug, but the room could tell he had prepared for this." },
            [ordered]@{ label = "風格"; body = "The performance feels <code>nonchalant</code> on the surface and tightly controlled underneath." }
        )
        collocations = @(
            [ordered]@{ phrase = "nonchalant shrug"; register = "敘事 / 人際" },
            [ordered]@{ phrase = "nonchalant attitude"; register = "評論 / 描述" }
        )
        modernUse = @(
            "<code>nonchalant</code> 常用來描寫一種刻意鬆鬆的表演感：人未必真的不在乎，但他想讓你以為他不在乎。"
        )
    }
    [ordered]@{
        slug = "noxious"
        word = "Noxious"
        partOfSpeech = "adjective"
        pronunciation = "NOK-shus · UK /ˈnɒk.ʃəs/ · US /ˈnɑːk.ʃəs/"
        cefr = "C2"
        zipf = "2.29"
        thesis = "不是難聞而已，而是有害到應該避開。"
        selfMeaning = "有毒有害"
        selfUse = "用在氣體、環境、言論或影響不只是 unpleasant，而是真的傷人時。"
        contrastWord = "Toxic"
        contrastNote = "<code>toxic</code> 現代用法很廣；<code>noxious</code> 更書面，也更帶生理或制度性傷害感。"
        neighborMeaning = "有毒、惡劣、造成傷害"
        neighborUse = "若要較口語或廣泛的傷害感，用 <code>toxic</code> 更常見。"
        flow = @("先讓人不舒服", "進一步造成傷害", "接近必須避開的程度")
        hook = "把 <code>noxious</code> 想成不是臭味而已，而是你吸久了真的會受傷。"
        hookExplanation = "這個字比 unpleasant 更重，因為它把危害感一起寫進去。"
        usage = @(
            [ordered]@{ label = "環境"; body = "Workers were exposed to <code>noxious</code> fumes after the leak." },
            [ordered]@{ label = "文化"; body = "A <code>noxious</code> blame culture can make honest reporting almost impossible." }
        )
        collocations = @(
            [ordered]@{ phrase = "noxious fumes"; register = "安全 / 環境" },
            [ordered]@{ phrase = "noxious influence"; register = "評論 / 社會" }
        )
        modernUse = @(
            "<code>noxious</code> 在現代寫作裡可用於物理危害，也能延伸到制度與文化上的傷害，語氣比 toxic 更書面。"
        )
    }
    [ordered]@{
        slug = "obdurate"
        word = "Obdurate"
        partOfSpeech = "adjective"
        pronunciation = "OB-dyuh-rət · UK /ˈɒb.djʊ.rət/ · US /ˈɑːb.dɚ.ət/"
        cefr = "C2"
        zipf = "2.24"
        thesis = "不是堅定，而是硬到怎麼勸都不鬆。"
        selfMeaning = "頑固不化"
        selfUse = "用在人明知壓力或道理存在，仍拒絕鬆動時。"
        contrastWord = "Stubborn"
        contrastNote = "<code>stubborn</code> 可以只是固執；<code>obdurate</code> 更有冷硬、拒絕被打動的感覺。"
        neighborMeaning = "固執、不肯改變"
        neighborUse = "若只要一般固執，用 <code>stubborn</code> 就夠；<code>obdurate</code> 更重。"
        flow = @("立場先鎖死", "外界勸說進不去", "態度維持冷硬")
        hook = "把 <code>obdurate</code> 想成曬乾的泥，不只是硬，還不肯再回軟。"
        hookExplanation = "這個字的關鍵不是有原則，而是連該有的柔軟度都拿掉了。"
        usage = @([ordered]@{ label = "談判"; body = "談判桌上一方明明知道代價，卻還是維持 <code>obdurate</code> 的姿態。"}, [ordered]@{ label = "人際"; body = "當一個人連明確傷害都不願承認時，<code>obdurate</code> 就比 simply stubborn 更準。"})
        collocations = @([ordered]@{ phrase = "obdurate refusal"; register = "政治 / 法律" }, [ordered]@{ phrase = "obdurate attitude"; register = "評論 / 人際" })
        modernUse = @("在現代評論裡，<code>obdurate</code> 常用來批評掌權者或決策者明知後果仍不鬆口的冷硬。")
    }
    [ordered]@{
        slug = "oblique"
        word = "Oblique"
        partOfSpeech = "adjective"
        pronunciation = "uh-BLEEK · UK /əˈbliːk/ · US /əˈbliːk/"
        cefr = "C1"
        zipf = "2.71"
        thesis = "不是側面而已，而是故意不正面進去。"
        selfMeaning = "斜切繞入"
        selfUse = "用在說法、暗示或角度不直接、而是斜著靠近時。"
        contrastWord = "Indirect"
        contrastNote = "<code>indirect</code> 是不直接；<code>oblique</code> 更像刻意斜切、留下角度。"
        neighborMeaning = "不直接、不是正面說"
        neighborUse = "若只要一般的婉轉或非直述，用 <code>indirect</code> 就夠。"
        flow = @("不從正面進場", "改走斜角靠近", "真正意思藏在側面")
        hook = "把 <code>oblique</code> 想成不是敲正門，而是從側窗把訊號丟進來。"
        hookExplanation = "這個字有一種刻意避開正面衝撞的角度感。"
        usage = @([ordered]@{ label = "說法"; body = "他沒有點名，只留下幾個 <code>oblique</code> 的暗示讓全場自己對號入座。"}, [ordered]@{ label = "分析"; body = "有些評論不是直接反對，而是用 <code>oblique</code> 的角度慢慢削弱前提。"})
        collocations = @([ordered]@{ phrase = "oblique reference"; register = "寫作 / 評論" }, [ordered]@{ phrase = "oblique angle"; register = "技術 / 視覺" })
        modernUse = @("<code>oblique</code> 在現代寫作裡很適合描述那種不正面明說、卻又不是完全模糊的斜向表達。")
    }
    [ordered]@{
        slug = "oblivious"
        word = "Oblivious"
        partOfSpeech = "adjective"
        pronunciation = "uh-BLIV-ee-us · UK /əˈblɪv.i.əs/ · US /əˈblɪv.i.əs/"
        cefr = "C1"
        zipf = "3.02"
        thesis = "不是不知道，而是周圍訊號明明很大卻完全沒接到。"
        selfMeaning = "渾然不覺"
        selfUse = "用在人對明顯線索、氣氛或後果毫無感知時。"
        contrastWord = "Unaware"
        contrastNote = "<code>unaware</code> 是不知道；<code>oblivious</code> 更強，像整個人沒接收到外界訊號。"
        neighborMeaning = "不知道某件事"
        neighborUse = "若只是資訊沒有被告知，用 <code>unaware</code> 更中性。"
        flow = @("外界訊號已經存在", "本人完全沒接到", "行為照舊往前走")
        hook = "把 <code>oblivious</code> 想成耳機開到最大聲的人，身後整條街都在按喇叭。"
        hookExplanation = "它描述的不是知識缺口，而是感知斷線。"
        usage = @([ordered]@{ label = "氣氛"; body = "全場都已經沉下來，只有他還 <code>oblivious</code> 地照原本節奏開玩笑。"}, [ordered]@{ label = "風險"; body = "當系統警訊已經滿版卻還照舊部署時，那種 <code>oblivious</code> 特別危險。"})
        collocations = @([ordered]@{ phrase = "blissfully oblivious"; register = "口語 / 敘事" }, [ordered]@{ phrase = "oblivious to the risk"; register = "管理 / 安全" })
        modernUse = @("<code>oblivious</code> 很常用來寫人和環境脫節的尷尬，也常用於批評對風險沒有感知的決策。")
    }
    [ordered]@{
        slug = "obviate"
        word = "Obviate"
        partOfSpeech = "verb"
        pronunciation = "OB-vee-ayt · UK /ˈɒb.vi.eɪt/ · US /ˈɑːb.vi.eɪt/"
        cefr = "C2"
        zipf = "2.36"
        thesis = "不是解決，而是讓原本那一步根本不必做。"
        selfMeaning = "省去需求"
        selfUse = "用在某個設計、安排或條件讓另一個步驟變得不再需要時。"
        contrastWord = "Prevent"
        contrastNote = "<code>prevent</code> 是阻止事情發生；<code>obviate</code> 是讓需求本身消失。"
        neighborMeaning = "阻止問題發生"
        neighborUse = "若重點是攔下風險或事件，用 <code>prevent</code> 更直接。"
        flow = @("原本有一個需求", "另一路設計先處理掉", "那一步驟被整體省去")
        hook = "把 <code>obviate</code> 想成不是多派一個保全，而是改門禁到根本不需要站人。"
        hookExplanation = "它描述的是需求被架構性拿掉，而不是工作做得更辛苦。"
        usage = @([ordered]@{ label = "設計"; body = "把資料在源頭校正好，就能 <code>obviate</code> 一整串後端補救流程。"}, [ordered]@{ label = "流程"; body = "好的預設值常常不是修正錯誤，而是直接 <code>obviate</code> 錯誤出現的機會。"})
        collocations = @([ordered]@{ phrase = "obviate the need"; register = "技術 / 寫作" }, [ordered]@{ phrase = "obviate the problem"; register = "分析 / 管理" })
        modernUse = @("<code>obviate</code> 在工程與制度設計裡很有力，因為它強調『不是補救，而是把需求本身拿掉』。")
    }
    [ordered]@{
        slug = "onerous"
        word = "Onerous"
        partOfSpeech = "adjective"
        pronunciation = "ON-er-us · UK /ˈəʊ.nər.əs/ · US /ˈoʊ.nɚ.əs/"
        cefr = "C1"
        zipf = "2.61"
        thesis = "不是麻煩，而是負擔重到讓人明顯吃力。"
        selfMeaning = "負擔沉重"
        selfUse = "用在規定、要求或責任重到不成比例時。"
        contrastWord = "Demanding"
        contrastNote = "<code>demanding</code> 是要求高；<code>onerous</code> 更強調負擔壓得人喘不過氣。"
        neighborMeaning = "要求高、需要投入很多"
        neighborUse = "若只是高標準或很費工，用 <code>demanding</code> 比較常見。"
        flow = @("要求先落下來", "負擔越積越重", "執行的人開始被壓垮")
        hook = "把 <code>onerous</code> 想成背包不是多裝一本書，而是塞進整塊磚。"
        hookExplanation = "這個字在乎的是重量感，而不是單純不方便。"
        usage = @([ordered]@{ label = "制度"; body = "如果申請流程重到連懂規則的人都嫌累，那就是 <code>onerous</code>。"}, [ordered]@{ label = "團隊"; body = "把所有風險審查都壓在同一個人身上，會讓角色變得過度 <code>onerous</code>。"})
        collocations = @([ordered]@{ phrase = "onerous requirement"; register = "法律 / 制度" }, [ordered]@{ phrase = "onerous burden"; register = "政策 / 管理" })
        modernUse = @("<code>onerous</code> 很常用來批評不成比例的流程與規範，特別是在法規、合約與公共服務語境。")
    }
    [ordered]@{
        slug = "onslaught"
        word = "Onslaught"
        partOfSpeech = "noun"
        pronunciation = "ON-slawt · UK /ˈɒn.slɔːt/ · US /ˈɑːn.slɑːt/"
        cefr = "C1"
        zipf = "2.67"
        thesis = "不是一波攻擊，而是整面壓過來的猛衝。"
        selfMeaning = "猛烈衝擊"
        selfUse = "用在攻擊、批評、請求或資訊量突然整批壓上來時。"
        contrastWord = "Attack"
        contrastNote = "<code>attack</code> 是一次攻擊；<code>onslaught</code> 更像連續而兇猛的一整波。"
        neighborMeaning = "單次攻擊或出手"
        neighborUse = "若只描述一個明確動作，用 <code>attack</code> 就夠。"
        flow = @("不是一點點來", "整批壓上來", "人很快被衝擊淹過")
        hook = "把 <code>onslaught</code> 想成不是一滴雨，而是整面暴雨迎面打下來。"
        hookExplanation = "它帶的是量和力一起到位的壓迫感。"
        usage = @([ordered]@{ label = "資訊"; body = "版本一上線後，客服很快就迎來一波 <code>onslaught</code> of tickets。"}, [ordered]@{ label = "評論"; body = "如果批評不是零星，而是一整片壓過來，<code>onslaught</code> 的語感就很合適。"})
        collocations = @([ordered]@{ phrase = "an onslaught of criticism"; register = "媒體 / 評論" }, [ordered]@{ phrase = "military onslaught"; register = "新聞 / 歷史" })
        modernUse = @("<code>onslaught</code> 在現代英文裡不只用於戰爭，也常拿來寫工單、通知、批評或需求一次湧來的壓迫感。")
    }
    [ordered]@{
        slug = "opportune"
        word = "Opportune"
        partOfSpeech = "adjective"
        pronunciation = "op-er-TOON · UK /ˌɒp.əˈtʃuːn/ · US /ˌɑː.pɚˈtuːn/"
        cefr = "B2"
        zipf = "2.91"
        thesis = "不是好，而是剛好踩在最能發揮作用的時機點。"
        selfMeaning = "時機剛好"
        selfUse = "用在某個動作、消息或轉向出現在非常合適的時點時。"
        contrastWord = "Timely"
        contrastNote = "<code>timely</code> 是及時；<code>opportune</code> 更強調那個時機特別有利。"
        neighborMeaning = "來得及、沒有拖延"
        neighborUse = "若只要說沒有太晚，用 <code>timely</code> 就夠。"
        flow = @("時點不是隨便一刻", "情勢剛好打開", "動作的效力因此放大")
        hook = "把 <code>opportune</code> 想成不是趕上車，而是剛好趕上最後一班也最適合的車。"
        hookExplanation = "這個字把『時間』和『有利程度』綁在一起。"
        usage = @([ordered]@{ label = "決策"; body = "在對手剛暴露弱點時出手，會顯得特別 <code>opportune</code>。"}, [ordered]@{ label = "消息"; body = "有些公告不是單純及時，而是在情勢正需要時出現，因此很 <code>opportune</code>。"})
        collocations = @([ordered]@{ phrase = "opportune moment"; register = "商務 / 敘事" }, [ordered]@{ phrase = "opportune time"; register = "正式 / 分析" })
        modernUse = @("<code>opportune</code> 常出現在策略與商務寫作，因為它能精準表達『不只是及時，而是有利地及時』。")
    }
    [ordered]@{
        slug = "ornate"
        word = "Ornate"
        partOfSpeech = "adjective"
        pronunciation = "or-NAYT · UK /ɔːˈneɪt/ · US /ɔːrˈneɪt/"
        cefr = "C1"
        zipf = "2.58"
        thesis = "不是精緻而已，而是裝飾感明顯到成了主角。"
        selfMeaning = "繁飾華麗"
        selfUse = "用在建築、文字、風格或設計裝飾層很厚時。"
        contrastWord = "Elegant"
        contrastNote = "<code>elegant</code> 可以簡潔；<code>ornate</code> 則是裝飾本身很顯眼。"
        neighborMeaning = "優雅、講究、比例好"
        neighborUse = "若重點是節制後的美感，用 <code>elegant</code> 更貼近。"
        flow = @("裝飾越加越多", "細節開始搶眼", "整體呈現厚重華麗")
        hook = "把 <code>ornate</code> 想成一扇門上不是一圈雕花，而是整面都刻滿花紋。"
        hookExplanation = "它描述的是裝飾量感，不一定是在稱讚。"
        usage = @([ordered]@{ label = "風格"; body = "如果文字的修辭層層疊上去，讀者可能會覺得它過於 <code>ornate</code>。"}, [ordered]@{ label = "空間"; body = "有些餐廳不是舒適，而是用很 <code>ornate</code> 的細節營造氣派。"})
        collocations = @([ordered]@{ phrase = "ornate design"; register = "設計 / 評論" }, [ordered]@{ phrase = "ornate style"; register = "寫作 / 藝評" })
        modernUse = @("<code>ornate</code> 常用於評論視覺與文風，語氣介於欣賞與嫌太滿之間。")
    }
    [ordered]@{
        slug = "ossify"
        word = "Ossify"
        partOfSpeech = "verb"
        pronunciation = "OSS-uh-fy · UK /ˈɒs.ɪ.faɪ/ · US /ˈɑː.sə.faɪ/"
        cefr = "C2"
        zipf = "2.21"
        thesis = "不是穩定，而是硬化到再也轉不動。"
        selfMeaning = "僵化變硬"
        selfUse = "用在制度、文化或想法原本可調整，後來卻硬掉時。"
        contrastWord = "Stabilize"
        contrastNote = "<code>stabilize</code> 是穩定下來；<code>ossify</code> 則是穩到失去彈性。"
        neighborMeaning = "變得穩定、可預測"
        neighborUse = "若重點是建立秩序與穩定，不帶負面僵硬感，用 <code>stabilize</code> 即可。"
        flow = @("原本仍能調整", "規則慢慢硬掉", "最後連必要改動也進不去")
        hook = "把 <code>ossify</code> 想成不是乾掉，而是整塊變成骨頭。"
        hookExplanation = "這個字批評的是彈性被拿掉之後的硬化。"
        usage = @([ordered]@{ label = "制度"; body = "流程一旦被 KPI 鎖死，很容易從穩定走到 <code>ossify</code>。"}, [ordered]@{ label = "文化"; body = "團隊最怕的不是沒有規則，而是規則開始 <code>ossify</code> 到沒人敢改。"})
        collocations = @([ordered]@{ phrase = "ossify into dogma"; register = "評論 / 思想" }, [ordered]@{ phrase = "ossified bureaucracy"; register = "政治 / 管理" })
        modernUse = @("<code>ossify</code> 在制度、組織與思想批評裡很好用，因為它把『硬化』和『失去生命力』一起寫出來。")
    }
    [ordered]@{
        slug = "oust"
        word = "Oust"
        partOfSpeech = "verb"
        pronunciation = "OWST · UK /aʊst/ · US /aʊst/"
        cefr = "C1"
        zipf = "2.73"
        thesis = "不是離開，而是被人硬生生趕下位置。"
        selfMeaning = "趕下位置"
        selfUse = "用在某人從權力、職位或地盤被迫退出時。"
        contrastWord = "Remove"
        contrastNote = "<code>remove</code> 很中性；<code>oust</code> 強調被推出去、通常帶權力鬥爭。"
        neighborMeaning = "移除、撤掉、拿開"
        neighborUse = "若只是中性的人事調整，用 <code>remove</code> 就夠。"
        flow = @("原本握有位置", "外力開始推擠", "最後被迫退出場內")
        hook = "把 <code>oust</code> 想成不是自己下車，而是被整個人擠出座位。"
        hookExplanation = "它把權力感和被迫性綁在一起。"
        usage = @([ordered]@{ label = "權力"; body = "董事會若主動把創辦人趕下台，最自然的動詞就是 <code>oust</code>。"}, [ordered]@{ label = "競爭"; body = "當新平台把舊玩家擠出主位時，也常會看到 <code>oust</code>。"})
        collocations = @([ordered]@{ phrase = "oust the leader"; register = "政治 / 商業" }, [ordered]@{ phrase = "oust from office"; register = "新聞 / 正式" })
        modernUse = @("<code>oust</code> 常出現在政治與董事會新聞裡，因為它比 remove 更有鬥爭與被逼退場的力道。")
    }
    [ordered]@{
        slug = "pacify"
        word = "Pacify"
        partOfSpeech = "verb"
        pronunciation = "PASS-uh-fy · UK /ˈpæs.ɪ.faɪ/ · US /ˈpæs.ə.faɪ/"
        cefr = "C1"
        zipf = "2.63"
        thesis = "不是說服，而是先把躁動壓到可控制。"
        selfMeaning = "平息躁動"
        selfUse = "用在人群、衝突或強烈情緒先被安撫下來時。"
        contrastWord = "Mollify"
        contrastNote = "<code>mollify</code> 常安撫個別怒氣；<code>pacify</code> 可更大範圍地平息騷動。"
        neighborMeaning = "把火氣往下壓"
        neighborUse = "若重點是單一對象的怒氣被安撫，用 <code>mollify</code> 更貼切。"
        flow = @("局面先躁動", "力量把情緒往下壓", "場面恢復到可控")
        hook = "把 <code>pacify</code> 想成先把晃動的桌子壓住，事情才有辦法往下談。"
        hookExplanation = "它描述的是局勢降溫，而不一定代表真正和解。"
        usage = @([ordered]@{ label = "群體"; body = "當人群已經躁起來時，目標往往不是說服，而是先 <code>pacify</code>。"}, [ordered]@{ label = "衝突"; body = "有些承諾的功能不在解決問題，而在暫時 <code>pacify</code> 現場。"})
        collocations = @([ordered]@{ phrase = "pacify the crowd"; register = "公共 / 敘事" }, [ordered]@{ phrase = "pacify tensions"; register = "政治 / 人際" })
        modernUse = @("<code>pacify</code> 在公共事件、客服與衝突處理裡很常見，因為它準確描述『先平下來再說』。")
    }
    [ordered]@{
        slug = "palliate"
        word = "Palliate"
        partOfSpeech = "verb"
        pronunciation = "PAL-ee-ayt · UK /ˈpæl.i.eɪt/ · US /ˈpæl.i.eɪt/"
        cefr = "C2"
        zipf = "2.16"
        thesis = "不是根治，而是先減輕痛感。"
        selfMeaning = "緩和症狀"
        selfUse = "用在痛苦、衝擊或不適先被減輕，但根本問題仍在時。"
        contrastWord = "Cure"
        contrastNote = "<code>cure</code> 是根治；<code>palliate</code> 是先把症狀壓低。"
        neighborMeaning = "把問題真正治好"
        neighborUse = "若重點是源頭被解決，用 <code>cure</code> 或 solve 更正確。"
        flow = @("痛點先出現", "強度被壓低", "根本原因仍留在底下")
        hook = "把 <code>palliate</code> 想成不是補洞，而是先墊一層軟墊讓你不要那麼痛。"
        hookExplanation = "這個字提醒你：緩解不等於解決。"
        usage = @([ordered]@{ label = "醫療"; body = "有些處置不是根治，而是先 <code>palliate</code> 症狀，讓人撐得住。"}, [ordered]@{ label = "制度"; body = "若政策只是在短期內 <code>palliate</code> 焦慮，問題很快還會回來。"})
        collocations = @([ordered]@{ phrase = "palliate the pain"; register = "醫療 / 正式" }, [ordered]@{ phrase = "palliate the effects"; register = "政策 / 分析" })
        modernUse = @("<code>palliate</code> 雖然書面，但在醫療與政策語境裡很精準，因為它清楚分出緩解和根治。")
    }
    [ordered]@{
        slug = "palpable"
        word = "Palpable"
        partOfSpeech = "adjective"
        pronunciation = "PAL-puh-buhl · UK /ˈpæl.pə.bəl/ · US /ˈpæl.pə.bəl/"
        cefr = "C1"
        zipf = "2.86"
        thesis = "不是感覺得到，而是濃到幾乎可以摸到。"
        selfMeaning = "強烈可感"
        selfUse = "用在緊張、期待、怒氣或差異濃到充滿空間時。"
        contrastWord = "Noticeable"
        contrastNote = "<code>noticeable</code> 只是看得出來；<code>palpable</code> 更像整個空氣裡都有。"
        neighborMeaning = "能注意到、看得出來"
        neighborUse = "若只要說明顯，不必強調身體感，用 <code>noticeable</code> 即可。"
        flow = @("情緒或差異變濃", "整個空間被它填滿", "人幾乎能用身體感到")
        hook = "把 <code>palpable</code> 想成空氣濕到你伸手都像能抓下一層霧。"
        hookExplanation = "它把抽象的東西寫得像有觸感。"
        usage = @([ordered]@{ label = "氣氛"; body = "會議室裡若緊張濃到每個人都能用身體感到，就很適合用 <code>palpable</code>。"}, [ordered]@{ label = "差異"; body = "品質提升如果只是可見，用 noticeable；如果連體感都不同，就是 <code>palpable</code>。"})
        collocations = @([ordered]@{ phrase = "palpable tension"; register = "敘事 / 人際" }, [ordered]@{ phrase = "palpable relief"; register = "評論 / 敘事" })
        modernUse = @("<code>palpable</code> 很適合寫情緒或差異強到帶有體感的時刻，常見於評論、敘事與演講。")
    }
    [ordered]@{
        slug = "parity"
        word = "Parity"
        partOfSpeech = "noun"
        pronunciation = "PAIR-uh-tee · UK /ˈpær.ə.ti/ · US /ˈper.ə.t̬i/"
        cefr = "B2"
        zipf = "3.07"
        thesis = "不是相似，而是拉到同一個等級線上。"
        selfMeaning = "同等齊平"
        selfUse = "用在薪資、功能、品質或地位被拉到同一水平時。"
        contrastWord = "Equality"
        contrastNote = "<code>equality</code> 偏平權與原則；<code>parity</code> 更像具體指標上的齊平。"
        neighborMeaning = "平等、平權、待遇一致"
        neighborUse = "若重點是價值與權利上的平等，用 <code>equality</code> 更合適。"
        flow = @("原本兩邊有落差", "差距被慢慢補上", "最後落在同一條線")
        hook = "把 <code>parity</code> 想成兩個儀表板的指針終於對齊。"
        hookExplanation = "它說的是可比較的齊平，而不是抽象上的公平感。"
        usage = @([ordered]@{ label = "產品"; body = "兩端功能做到 <code>parity</code>，使用者才不會被平台差異困住。"}, [ordered]@{ label = "薪資"; body = "談 <code>parity</code> 時，通常是在看具體的級距、不是只談理念。"})
        collocations = @([ordered]@{ phrase = "feature parity"; register = "產品 / 工程" }, [ordered]@{ phrase = "pay parity"; register = "職場 / 政策" })
        modernUse = @("<code>parity</code> 在產品、薪資與制度討論裡很常見，因為它把『同一標準線』說得很明確。")
    }
    [ordered]@{
        slug = "partisan"
        word = "Partisan"
        partOfSpeech = "adjective"
        pronunciation = "PAR-tuh-zən · UK /ˌpɑː.tɪˈzæn/ · US /ˈpɑːr.t̬ə.zən/"
        cefr = "C1"
        zipf = "2.76"
        thesis = "不是有立場，而是立場先選邊，再看事實。"
        selfMeaning = "偏派選邊"
        selfUse = "用在討論或機構先按陣營站位，而不是先看證據時。"
        contrastWord = "Biased"
        contrastNote = "<code>biased</code> 是有偏見；<code>partisan</code> 更明確地指向黨派或陣營站位。"
        neighborMeaning = "帶偏見、不夠公正"
        neighborUse = "若只是一般偏頗，不一定涉及陣營站位，用 <code>biased</code> 更自然。"
        flow = @("先有陣營身份", "判斷往己方傾斜", "事實被站位重新排序")
        hook = "把 <code>partisan</code> 想成球賽還沒開打，分數板就先被你偏向一邊。"
        hookExplanation = "這個字不只是說你有意見，而是說你先選隊。"
        usage = @([ordered]@{ label = "媒體"; body = "當一個平台每次都沿著同一陣營解讀事件時，讀者會覺得它很 <code>partisan</code>。"}, [ordered]@{ label = "討論"; body = "如果所有判斷都先問誰得利而不是什麼為真，討論就容易變得 <code>partisan</code>。"})
        collocations = @([ordered]@{ phrase = "partisan divide"; register = "政治 / 媒體" }, [ordered]@{ phrase = "partisan rhetoric"; register = "公共 / 評論" })
        modernUse = @("<code>partisan</code> 在現代公共討論裡很常見，尤其用來批評資訊被陣營邏輯綁死。")
    }
    [ordered]@{
        slug = "paucity"
        word = "Paucity"
        partOfSpeech = "noun"
        pronunciation = "PAW-suh-tee · UK /ˈpɔː.sə.ti/ · US /ˈpɑː.sə.t̬i/"
        cefr = "C2"
        zipf = "2.18"
        thesis = "不是少，而是少到你開始意識到缺口。"
        selfMeaning = "稀少短缺"
        selfUse = "用在證據、資源、人才或機會少到成問題時。"
        contrastWord = "Shortage"
        contrastNote = "<code>shortage</code> 偏實際缺貨；<code>paucity</code> 更書面，也可指抽象資源稀少。"
        neighborMeaning = "短缺、不夠用"
        neighborUse = "若是具體供應不足的問題，用 <code>shortage</code> 會更直接。"
        flow = @("原本期待會有更多", "實際數量明顯偏少", "缺口開始影響判斷與行動")
        hook = "把 <code>paucity</code> 想成抽屜一拉開，不是空，而是只剩幾張薄薄的紙。"
        hookExplanation = "它比 few 更有『這個少會造成後果』的味道。"
        usage = @([ordered]@{ label = "證據"; body = "如果資料少到不足以支撐結論，就可以說有 a <code>paucity</code> of evidence。"}, [ordered]@{ label = "人才"; body = "某些領域不是沒有候選人，而是有一種明顯的 <code>paucity</code>。"})
        collocations = @([ordered]@{ phrase = "paucity of evidence"; register = "研究 / 法律" }, [ordered]@{ phrase = "paucity of resources"; register = "政策 / 管理" })
        modernUse = @("<code>paucity</code> 雖然偏書面，但在研究、法規與評論裡很精準，因為它把『少到成問題』寫了出來。")
    }
    [ordered]@{
        slug = "peevish"
        word = "Peevish"
        partOfSpeech = "adjective"
        pronunciation = "PEE-vish · UK /ˈpiː.vɪʃ/ · US /ˈpiː.vɪʃ/"
        cefr = "C2"
        zipf = "2.22"
        thesis = "不是大怒，而是小小的不爽一直掛在臉上。"
        selfMeaning = "小氣惱躁"
        selfUse = "用在人因小事而煩、語氣發刺、情緒不耐時。"
        contrastWord = "Irritable"
        contrastNote = "<code>irritable</code> 是容易被惹毛；<code>peevish</code> 更像小小的不耐一路掛著。"
        neighborMeaning = "容易被惹煩"
        neighborUse = "若重點是體質上容易煩躁，用 <code>irritable</code> 更自然。"
        flow = @("事情不一定很大", "情緒開始發刺", "整個人透出小小的不耐")
        hook = "把 <code>peevish</code> 想成鞋裡卡了一顆沙，不致命，但每一步都讓你想皺眉。"
        hookExplanation = "這個字的火氣不大，卻會持續磨人。"
        usage = @([ordered]@{ label = "人際"; body = "有些人不是生氣，只是用很 <code>peevish</code> 的口氣把不耐煩全灑出來。"}, [ordered]@{ label = "狀態"; body = "睡不好時，人很容易為小事變得 <code>peevish</code>。"})
        collocations = @([ordered]@{ phrase = "peevish tone"; register = "人際 / 敘事" }, [ordered]@{ phrase = "peevish complaint"; register = "評論 / 口語" })
        modernUse = @("<code>peevish</code> 適合抓那種不算大怒、卻一直透出煩和刺的情緒層次。")
    }
    [ordered]@{
        slug = "perverse"
        word = "Perverse"
        partOfSpeech = "adjective"
        pronunciation = "per-VERS · UK /pəˈvɜːs/ · US /pɚˈvɝːs/"
        cefr = "C1"
        zipf = "2.54"
        thesis = "不是奇怪，而是故意往不該去的方向拗。"
        selfMeaning = "故意拗反"
        selfUse = "用在人偏偏往常理相反、甚至自損的方向走時。"
        contrastWord = "Contrary"
        contrastNote = "<code>contrary</code> 是唱反調；<code>perverse</code> 更強，像故意往壞方向拗。"
        neighborMeaning = "愛反著來、愛唱反調"
        neighborUse = "若只是一般逆著別人說，用 <code>contrary</code> 即可。"
        flow = @("明明看得見更好的路", "卻故意往反方向扭", "結果常更壞")
        hook = "把 <code>perverse</code> 想成門明明往外推就開，卻偏偏硬往裡撞。"
        hookExplanation = "它帶著一點故意、甚至自找麻煩的味道。"
        usage = @([ordered]@{ label = "決策"; body = "如果制度獎勵的結果和原本目標相反，就常被說成帶有 <code>perverse</code> incentives。"}, [ordered]@{ label = "性格"; body = "有些人不是單純不合作，而是帶著一種 <code>perverse</code> 的拗勁。"})
        collocations = @([ordered]@{ phrase = "perverse incentive"; register = "政策 / 經濟" }, [ordered]@{ phrase = "perverse pleasure"; register = "評論 / 敘事" })
        modernUse = @("<code>perverse</code> 在制度與政策討論裡很常見，特別是拿來寫設計把人推向相反結果的時候。")
    }
    [ordered]@{
        slug = "perilous"
        word = "Perilous"
        partOfSpeech = "adjective"
        pronunciation = "PAIR-uh-lus · UK /ˈper.ɪ.ləs/ · US /ˈper.ə.ləs/"
        cefr = "C1"
        zipf = "2.66"
        thesis = "不是有風險，而是一步踩錯就可能出事。"
        selfMeaning = "危險懸邊"
        selfUse = "用在處境、路線或局勢危險度高、容錯很低時。"
        contrastWord = "Risky"
        contrastNote = "<code>risky</code> 是有風險；<code>perilous</code> 更像整個人站在邊緣。"
        neighborMeaning = "有風險、可能失敗"
        neighborUse = "若只是一般可能出錯，用 <code>risky</code> 就夠。"
        flow = @("局勢本來就不穩", "容錯空間很小", "一步偏掉就可能失控")
        hook = "把 <code>perilous</code> 想成站在濕滑山脊上，不是不能走，而是不能走錯。"
        hookExplanation = "它描述的是高危與低容錯同時存在。"
        usage = @([ordered]@{ label = "局勢"; body = "當現金流已經薄到見底，任何拖延都會讓局面變得更 <code>perilous</code>。"}, [ordered]@{ label = "選擇"; body = "有些 shortcut 看起來省事，其實只是把團隊帶進更 <code>perilous</code> 的位置。"})
        collocations = @([ordered]@{ phrase = "perilous situation"; register = "新聞 / 分析" }, [ordered]@{ phrase = "perilous path"; register = "敘事 / 隱喻" })
        modernUse = @("<code>perilous</code> 常用來把風險寫得更有懸崖感，特別適合財務、政治或安全語境。")
    }
    [ordered]@{
        slug = "pernicious"
        word = "Pernicious"
        partOfSpeech = "adjective"
        pronunciation = "per-NISH-us · UK /pəˈnɪʃ.əs/ · US /pɚˈnɪʃ.əs/"
        cefr = "C2"
        zipf = "2.34"
        thesis = "不是壞得明顯，而是壞得慢、深、難察覺。"
        selfMeaning = "隱蔽侵蝕"
        selfUse = "用在影響表面不轟烈，卻會慢慢侵蝕判斷、制度或健康時。"
        contrastWord = "Harmful"
        contrastNote = "<code>harmful</code> 是有害；<code>pernicious</code> 更像傷害悄悄滲進去。"
        neighborMeaning = "會造成傷害"
        neighborUse = "若只要一般有害，不特別強調隱蔽滲透感，用 <code>harmful</code> 即可。"
        flow = @("表面先不顯眼", "傷害慢慢滲入", "等看見時通常已經很深")
        hook = "把 <code>pernicious</code> 想成牆裡的濕氣，不是一下子倒，但會一直往裡面爛。"
        hookExplanation = "這個字的可怕在於它往往不是大張旗鼓地來。"
        usage = @([ordered]@{ label = "文化"; body = "某些看似無傷的小習慣，其實會很 <code>pernicious</code> 地侵蝕信任。"}, [ordered]@{ label = "觀念"; body = "最難處理的往往不是明顯錯誤，而是那種 <code>pernicious</code>、慢慢改寫判斷的前提。"})
        collocations = @([ordered]@{ phrase = "pernicious effect"; register = "正式 / 評論" }, [ordered]@{ phrase = "pernicious influence"; register = "社會 / 文化" })
        modernUse = @("<code>pernicious</code> 在制度、文化與健康語境都很有用，因為它能寫出那種慢慢侵蝕卻很難立刻抓到的壞。")
    }
    [ordered]@{
        slug = "placate"
        word = "Placate"
        partOfSpeech = "verb"
        pronunciation = "PLAY-kayt · UK /pləˈkeɪt/ · US /ˈpleɪ.keɪt/"
        cefr = "C1"
        zipf = "2.74"
        thesis = "不是解決，而是先把對方的不滿壓到不爆。"
        selfMeaning = "安撫降火"
        selfUse = "用在情緒先被安撫下來，好讓局面不立刻惡化時。"
        contrastWord = "Appease"
        contrastNote = "<code>appease</code> 可能更像讓步討好；<code>placate</code> 重點是把怒氣壓下來。"
        neighborMeaning = "靠讓步去安撫"
        neighborUse = "若重點是以讓步、妥協換安靜，用 <code>appease</code> 更貼近。"
        flow = @("不滿開始升高", "有人出手降火", "場面暫時穩住")
        hook = "把 <code>placate</code> 想成不是修好引擎，而是先把冒煙的地方蓋住。"
        hookExplanation = "這個字常暗示情緒先被處理，根本問題未必已解。"
        usage = @([ordered]@{ label = "客戶"; body = "有時回應的第一步不是修完，而是先 <code>placate</code> 對方失控的情緒。"}, [ordered]@{ label = "衝突"; body = "如果你只是需要先把火降下來，<code>placate</code> 會比 solve 更準。"})
        collocations = @([ordered]@{ phrase = "placate the customer"; register = "服務 / 商務" }, [ordered]@{ phrase = "placate public anger"; register = "公共 / 媒體" })
        modernUse = @("<code>placate</code> 很常出現在客服、政治與危機溝通語境，因為它直接面向『先把火降下來』。")
    }
    [ordered]@{
        slug = "pliable"
        word = "Pliable"
        partOfSpeech = "adjective"
        pronunciation = "PLY-uh-buhl · UK /ˈplaɪ.ə.bəl/ · US /ˈplaɪ.ə.bəl/"
        cefr = "C1"
        zipf = "2.53"
        thesis = "不是軟，而是可以彎、可以被塑形。"
        selfMeaning = "柔韌可塑"
        selfUse = "用在材質、安排或人容易被彎動、調整或塑形成別的樣子時。"
        contrastWord = "Flexible"
        contrastNote = "<code>flexible</code> 偏有彈性；<code>pliable</code> 更強調能被外力塑形。"
        neighborMeaning = "有彈性、好調整"
        neighborUse = "若只想說可調整，用 <code>flexible</code> 更中性。"
        flow = @("本身先不僵", "外力可以彎動它", "形狀或方向被改出來")
        hook = "把 <code>pliable</code> 想成還有溫度的金屬，不是融掉，但你可以把它彎出形。"
        hookExplanation = "它的重點是『可被塑形』，因此可好可壞。"
        usage = @([ordered]@{ label = "材質"; body = "材料若還保持 <code>pliable</code>，就代表它還能被加工。"}, [ordered]@{ label = "人際"; body = "形容人時，<code>pliable</code> 常帶一點容易受影響的味道。"})
        collocations = @([ordered]@{ phrase = "pliable material"; register = "製造 / 設計" }, [ordered]@{ phrase = "pliable mind"; register = "評論 / 人際" })
        modernUse = @("<code>pliable</code> 現代用法常跨在物理與人格之間，一邊是可加工，一邊是容易被帶走。")
    }
    [ordered]@{
        slug = "plight"
        word = "Plight"
        partOfSpeech = "noun"
        pronunciation = "PLYT · UK /plaɪt/ · US /plaɪt/"
        cefr = "C1"
        zipf = "2.75"
        thesis = "不是問題，而是已經陷進去的困境。"
        selfMeaning = "困境處境"
        selfUse = "用在某人或某群體被卡在艱難、令人同情的處境裡時。"
        contrastWord = "Problem"
        contrastNote = "<code>problem</code> 可以很抽象；<code>plight</code> 更強調人已經身在其中。"
        neighborMeaning = "需要解決的一個問題"
        neighborUse = "若只是一般待解決事項，用 <code>problem</code> 就夠。"
        flow = @("情況先惡化", "人被困在裡面", "處境開始令人同情或擔心")
        hook = "把 <code>plight</code> 想成不是地圖上的障礙，而是人已經站在坑裡。"
        hookExplanation = "這個字把抽象問題轉成具體的人身處境。"
        usage = @([ordered]@{ label = "群體"; body = "談難民、債務人或基層工作者時，<code>plight</code> 常用來凸顯他們身處的困境。"}, [ordered]@{ label = "敘事"; body = "如果重點是人已經陷在局裡，而不是外部觀察一個問題，<code>plight</code> 很好用。"})
        collocations = @([ordered]@{ phrase = "economic plight"; register = "政策 / 社會" }, [ordered]@{ phrase = "plight of workers"; register = "報導 / 評論" })
        modernUse = @("<code>plight</code> 常見於公共議題寫作，因為它讓讀者直視『有人正在那個困境裡』。")
    }
    [ordered]@{
        slug = "plummet"
        word = "Plummet"
        partOfSpeech = "verb"
        pronunciation = "PLUM-it · UK /ˈplʌm.ɪt/ · US /ˈplʌm.ət/"
        cefr = "C1"
        zipf = "2.84"
        thesis = "不是下降，而是往下掉得又快又狠。"
        selfMeaning = "急墜下滑"
        selfUse = "用在價格、信心、溫度或數據快速往下掉時。"
        contrastWord = "Decline"
        contrastNote = "<code>decline</code> 可以慢慢降；<code>plummet</code> 有一種失重直落感。"
        neighborMeaning = "逐步下降"
        neighborUse = "若變化是緩慢或長期趨勢，用 <code>decline</code> 更自然。"
        flow = @("先往下走", "速度突然加快", "很快掉到低點")
        hook = "把 <code>plummet</code> 想成不是滑坡，而是電梯斷線。"
        hookExplanation = "這個字的速度感非常強，幾乎總伴隨驚嚇。"
        usage = @([ordered]@{ label = "數據"; body = "如果留存率在一週內直直掉下去，<code>plummet</code> 的力道就很對。"}, [ordered]@{ label = "情緒"; body = "有些消息不只是讓士氣下降，而是讓它瞬間 <code>plummet</code>。"})
        collocations = @([ordered]@{ phrase = "plummet in value"; register = "商業 / 財經" }, [ordered]@{ phrase = "temperatures plummet"; register = "新聞 / 日常" })
        modernUse = @("<code>plummet</code> 在數據、財務與新聞語境很常見，因為它把『快速下墜』寫得很有畫面。")
    }
    [ordered]@{
        slug = "portent"
        word = "Portent"
        partOfSpeech = "noun"
        pronunciation = "POR-tent · UK /ˈpɔː.tent/ · US /ˈpɔːr.tent/"
        cefr = "C2"
        zipf = "2.07"
        thesis = "不是預告，而是帶不祥意味的前兆。"
        selfMeaning = "不祥前兆"
        selfUse = "用在某個跡象像是在替更大的變化投下陰影時。"
        contrastWord = "Sign"
        contrastNote = "<code>sign</code> 很中性；<code>portent</code> 更像帶著重量和不安的徵候。"
        neighborMeaning = "一般訊號或跡象"
        neighborUse = "若只是中性的徵兆，不帶陰影感，用 <code>sign</code> 即可。"
        flow = @("先冒出一個跡象", "它帶著陰影感", "人開始聯想到更大的事要來")
        hook = "把 <code>portent</code> 想成天色突然壓暗，不是事情已發生，但你知道快了。"
        hookExplanation = "它的核心不是預測準確，而是氣氛已經先告訴你不妙。"
        usage = @([ordered]@{ label = "敘事"; body = "小說裡一個小徵候如果後面會引出大災難，就很像 a <code>portent</code>。"}, [ordered]@{ label = "評論"; body = "某些政策轉向不只是 news，而會被看成更大變化的 <code>portent</code>。"})
        collocations = @([ordered]@{ phrase = "dark portent"; register = "文學 / 敘事" }, [ordered]@{ phrase = "a portent of change"; register = "評論 / 正式" })
        modernUse = @("<code>portent</code> 雖然偏文學，但在正式評論裡仍能用來寫那些讓人起警覺的前兆。")
    }
    [ordered]@{
        slug = "potent"
        word = "Potent"
        partOfSpeech = "adjective"
        pronunciation = "POH-tent · UK /ˈpəʊ.tənt/ · US /ˈpoʊ.tənt/"
        cefr = "B2"
        zipf = "3.12"
        thesis = "不是強，而是小小一點就有很大作用。"
        selfMeaning = "效力很強"
        selfUse = "用在藥物、訊號、象徵或說法力量濃度很高時。"
        contrastWord = "Powerful"
        contrastNote = "<code>powerful</code> 是大而強；<code>potent</code> 更像濃度高、作用猛。"
        neighborMeaning = "強大、有力量"
        neighborUse = "若只是一般強，用 <code>powerful</code> 更通用。"
        flow = @("份量不一定大", "作用卻很集中", "效果很快被感到")
        hook = "把 <code>potent</code> 想成一小滴濃縮液，量不多，後勁卻很重。"
        hookExplanation = "這個字在乎的是效力密度。"
        usage = @([ordered]@{ label = "說法"; body = "一句話如果短，但打中要害，就可以說它很 <code>potent</code>。"}, [ordered]@{ label = "象徵"; body = "有些意象不需要鋪很大，卻因為夠 <code>potent</code> 而記得住。"})
        collocations = @([ordered]@{ phrase = "potent symbol"; register = "評論 / 文化" }, [ordered]@{ phrase = "potent drug"; register = "醫療 / 科學" })
        modernUse = @("<code>potent</code> 在藥物、政治象徵與修辭評論都常見，因為它能把『濃度型的強』說清楚。")
    }
    [ordered]@{
        slug = "preclude"
        word = "Preclude"
        partOfSpeech = "verb"
        pronunciation = "pri-KLOOD · UK /prɪˈkluːd/ · US /prɪˈkluːd/"
        cefr = "C1"
        zipf = "2.68"
        thesis = "不是晚了一步，而是一開始就把路堵住。"
        selfMeaning = "事先排除"
        selfUse = "用在某條件從一開始就讓另一種可能無法成立時。"
        contrastWord = "Prevent"
        contrastNote = "<code>prevent</code> 是阻止發生；<code>preclude</code> 更像前提直接把可能性封掉。"
        neighborMeaning = "攔住事情不要發生"
        neighborUse = "若重點是行動上的阻止，用 <code>prevent</code> 更直白。"
        flow = @("前提先設定好", "可能性被堵住", "後續選項直接被排除")
        hook = "把 <code>preclude</code> 想成門還沒打開，門把就已經被拆掉。"
        hookExplanation = "它強調的是可能性先被封死，而不是過程中失敗。"
        usage = @([ordered]@{ label = "前提"; body = "有些限制不是讓你更難做，而是直接 <code>preclude</code> 某些方案。"}, [ordered]@{ label = "制度"; body = "如果資料權限一開始就沒開，那就已經 <code>preclude</code> 後面的分析了。"})
        collocations = @([ordered]@{ phrase = "preclude the possibility"; register = "正式 / 分析" }, [ordered]@{ phrase = "preclude access"; register = "法律 / 制度" })
        modernUse = @("<code>preclude</code> 在合約、政策與設計約束裡很精準，因為它說的是可能性被前提先封死。")
    }
    [ordered]@{
        slug = "precursor"
        word = "Precursor"
        partOfSpeech = "noun"
        pronunciation = "pree-KER-ser · UK /priːˈkɜː.sə/ · US /priːˈkɝː.sɚ/"
        cefr = "C1"
        zipf = "2.74"
        thesis = "不是前面那個，而是後面那件事的先行版本或徵候。"
        selfMeaning = "先行前驅"
        selfUse = "用在某事物先出現，並替後續更成熟或更大的東西鋪路時。"
        contrastWord = "Prototype"
        contrastNote = "<code>prototype</code> 偏具體原型；<code>precursor</code> 可是前身、前兆或前驅。"
        neighborMeaning = "可實際拿來試的早期原型"
        neighborUse = "若重點是開發中的試作品，用 <code>prototype</code> 更貼切。"
        flow = @("先有一個早期形態", "後面的大東西逐步長出", "回頭看才知道它是前驅")
        hook = "把 <code>precursor</code> 想成不是完整建築，而是地上先打下去的樁。"
        hookExplanation = "它關心的是歷史位置和後續關係。"
        usage = @([ordered]@{ label = "技術"; body = "某些老系統看起來過時，但其實是今天架構的 <code>precursor</code>。"}, [ordered]@{ label = "事件"; body = "有些小徵候不是偶然，而是後面大轉變的 <code>precursor</code>。"})
        collocations = @([ordered]@{ phrase = "chemical precursor"; register = "科學 / 醫療" }, [ordered]@{ phrase = "precursor to reform"; register = "歷史 / 政策" })
        modernUse = @("<code>precursor</code> 很常用於技術史、制度史與科學寫作，因為它把『前身』與『後續連結』綁在一起。")
    }
    [ordered]@{
        slug = "predilection"
        word = "Predilection"
        partOfSpeech = "noun"
        pronunciation = "pred-uh-LEK-shən · UK /ˌpred.ɪˈlek.ʃən/ · US /ˌpred.əˈlek.ʃən/"
        cefr = "C2"
        zipf = "2.21"
        thesis = "不是喜歡，而是會一再偏向同一類東西。"
        selfMeaning = "偏好傾向"
        selfUse = "用在人或機構對某種風格、選擇或做法有穩定偏愛時。"
        contrastWord = "Preference"
        contrastNote = "<code>preference</code> 很日常；<code>predilection</code> 更書面，也更像反覆顯現的偏愛。"
        neighborMeaning = "一般偏好或選擇"
        neighborUse = "若只談普通喜好，用 <code>preference</code> 更自然。"
        flow = @("不是一次選擇", "偏愛反覆出現", "久了形成穩定傾向")
        hook = "把 <code>predilection</code> 想成手會自動往同一個抽屜伸。"
        hookExplanation = "它不是短暫喜歡，而是有一點慣性地偏向那裡。"
        usage = @([ordered]@{ label = "風格"; body = "如果一個作者總是偏愛某種句型或題材，就可以說他有 a <code>predilection</code> for it。"}, [ordered]@{ label = "決策"; body = "團隊若老是往同一種解法靠，不只是習慣，也可能是一種 <code>predilection</code>。"})
        collocations = @([ordered]@{ phrase = "predilection for detail"; register = "評論 / 人物" }, [ordered]@{ phrase = "predilection toward risk"; register = "管理 / 心理" })
        modernUse = @("<code>predilection</code> 適合正式描述某人長期穩定的偏愛，比 like 更有輪廓。")
    }
    [ordered]@{
        slug = "preempt"
        word = "Preempt"
        partOfSpeech = "verb"
        pronunciation = "pree-EMPT · UK /priːˈempt/ · US /priːˈempt/"
        cefr = "C1"
        zipf = "2.77"
        thesis = "不是搶快，而是先一步動手，讓別人沒機會再做。"
        selfMeaning = "先發占位"
        selfUse = "用在先一步處理、回應或出手，以免別人搶走主導權時。"
        contrastWord = "Forestall"
        contrastNote = "<code>forestall</code> 偏阻止後續發生；<code>preempt</code> 更強調你先一步占掉位置。"
        neighborMeaning = "事先阻止某件事"
        neighborUse = "若重點是攔下結果，不特別強調主導權，用 <code>forestall</code> 更準。"
        flow = @("局勢還沒完全展開", "先一步卡位出手", "後面的人失去空間")
        hook = "把 <code>preempt</code> 想成不是排隊排得快，而是先把位置整個占走。"
        hookExplanation = "這個字很常跟時機和主導權綁在一起。"
        usage = @([ordered]@{ label = "溝通"; body = "如果你知道誤解快要擴散，先說清楚就是一種 <code>preempt</code>。"}, [ordered]@{ label = "競爭"; body = "有些產品不是更好，而是更早 <code>preempt</code> 了市場注意力。"})
        collocations = @([ordered]@{ phrase = "preempt criticism"; register = "溝通 / 媒體" }, [ordered]@{ phrase = "preempt the market"; register = "商業 / 策略" })
        modernUse = @("<code>preempt</code> 在商業、政治與公關語境都常見，因為它精準寫出『先一步卡位』。")
    }
    [ordered]@{
        slug = "prelude"
        word = "Prelude"
        partOfSpeech = "noun"
        pronunciation = "PREL-yood · UK /ˈprel.juːd/ · US /ˈprel.uːd/"
        cefr = "C1"
        zipf = "2.62"
        thesis = "不是前面那段，而是替後面真正主體暖場的開端。"
        selfMeaning = "序幕鋪墊"
        selfUse = "用在某件更大的事發生前，那段先行鋪墊時。"
        contrastWord = "Introduction"
        contrastNote = "<code>introduction</code> 很中性；<code>prelude</code> 更有序幕、預示和氣氛鋪陳感。"
        neighborMeaning = "單純的開場介紹"
        neighborUse = "若只要功能性的開場，用 <code>introduction</code> 更簡單。"
        flow = @("先有一段暖場", "氣氛逐漸被推起來", "後面主體才真正進場")
        hook = "把 <code>prelude</code> 想成演出前燈光先暗下來的那幾秒。"
        hookExplanation = "它不是主菜，但它會決定你怎麼走進主菜。"
        usage = @([ordered]@{ label = "事件"; body = "回頭看時，前面的幾個小動作常被視為後續大變化的 <code>prelude</code>。"}, [ordered]@{ label = "寫作"; body = "如果前段不是純交代，而是在替後文壓氣氛，<code>prelude</code> 很好用。"})
        collocations = @([ordered]@{ phrase = "prelude to war"; register = "歷史 / 評論" }, [ordered]@{ phrase = "musical prelude"; register = "藝術 / 音樂" })
        modernUse = @("<code>prelude</code> 在評論和敘事裡很有用，因為它讓你把前段和後段的因勢關係寫得更有戲劇感。")
    }
    [ordered]@{
        slug = "premise"
        word = "Premise"
        partOfSpeech = "noun"
        pronunciation = "PREM-iss · UK /ˈprem.ɪs/ · US /ˈprem.ɪs/"
        cefr = "B2"
        zipf = "3.54"
        thesis = "不是結論，而是結論站在上面的那塊地板。"
        selfMeaning = "前提基座"
        selfUse = "用在推理、策略或故事成立所依靠的基本設定時。"
        contrastWord = "Assumption"
        contrastNote = "<code>assumption</code> 偏假設；<code>premise</code> 更像整段推理或故事所站的前提框架。"
        neighborMeaning = "未被驗證的假定"
        neighborUse = "若重點是這件事是否真的成立，用 <code>assumption</code> 更聚焦。"
        flow = @("先立一塊前提", "推理在其上展開", "一旦底板鬆動，後面都跟著晃")
        hook = "把 <code>premise</code> 想成不是屋頂，而是整棟房子踩著的地板。"
        hookExplanation = "它最重要的地方常常不是看起來最顯眼。"
        usage = @([ordered]@{ label = "推理"; body = "如果結論老是說不通，先回去檢查 <code>premise</code> 往往比修補句子有效。"}, [ordered]@{ label = "故事"; body = "談小說或電影時，<code>premise</code> 也常指那個讓故事成立的核心設定。"})
        collocations = @([ordered]@{ phrase = "false premise"; register = "辯論 / 分析" }, [ordered]@{ phrase = "core premise"; register = "寫作 / 產品" })
        modernUse = @("<code>premise</code> 在推理、故事和產品概念討論都很常見，因為它抓的是最底下那層站位。")
    }
    [ordered]@{
        slug = "prescient"
        word = "Prescient"
        partOfSpeech = "adjective"
        pronunciation = "PRESH-ənt · UK /ˈpreʃ.ənt/ · US /ˈpreʃ.ənt/"
        cefr = "C2"
        zipf = "2.28"
        thesis = "不是猜中，而是早早看見別人後來才看見的走向。"
        selfMeaning = "先見洞察"
        selfUse = "用在觀察或判斷提前看出後續發展時。"
        contrastWord = "Predictive"
        contrastNote = "<code>predictive</code> 偏可預測；<code>prescient</code> 更像人有先見之明。"
        neighborMeaning = "能做出預測"
        neighborUse = "若是在談模型或方法的預測能力，用 <code>predictive</code> 更合適。"
        flow = @("別人還沒注意", "有人先看出方向", "之後事實慢慢追上那個判斷")
        hook = "把 <code>prescient</code> 想成天還沒變，卻先聞到雨味的人。"
        hookExplanation = "它稱讚的不是神祕，而是提早看見。"
        usage = @([ordered]@{ label = "評論"; body = "有些舊文章回頭看會覺得格外 <code>prescient</code>，因為它早早指出後面的裂縫。"}, [ordered]@{ label = "策略"; body = "若一個決策在風險真正爆開前就先轉向，常會被說很 <code>prescient</code>。"})
        collocations = @([ordered]@{ phrase = "prescient warning"; register = "評論 / 新聞" }, [ordered]@{ phrase = "prescient analysis"; register = "研究 / 商務" })
        modernUse = @("<code>prescient</code> 常見於回顧式評論，拿來稱讚那些提早看見趨勢的人或文本。")
    }
    [ordered]@{
        slug = "pristine"
        word = "Pristine"
        partOfSpeech = "adjective"
        pronunciation = "PRIS-teen · UK /ˈprɪs.tiːn/ · US /ˈprɪs.tiːn/"
        cefr = "C1"
        zipf = "2.89"
        thesis = "不是乾淨，而是乾淨到像還沒被碰過。"
        selfMeaning = "未染原貌"
        selfUse = "用在環境、狀態或物件保存得像初始一樣時。"
        contrastWord = "Clean"
        contrastNote = "<code>clean</code> 是乾淨；<code>pristine</code> 更像保留了最初狀態。"
        neighborMeaning = "沒有髒污、整理過"
        neighborUse = "若只是整潔乾淨，用 <code>clean</code> 即可。"
        flow = @("沒有被污染", "也沒有被磨損", "保留接近初始的面貌")
        hook = "把 <code>pristine</code> 想成新雪地上還沒有第一個腳印。"
        hookExplanation = "這個字帶著一點原初感，不只是打掃過。"
        usage = @([ordered]@{ label = "環境"; body = "談自然景觀時，<code>pristine</code> 常暗示它還保有未被擾動的樣子。"}, [ordered]@{ label = "資料"; body = "在工程裡也可以用 <code>pristine</code> 形容尚未被改動的原始狀態。"})
        collocations = @([ordered]@{ phrase = "pristine condition"; register = "日常 / 正式" }, [ordered]@{ phrase = "pristine environment"; register = "自然 / 評論" })
        modernUse = @("<code>pristine</code> 常用來讚賞未受污染或仍保有原貌的狀態，也常延伸到資料與版本管理。")
    }
    [ordered]@{
        slug = "probity"
        word = "Probity"
        partOfSpeech = "noun"
        pronunciation = "PROB-uh-tee · UK /ˈprəʊ.bə.ti/ · US /ˈproʊ.bə.t̬i/"
        cefr = "C2"
        zipf = "2.05"
        thesis = "不是誠實而已，而是行為和標準都站得住。"
        selfMeaning = "正直操守"
        selfUse = "用在一個人的品格、廉潔和做事底線值得信任時。"
        contrastWord = "Integrity"
        contrastNote = "<code>integrity</code> 用得更廣；<code>probity</code> 更偏正式，也更常落在廉潔與操守。"
        neighborMeaning = "完整性與價值一致"
        neighborUse = "若你想談整體一致與誠信，用 <code>integrity</code> 更常見。"
        flow = @("有原則可依", "做事不偷換標準", "因此能被長期信任")
        hook = "把 <code>probity</code> 想成天平不是只會擺平，而是每次秤都不作弊。"
        hookExplanation = "這個字帶著很正式的道德重量。"
        usage = @([ordered]@{ label = "公職"; body = "談公職人物時，<code>probity</code> 常用來稱讚那種可以經得起放大檢視的操守。"}, [ordered]@{ label = "治理"; body = "制度再漂亮，如果沒有基本 <code>probity</code>，最後還是會被掏空。"})
        collocations = @([ordered]@{ phrase = "financial probity"; register = "治理 / 財務" }, [ordered]@{ phrase = "personal probity"; register = "正式 / 評論" })
        modernUse = @("<code>probity</code> 在治理、審計與正式評論中很有用，因為它把『值得信任的操守』說得很準。")
    }
    [ordered]@{
        slug = "quagmire"
        word = "Quagmire"
        partOfSpeech = "noun"
        pronunciation = "KWAG-myre · UK /ˈkwæɡ.maɪə/ · US /ˈkwæɡ.maɪr/"
        cefr = "C2"
        zipf = "2.22"
        thesis = "不是麻煩，而是越掙扎越陷深的泥地。"
        selfMeaning = "泥淖困局"
        selfUse = "用在問題不只難解，還會讓人越處理越被拖住時。"
        contrastWord = "Mess"
        contrastNote = "<code>mess</code> 可以很亂；<code>quagmire</code> 更像一腳踩進去後很難抽身。"
        neighborMeaning = "混亂又麻煩的局面"
        neighborUse = "若只是說事情一團亂，用 <code>mess</code> 即可。"
        flow = @("先踩進去", "越動越深", "最後被整個局拖住")
        hook = "把 <code>quagmire</code> 想成不是堵車，而是車輪整個陷進泥地。"
        hookExplanation = "它強調的是『抽身成本』越來越高。"
        usage = @([ordered]@{ label = "專案"; body = "如果一個決策讓團隊每修一次都更被綁住，整體就像進入 <code>quagmire</code>。"}, [ordered]@{ label = "政治"; body = "談長期拉不出來的戰事或政策失誤時，<code>quagmire</code> 很常出現。"})
        collocations = @([ordered]@{ phrase = "bureaucratic quagmire"; register = "管理 / 政策" }, [ordered]@{ phrase = "legal quagmire"; register = "法律 / 媒體" })
        modernUse = @("<code>quagmire</code> 在現代評論裡常用來描述那種一旦踩進去，修復成本只會越滾越大的局面。")
    }
    [ordered]@{
        slug = "quibble"
        word = "Quibble"
        partOfSpeech = "verb"
        pronunciation = "KWIB-uhl · UK /ˈkwɪb.əl/ · US /ˈkwɪb.əl/"
        cefr = "C1"
        zipf = "2.39"
        thesis = "不是討論，而是在小地方挑細枝末節。"
        selfMeaning = "吹毛挑刺"
        selfUse = "用在對重點幫助不大的小差異反覆爭時。"
        contrastWord = "Disagree"
        contrastNote = "<code>disagree</code> 是不同意；<code>quibble</code> 暗示你在小地方卡太久。"
        neighborMeaning = "有不同看法"
        neighborUse = "若是對核心點真的有分歧，用 <code>disagree</code> 更中性。"
        flow = @("大方向其實相近", "注意力卡在小差別", "討論被細節拖住")
        hook = "把 <code>quibble</code> 想成桌上有大洞還在量桌布邊緣歪幾毫米。"
        hookExplanation = "這個字常帶一點『你在挑不值得挑的地方』。"
        usage = @([ordered]@{ label = "會議"; body = "當大家其實已經同意方向，還一直在小地方繞，那就像在 <code>quibble</code>。"}, [ordered]@{ label = "評論"; body = "有些回應不是提出真正反對，只是在字眼上 <code>quibble</code>。"})
        collocations = @([ordered]@{ phrase = "quibble over wording"; register = "會議 / 寫作" }, [ordered]@{ phrase = "quibble with the details"; register = "評論 / 口語" })
        modernUse = @("<code>quibble</code> 很適合提醒團隊：現在卡住的是細枝末節，不是核心判斷。")
    }
    [ordered]@{
        slug = "quiescent"
        word = "Quiescent"
        partOfSpeech = "adjective"
        pronunciation = "kwi-ES-ənt · UK /kwiˈes.ənt/ · US /kwiˈes.ənt/"
        cefr = "C2"
        zipf = "2.01"
        thesis = "不是死掉，而是暫時安靜、不活動。"
        selfMeaning = "靜止休眠"
        selfUse = "用在威脅、基因、習慣或市場暫時不活躍時。"
        contrastWord = "Dormant"
        contrastNote = "<code>dormant</code> 偏沉睡；<code>quiescent</code> 更書面，也常指暫時不活動但仍在。"
        neighborMeaning = "沉睡、暫停、未啟動"
        neighborUse = "若想用更常見的字描述休眠狀態，用 <code>dormant</code> 更自然。"
        flow = @("東西沒有消失", "活動度先降到很低", "表面看起來近乎靜止")
        hook = "把 <code>quiescent</code> 想成火山不是熄了，而是暫時沒冒煙。"
        hookExplanation = "它保留了『還在』這件事，只是現在不動。"
        usage = @([ordered]@{ label = "風險"; body = "有些漏洞不是修掉，而是因為條件沒到，暫時保持 <code>quiescent</code>。"}, [ordered]@{ label = "系統"; body = "市場在事件前看似 <code>quiescent</code>，不代表裡面沒有壓力。"})
        collocations = @([ordered]@{ phrase = "quiescent state"; register = "科學 / 工程" }, [ordered]@{ phrase = "quiescent market"; register = "財經 / 評論" })
        modernUse = @("<code>quiescent</code> 雖偏正式，但在技術、金融與醫療語境都很好用，因為它精準表達『暫時不動，但還在』。")
    }
    [ordered]@{
        slug = "quirk"
        word = "Quirk"
        partOfSpeech = "noun"
        pronunciation = "KWERK · UK /kwɜːk/ · US /kwɝːk/"
        cefr = "B2"
        zipf = "3.06"
        thesis = "不是缺陷，而是一個有點怪、但可辨認的小特徵。"
        selfMeaning = "小怪癖性"
        selfUse = "用在人、系統或語言有點奇特但可辨認的習性時。"
        contrastWord = "Bug"
        contrastNote = "<code>bug</code> 是錯誤；<code>quirk</code> 可以怪，但不一定真的是壞掉。"
        neighborMeaning = "明確錯誤、應修正的缺陷"
        neighborUse = "若是功能錯誤或會造成損害，用 <code>bug</code> 才準。"
        flow = @("特徵有點不尋常", "卻反覆穩定出現", "久了成為可辨識的一部分")
        hook = "把 <code>quirk</code> 想成門把有點歪，但每次就是那個角度最好開。"
        hookExplanation = "這個字留住了『奇特』，卻不急著判它為錯。"
        usage = @([ordered]@{ label = "產品"; body = "有些介面行為明明很怪，卻更像設計 <code>quirk</code> 而不是 bug。"}, [ordered]@{ label = "個性"; body = "形容一個人的小習慣時，<code>quirk</code> 常帶一點可愛或可辨識感。"})
        collocations = @([ordered]@{ phrase = "personality quirk"; register = "人際 / 評論" }, [ordered]@{ phrase = "quirk of the system"; register = "工程 / 口語" })
        modernUse = @("<code>quirk</code> 很常出現在產品與人際描述裡，因為它能把『怪但未必錯』這種特質保留下來。")
    }
    [ordered]@{
        slug = "rabid"
        word = "Rabid"
        partOfSpeech = "adjective"
        pronunciation = "RAB-id · UK /ˈræb.ɪd/ · US /ˈræb.ɪd/"
        cefr = "C1"
        zipf = "2.51"
        thesis = "不是熱情，而是熱到帶攻擊性。"
        selfMeaning = "狂熱失控"
        selfUse = "用在支持、反對或情緒強度高到近乎失控時。"
        contrastWord = "Fervent"
        contrastNote = "<code>fervent</code> 可以是正面的熱誠；<code>rabid</code> 則常帶失衡與攻擊性。"
        neighborMeaning = "熱切、真誠而投入"
        neighborUse = "若重點是深切熱誠，不帶失控感，用 <code>fervent</code> 更好。"
        flow = @("情緒先高漲", "理性退到後面", "熱度開始咬人")
        hook = "把 <code>rabid</code> 想成不是火旺，而是火旺到開始亂噴。"
        hookExplanation = "它批評的不是投入，而是投入失去比例。"
        usage = @([ordered]@{ label = "支持者"; body = "如果一群支持者的熱情已經帶出攻擊性，<code>rabid</code> 的語感就到了。"}, [ordered]@{ label = "評論"; body = "有些反對聲浪不是強烈而已，而是近乎 <code>rabid</code>。"})
        collocations = @([ordered]@{ phrase = "rabid fan base"; register = "媒體 / 文化" }, [ordered]@{ phrase = "rabid opposition"; register = "政治 / 評論" })
        modernUse = @("<code>rabid</code> 在現代評論裡常用來寫狂熱過頭、甚至帶攻擊性的支持或反對。")
    }
    [ordered]@{
        slug = "rancor"
        word = "Rancor"
        partOfSpeech = "noun"
        pronunciation = "RANG-ker · UK /ˈræŋ.kə/ · US /ˈræŋ.kɚ/"
        cefr = "C2"
        zipf = "2.12"
        thesis = "不是生氣，而是積久了還沒散掉的怨恨。"
        selfMeaning = "積怨苦毒"
        selfUse = "用在人際或政治衝突中，怒氣沉澱成長久怨恨時。"
        contrastWord = "Anger"
        contrastNote = "<code>anger</code> 可以是一時情緒；<code>rancor</code> 更像沉在底下、放久的怨。"
        neighborMeaning = "當下的怒氣"
        neighborUse = "若只是當場生氣，用 <code>anger</code> 更直接。"
        flow = @("衝突先發生", "怒氣沒有消掉", "久了變成帶苦味的怨")
        hook = "把 <code>rancor</code> 想成不是剛煮沸的水，而是鍋底一直燒焦不散的味道。"
        hookExplanation = "這個字寫的是情緒放久之後的殘留。"
        usage = @([ordered]@{ label = "人際"; body = "如果爭執已經過去很久，卻還留下一層苦味，那種感覺就接近 <code>rancor</code>。"}, [ordered]@{ label = "政治"; body = "公共討論裡最難處理的常不是分歧，而是堆久了的 <code>rancor</code>。"})
        collocations = @([ordered]@{ phrase = "deep rancor"; register = "評論 / 人際" }, [ordered]@{ phrase = "political rancor"; register = "政治 / 媒體" })
        modernUse = @("<code>rancor</code> 很適合寫那些衝突結束後仍留在關係裡的苦毒，尤其在政治和長期合作裂痕中。")
    }
    [ordered]@{
        slug = "rampant"
        word = "Rampant"
        partOfSpeech = "adjective"
        pronunciation = "RAM-pənt · UK /ˈræm.pənt/ · US /ˈræm.pənt/"
        cefr = "C1"
        zipf = "2.89"
        thesis = "不是很多，而是失控地到處蔓開。"
        selfMeaning = "失控蔓延"
        selfUse = "用在腐敗、謠言、錯誤或某種行為到處擴散時。"
        contrastWord = "Widespread"
        contrastNote = "<code>widespread</code> 是分布很廣；<code>rampant</code> 還多了失控與惡化感。"
        neighborMeaning = "分布範圍很廣"
        neighborUse = "若只是客觀描述很普遍，用 <code>widespread</code> 更中性。"
        flow = @("一開始只是局部", "很快四處擴散", "最後帶著失控感")
        hook = "把 <code>rampant</code> 想成藤蔓不是長出來，而是整面牆都被它吃掉。"
        hookExplanation = "它通常帶有『沒人真的控住』的警訊。"
        usage = @([ordered]@{ label = "問題"; body = "如果錯誤不是零星，而是到處冒出來，就很像變得 <code>rampant</code>。"}, [ordered]@{ label = "文化"; body = "某些壞習慣一旦無人制止，就會在團隊裡 <code>rampant</code> 地長開。"})
        collocations = @([ordered]@{ phrase = "rampant corruption"; register = "政治 / 新聞" }, [ordered]@{ phrase = "rampant speculation"; register = "媒體 / 財經" })
        modernUse = @("<code>rampant</code> 在新聞與評論裡常拿來寫快速蔓延且失控的負面現象。")
    }
    [ordered]@{
        slug = "ratify"
        word = "Ratify"
        partOfSpeech = "verb"
        pronunciation = "RAT-uh-fy · UK /ˈræt.ɪ.faɪ/ · US /ˈræt̬.ə.faɪ/"
        cefr = "C1"
        zipf = "2.53"
        thesis = "不是同意，而是正式把它蓋章成效。"
        selfMeaning = "正式批准"
        selfUse = "用在協議、條款或決議經正式程序確認時。"
        contrastWord = "Approve"
        contrastNote = "<code>approve</code> 可以只是表示同意；<code>ratify</code> 更像經正式程序讓它生效。"
        neighborMeaning = "表示認可或接受"
        neighborUse = "若只是一般同意，不一定有程序與法律效力，用 <code>approve</code> 即可。"
        flow = @("先有草案或協議", "進入正式程序", "最後被確認生效")
        hook = "把 <code>ratify</code> 想成文件不是寫完就算，而是最後要蓋上生效那一印。"
        hookExplanation = "這個字很重程序感。"
        usage = @([ordered]@{ label = "協議"; body = "條約談妥還不夠，還得被相關機構 <code>ratify</code> 才真正成立。"}, [ordered]@{ label = "組織"; body = "有些決定不是主管點頭就算，要等董事會 <code>ratify</code>。"})
        collocations = @([ordered]@{ phrase = "ratify the agreement"; register = "法律 / 政治" }, [ordered]@{ phrase = "ratify the decision"; register = "治理 / 組織" })
        modernUse = @("<code>ratify</code> 常見於條約、組織決議與章程治理，因為它精準指向正式生效那一步。")
    }
    [ordered]@{
        slug = "redress"
        word = "Redress"
        partOfSpeech = "noun"
        pronunciation = "ri-DRESS · UK /rɪˈdres/ · US /rɪˈdres/"
        cefr = "C1"
        zipf = "2.42"
        thesis = "不是道歉，而是讓受損的一方得到補償或修復。"
        selfMeaning = "補救補償"
        selfUse = "用在某種傷害、損失或不公需要被補正時。"
        contrastWord = "Apology"
        contrastNote = "<code>apology</code> 是表態；<code>redress</code> 更往具體補救或補償走。"
        neighborMeaning = "表達歉意或承認錯誤"
        neighborUse = "若重點只是說抱歉，用 <code>apology</code> 即可。"
        flow = @("先有傷害或不公", "受損方提出要求", "補償或修正被安排進來")
        hook = "把 <code>redress</code> 想成不是說一句對不起，而是真的把傾斜的秤盤拉回來。"
        hookExplanation = "這個字往往期待的是可執行的修補。"
        usage = @([ordered]@{ label = "制度"; body = "如果申訴最後能帶來補償或修正，那才接近真正的 <code>redress</code>。"}, [ordered]@{ label = "法律"; body = "談權益受損時，<code>redress</code> 常比 apology 更有實際份量。"})
        collocations = @([ordered]@{ phrase = "seek redress"; register = "法律 / 正式" }, [ordered]@{ phrase = "provide redress"; register = "政策 / 治理" })
        modernUse = @("<code>redress</code> 在法律、治理與消費者保護語境很常見，因為它把『補回來』說得比 sorry 更實際。")
    }
    [ordered]@{
        slug = "relapse"
        word = "Relapse"
        partOfSpeech = "verb"
        pronunciation = "ree-LAPS · UK /rɪˈlæps/ · US /rɪˈlæps/"
        cefr = "C1"
        zipf = "2.71"
        thesis = "不是退步，而是好不容易離開後又掉回去。"
        selfMeaning = "復發退回"
        selfUse = "用在病症、習慣或狀態改善後又回到舊問題時。"
        contrastWord = "Regress"
        contrastNote = "<code>regress</code> 是整體退步；<code>relapse</code> 更像離開後又跌回老路。"
        neighborMeaning = "往較早或較差的狀態退回"
        neighborUse = "若是一般性的退化或倒退，用 <code>regress</code> 更廣。"
        flow = @("原本有改善", "警覺逐漸鬆掉", "舊狀態重新回來")
        hook = "把 <code>relapse</code> 想成剛爬出坑，又在同一個邊緣滑回去。"
        hookExplanation = "這個字帶著一點令人沮喪的重來感。"
        usage = @([ordered]@{ label = "習慣"; body = "最難的不是戒掉那一下，而是避免在壓力大時 <code>relapse</code>。"}, [ordered]@{ label = "系統"; body = "修好一個流程後若又回到手動補洞，就像在 <code>relapse</code> into old habits。"})
        collocations = @([ordered]@{ phrase = "relapse into old habits"; register = "日常 / 管理" }, [ordered]@{ phrase = "relapse after treatment"; register = "醫療 / 正式" })
        modernUse = @("<code>relapse</code> 在健康、習慣養成和組織改善都很好用，因為它把『回到舊問題』這層挫折感寫了出來。")
    }
    [ordered]@{
        slug = "relent"
        word = "Relent"
        partOfSpeech = "verb"
        pronunciation = "ri-LENT · UK /rɪˈlent/ · US /rɪˈlent/"
        cefr = "C1"
        zipf = "2.63"
        thesis = "不是同意，而是終於鬆手一點。"
        selfMeaning = "終於鬆動"
        selfUse = "用在原本很硬的態度、壓力或條件終於變軟時。"
        contrastWord = "Yield"
        contrastNote = "<code>yield</code> 是讓步；<code>relent</code> 更像堅持已久後終於鬆開。"
        neighborMeaning = "讓出、退讓、接受對方"
        neighborUse = "若重點是具體讓步行為，用 <code>yield</code> 更直接。"
        flow = @("原本一直很硬", "壓力慢慢累積", "最後態度終於鬆一點")
        hook = "把 <code>relent</code> 想成抓得很緊的手，終於有一根手指先鬆開。"
        hookExplanation = "它寫的是鬆動發生的瞬間。"
        usage = @([ordered]@{ label = "談判"; body = "有些僵局真正的轉折，不是對方改口，而是終於開始 <code>relent</code>。"}, [ordered]@{ label = "壓力"; body = "如果天氣、工作量或規定一直不放人，也可以說它們 refuse to <code>relent</code>。"})
        collocations = @([ordered]@{ phrase = "finally relent"; register = "人際 / 敘事" }, [ordered]@{ phrase = "pressure relents"; register = "評論 / 報導" })
        modernUse = @("<code>relent</code> 常見於談判、人際和新聞敘事，因為它抓住『硬了很久，終於鬆一點』那刻。")
    }
    [ordered]@{
        slug = "relegate"
        word = "Relegate"
        partOfSpeech = "verb"
        pronunciation = "REL-uh-gayt · UK /ˈrel.ɪ.ɡeɪt/ · US /ˈrel.ə.ɡeɪt/"
        cefr = "C1"
        zipf = "2.57"
        thesis = "不是移動，而是把某人某事往較次要的位置放。"
        selfMeaning = "降到次位"
        selfUse = "用在角色、議題或人被推到邊緣、次要或較低位置時。"
        contrastWord = "Assign"
        contrastNote = "<code>assign</code> 是分配；<code>relegate</code> 更像降格、往旁邊擺。"
        neighborMeaning = "分配到某位置或任務"
        neighborUse = "若沒有降位感，只是一般安排，用 <code>assign</code> 更自然。"
        flow = @("原本還在主場", "被推往旁邊或下層", "重要性明顯被降")
        hook = "把 <code>relegate</code> 想成不是換座位，而是從桌中央被挪到最邊邊。"
        hookExplanation = "它常帶一點權力和價值排序。"
        usage = @([ordered]@{ label = "議題"; body = "如果某個重要問題總被放到最後討論，它其實是被 <code>relegate</code> 到次要位置。"}, [ordered]@{ label = "角色"; body = "把有經驗的人長期擺在邊角位，也是在 <code>relegate</code> 他。"})
        collocations = @([ordered]@{ phrase = "relegate to the background"; register = "評論 / 敘事" }, [ordered]@{ phrase = "relegate to a minor role"; register = "管理 / 藝評" })
        modernUse = @("<code>relegate</code> 很適合寫權力與注意力排序，因為它不只是移動，而是明顯往次位推。")
    }
    [ordered]@{
        slug = "remiss"
        word = "Remiss"
        partOfSpeech = "adjective"
        pronunciation = "ri-MISS · UK /rɪˈmɪs/ · US /rɪˈmɪs/"
        cefr = "C2"
        zipf = "2.24"
        thesis = "不是做不好，而是該做的責任沒有做。"
        selfMeaning = "失職疏漏"
        selfUse = "用在責任本來明確，卻因疏忽或怠慢沒有完成時。"
        contrastWord = "Careless"
        contrastNote = "<code>careless</code> 是粗心；<code>remiss</code> 更強，點出責任上的失職。"
        neighborMeaning = "粗心、不夠小心"
        neighborUse = "若只是一般粗心，用 <code>careless</code> 較自然。"
        flow = @("責任本來清楚", "該做的步驟沒做", "因此構成明顯疏漏")
        hook = "把 <code>remiss</code> 想成巡檢表就在桌上，卻整欄沒勾。"
        hookExplanation = "它不是笨，而是責任沒有被完成。"
        usage = @([ordered]@{ label = "責任"; body = "如果明知道要提醒、要檢查卻沒做，就可以說自己 would be <code>remiss</code>。"}, [ordered]@{ label = "治理"; body = "對已知風險視而不見，往往不是 unlucky，而是 <code>remiss</code>。"})
        collocations = @([ordered]@{ phrase = "be remiss in one's duty"; register = "正式 / 治理" }, [ordered]@{ phrase = "remiss oversight"; register = "法律 / 評論" })
        modernUse = @("<code>remiss</code> 在正式書寫很實用，因為它能禮貌但明確地指出『這是責任上的失誤』。")
    }
    [ordered]@{
        slug = "renounce"
        word = "Renounce"
        partOfSpeech = "verb"
        pronunciation = "ri-NOWNS · UK /rɪˈnaʊns/ · US /rɪˈnaʊns/"
        cefr = "C1"
        zipf = "2.48"
        thesis = "不是放棄而已，而是公開與它切斷關係。"
        selfMeaning = "公開棄絕"
        selfUse = "用在人明白宣告不再接受某信念、身份或權利時。"
        contrastWord = "Abandon"
        contrastNote = "<code>abandon</code> 可以只是丟下；<code>renounce</code> 常有公開、正式切割的味道。"
        neighborMeaning = "放下、丟棄、不再持有"
        neighborUse = "若只要一般放棄，用 <code>abandon</code> 或 give up 更常見。"
        flow = @("原本與某物有連結", "人主動表態切開", "之後不再承認那個身份或權利")
        hook = "把 <code>renounce</code> 想成不是把東西放桌上，而是當眾把名字從它上面劃掉。"
        hookExplanation = "這個字有一種公開切割的戲劇感。"
        usage = @([ordered]@{ label = "信念"; body = "若一個人公開放棄過去主張，可以說他 <code>renounced</code> those views。"}, [ordered]@{ label = "權利"; body = "某些法律語境裡，<code>renounce</code> 也會用在放棄公民資格或繼承權。"})
        collocations = @([ordered]@{ phrase = "renounce violence"; register = "政治 / 公共" }, [ordered]@{ phrase = "renounce citizenship"; register = "法律 / 正式" })
        modernUse = @("<code>renounce</code> 常見於政治、宗教與法律語境，因為它不只是離開，而是明白切割。")
    }
    [ordered]@{
        slug = "repertoire"
        word = "Repertoire"
        partOfSpeech = "noun"
        pronunciation = "REP-er-twahr · UK /ˈrep.ə.twɑː/ · US /ˈrep.ɚ.twɑːr/"
        cefr = "C1"
        zipf = "2.67"
        thesis = "不是清單，而是你手上那套真正能拿出來用的本事。"
        selfMeaning = "可用本領庫"
        selfUse = "用在某人或某團體手上能熟練拿出來的技能、作品或招式集合。"
        contrastWord = "Inventory"
        contrastNote = "<code>inventory</code> 是庫存清單；<code>repertoire</code> 更像隨時可上場的本領。"
        neighborMeaning = "列出來的物品或項目清單"
        neighborUse = "若只是列數量或品項，用 <code>inventory</code> 更準。"
        flow = @("不只擁有", "而且能調度使用", "久了形成一套可上場的庫")
        hook = "把 <code>repertoire</code> 想成不是工具箱，而是你知道怎麼用、用得順的那幾樣工具。"
        hookExplanation = "它比 collection 更有熟練與調度感。"
        usage = @([ordered]@{ label = "技能"; body = "如果一個人不只會一招，而是有一整套拿得出手的做法，就可以談他的 <code>repertoire</code>。"}, [ordered]@{ label = "表演"; body = "在音樂、戲劇語境裡，<code>repertoire</code> 也常指可演出的作品庫。"})
        collocations = @([ordered]@{ phrase = "expand one's repertoire"; register = "學習 / 表演" }, [ordered]@{ phrase = "repertoire of skills"; register = "職涯 / 教育" })
        modernUse = @("<code>repertoire</code> 在技能成長、表演藝術與教學討論都很好用，因為它強調的是可調度的熟手庫。")
    }
    [ordered]@{
        slug = "reprieve"
        word = "Reprieve"
        partOfSpeech = "noun"
        pronunciation = "ri-PREEV · UK /rɪˈpriːv/ · US /rɪˈpriːv/"
        cefr = "C1"
        zipf = "2.43"
        thesis = "不是解脫，而是暫時鬆一口氣。"
        selfMeaning = "暫緩喘息"
        selfUse = "用在壓力、處罰或危機沒有完全解除，只是暫時延後或放鬆時。"
        contrastWord = "Rescue"
        contrastNote = "<code>rescue</code> 更像真正救出來；<code>reprieve</code> 常只是暫時放你一馬。"
        neighborMeaning = "被真正救離危險"
        neighborUse = "若危機已經完全脫離，用 <code>rescue</code> 或 relief 更貼近。"
        flow = @("危機先壓著你", "壓力暫時鬆開", "但根本問題還沒走")
        hook = "把 <code>reprieve</code> 想成浪先退一下，岸上人能喘口氣，但海還在。"
        hookExplanation = "它保留了暫時性，這是關鍵。"
        usage = @([ordered]@{ label = "時程"; body = "如果 deadline 只是往後延，而不是取消，那更像一種 <code>reprieve</code>。"}, [ordered]@{ label = "危機"; body = "很多人把暫時好轉誤當結束，其實那只是一段短短的 <code>reprieve</code>。"})
        collocations = @([ordered]@{ phrase = "temporary reprieve"; register = "正式 / 新聞" }, [ordered]@{ phrase = "grant a reprieve"; register = "法律 / 管理" })
        modernUse = @("<code>reprieve</code> 常見於壓力管理、法律與財務報導，因為它能把『暫時緩一下』寫得很準。")
    }
    [ordered]@{
        slug = "repudiate"
        word = "Repudiate"
        partOfSpeech = "verb"
        pronunciation = "ri-PYOO-dee-ayt · UK /rɪˈpjuː.di.eɪt/ · US /rɪˈpjuː.di.eɪt/"
        cefr = "C2"
        zipf = "2.19"
        thesis = "不是不同意，而是明白把它撇開、否認、切割。"
        selfMeaning = "公開否斥"
        selfUse = "用在立場、責任或主張被正式否認並切割時。"
        contrastWord = "Reject"
        contrastNote = "<code>reject</code> 是拒絕；<code>repudiate</code> 更像公開切割、甚至否認和它有關。"
        neighborMeaning = "不接受、退回"
        neighborUse = "若只要一般拒絕，用 <code>reject</code> 即可。"
        flow = @("先有某關聯或主張", "人公開站出來否斥", "連帶關係被切斷")
        hook = "把 <code>repudiate</code> 想成不是把信退回，而是當場撕掉並說跟我無關。"
        hookExplanation = "它的語氣比 disagree 或 reject 都更重。"
        usage = @([ordered]@{ label = "立場"; body = "如果一個組織公開否認某說法並切割，就可以說它 <code>repudiated</code> the claim。"}, [ordered]@{ label = "責任"; body = "在正式語境裡，<code>repudiate</code> 也常指否認自己對某責任的承接。"})
        collocations = @([ordered]@{ phrase = "repudiate the claim"; register = "法律 / 媒體" }, [ordered]@{ phrase = "repudiate violence"; register = "政治 / 公共" })
        modernUse = @("<code>repudiate</code> 常見於政治聲明與法律語境，因為它帶有高強度的公開切割。")
    }
    [ordered]@{
        slug = "reticent"
        word = "Reticent"
        partOfSpeech = "adjective"
        pronunciation = "RET-uh-sənt · UK /ˈret.ɪ.sənt/ · US /ˈret̬.ə.sənt/"
        cefr = "C2"
        zipf = "2.36"
        thesis = "不是害羞，而是不願把話全部攤開。"
        selfMeaning = "寡言保留"
        selfUse = "用在人刻意少說、保留、或不願完全打開時。"
        contrastWord = "Shy"
        contrastNote = "<code>shy</code> 偏社交膽怯；<code>reticent</code> 更像有意識地收住話。"
        neighborMeaning = "害羞、不敢表現"
        neighborUse = "若重點是膽怯，不是保留，用 <code>shy</code> 更自然。"
        flow = @("知道可以多說", "卻選擇收著", "資訊只露一部分")
        hook = "把 <code>reticent</code> 想成抽屜沒有鎖，但人就是只拉開一條縫。"
        hookExplanation = "這個字寫的是保留，不一定是軟弱。"
        usage = @([ordered]@{ label = "人際"; body = "有些人不是沒想法，而是對自己的經歷特別 <code>reticent</code>。"}, [ordered]@{ label = "會議"; body = "如果一個團隊成員只願意透露必要資訊，他可能顯得很 <code>reticent</code>。"})
        collocations = @([ordered]@{ phrase = "reticent about the details"; register = "人際 / 訪談" }, [ordered]@{ phrase = "reticent manner"; register = "敘事 / 評論" })
        modernUse = @("<code>reticent</code> 在人物描寫與訪談語境很好用，因為它能把『不多說』寫得更有主動性。")
    }
    [ordered]@{
        slug = "retract"
        word = "Retract"
        partOfSpeech = "verb"
        pronunciation = "ri-TRAKT · UK /rɪˈtrækt/ · US /rɪˈtrækt/"
        cefr = "C1"
        zipf = "2.62"
        thesis = "不是修改，而是把說出去的話收回。"
        selfMeaning = "收回撤銷"
        selfUse = "用在人撤回聲明、主張、指控或某個突出部分縮回時。"
        contrastWord = "Revise"
        contrastNote = "<code>revise</code> 是修改；<code>retract</code> 則是把它整段收回。"
        neighborMeaning = "修訂、重寫、調整"
        neighborUse = "若只是改內容而非整體撤回，用 <code>revise</code> 更準。"
        flow = @("原本已經說出或伸出", "意識到不能維持", "整個往回收")
        hook = "把 <code>retract</code> 想成不是換手勢，而是把伸出去的手整個縮回袖子裡。"
        hookExplanation = "這個字的方向感非常明確，就是往回收。"
        usage = @([ordered]@{ label = "聲明"; body = "如果媒體公開收回指控，就是在 <code>retract</code> that statement。"}, [ordered]@{ label = "工程"; body = "某些機構件會自動 <code>retract</code>，這時候它就是物理上的縮回。"})
        collocations = @([ordered]@{ phrase = "retract the statement"; register = "媒體 / 法律" }, [ordered]@{ phrase = "retractable mechanism"; register = "工程 / 設計" })
        modernUse = @("<code>retract</code> 的好處是同時能處理語言上的收回和物理上的縮回，兩邊都帶有清楚的回收感。")
    }
    [ordered]@{
        slug = "revere"
        word = "Revere"
        partOfSpeech = "verb"
        pronunciation = "ri-VEER · UK /rɪˈvɪə/ · US /rɪˈvɪr/"
        cefr = "C1"
        zipf = "2.55"
        thesis = "不是喜歡，而是帶著敬意抬高它。"
        selfMeaning = "尊崇敬重"
        selfUse = "用在對人物、傳統、作品或價值抱有深層敬意時。"
        contrastWord = "Admire"
        contrastNote = "<code>admire</code> 是欣賞；<code>revere</code> 更像把對方放到值得敬重的位置。"
        neighborMeaning = "欣賞、佩服"
        neighborUse = "若只是一般佩服，用 <code>admire</code> 就足夠。"
        flow = @("先看見對方價值", "情感升到敬意", "態度帶出抬高與珍重")
        hook = "把 <code>revere</code> 想成不是拍拍手，而是進門前先把帽子摘下來。"
        hookExplanation = "它比 like 或 admire 多一層抬高與莊重。"
        usage = @([ordered]@{ label = "人物"; body = "有些導師不是單純受歡迎，而是被整個領域 <code>revere</code>。"}, [ordered]@{ label = "傳統"; body = "如果一個社群不只是保存某傳統，而是帶著敬意去對待，那種感覺就接近 <code>revere</code>。"})
        collocations = @([ordered]@{ phrase = "revere the tradition"; register = "文化 / 歷史" }, [ordered]@{ phrase = "widely revered"; register = "正式 / 評論" })
        modernUse = @("<code>revere</code> 常用來描寫帶有莊重感的敬意，特別是在文化、教育與公共人物書寫裡。")
    }
    [ordered]@{
        slug = "sacrosanct"
        word = "Sacrosanct"
        partOfSpeech = "adjective"
        pronunciation = "SAK-roh-sankt · UK /ˈsæk.rəʊ.sæŋkt/ · US /ˈsæk.roʊ.sæŋkt/"
        cefr = "C2"
        zipf = "2.13"
        thesis = "不是重要，而是重要到大家默認不能碰。"
        selfMeaning = "神聖不可碰"
        selfUse = "用在規則、傳統或權利被視為不該被侵犯或質疑時。"
        contrastWord = "Important"
        contrastNote = "<code>important</code> 是重要；<code>sacrosanct</code> 更像你連手都不該伸過去。"
        neighborMeaning = "值得重視"
        neighborUse = "若只是重要但仍可談可改，用 <code>important</code> 即可。"
        flow = @("某物先被抬高", "周圍形成禁觸感", "挑戰它會被視為越線")
        hook = "把 <code>sacrosanct</code> 想成桌上不是貴重物，而是貼著『勿碰』且大家都信的那樣東西。"
        hookExplanation = "這個字不只說價值高，也說邊界被劃得很硬。"
        usage = @([ordered]@{ label = "制度"; body = "有些流程明明可以改，卻被當成 <code>sacrosanct</code>，誰碰都像犯規。"}, [ordered]@{ label = "權利"; body = "談基本權利時，<code>sacrosanct</code> 常用來強調它不該被隨便交換。"})
        collocations = @([ordered]@{ phrase = "sacrosanct principle"; register = "政治 / 法律" }, [ordered]@{ phrase = "sacrosanct tradition"; register = "文化 / 評論" })
        modernUse = @("<code>sacrosanct</code> 常出現在制度與價值辯論裡，用來指出某些東西被視為幾乎不可碰。")
    }
    [ordered]@{
        slug = "sagacious"
        word = "Sagacious"
        partOfSpeech = "adjective"
        pronunciation = "suh-GAY-shus · UK /səˈɡeɪ.ʃəs/ · US /səˈɡeɪ.ʃəs/"
        cefr = "C2"
        zipf = "2.07"
        thesis = "不是聰明，而是判斷裡有老到的分寸。"
        selfMeaning = "睿智老練"
        selfUse = "用在看事有分寸、能抓輕重、判斷成熟時。"
        contrastWord = "Smart"
        contrastNote = "<code>smart</code> 可以是反應快；<code>sagacious</code> 更像有歷練沉澱出的判斷。"
        neighborMeaning = "聰明、反應快"
        neighborUse = "若只是一般聰明，用 <code>smart</code> 更自然。"
        flow = @("不急著表現機智", "先看清局勢輕重", "最後給出成熟判斷")
        hook = "把 <code>sagacious</code> 想成不是最快那個，而是知道哪一步最值得下的人。"
        hookExplanation = "它稱讚的是判斷深度，不只是腦筋快。"
        usage = @([ordered]@{ label = "判斷"; body = "有些建議不是 flashy，但因為很 <code>sagacious</code>，事後回頭看特別穩。"}, [ordered]@{ label = "人物"; body = "形容一個人 <code>sagacious</code>，通常是在讚他看事沉著又有分寸。"})
        collocations = @([ordered]@{ phrase = "sagacious advice"; register = "人物 / 評述" }, [ordered]@{ phrase = "sagacious observer"; register = "正式 / 評論" })
        modernUse = @("<code>sagacious</code> 雖偏書面，但在人物評論裡很有力，因為它把『成熟判斷』寫得比 wise 更細。")
    }
    [ordered]@{
        slug = "sanction"
        word = "Sanction"
        partOfSpeech = "noun"
        pronunciation = "SANGK-shən · UK /ˈsæŋk.ʃən/ · US /ˈsæŋk.ʃən/"
        cefr = "C1"
        zipf = "3.41"
        thesis = "不是處罰而已，它也可以是正式批准；重點是制度把力道放下來。"
        selfMeaning = "制度裁可"
        selfUse = "用在制度以正式方式施加懲罰或給出批准時。"
        contrastWord = "Penalty"
        contrastNote = "<code>penalty</code> 只偏處罰；<code>sanction</code> 還可能指正式批准，所以要看語境。"
        neighborMeaning = "單純的處罰"
        neighborUse = "若語境沒有『制度正式出手』或『批准』這種制度語感，用 <code>penalty</code> 更單純。"
        flow = @("制度先介入", "力量被正式放下來", "結果可能是准許也可能是懲罰")
        hook = "把 <code>sanction</code> 想成蓋章本身既能放行，也能禁行。"
        hookExplanation = "這個字最值得記的是它的雙面性。"
        usage = @([ordered]@{ label = "政策"; body = "談國際政治時，<code>sanction</code> 很常指制裁；但在別的語境，也可能是正式批准。"}, [ordered]@{ label = "閱讀"; body = "讀到 <code>sanction</code> 時，先不要急著翻『制裁』，要先看它是在 punish 還是 authorize。"})
        collocations = @([ordered]@{ phrase = "economic sanctions"; register = "政治 / 媒體" }, [ordered]@{ phrase = "official sanction"; register = "法律 / 正式" })
        modernUse = @("<code>sanction</code> 是高價值字，因為它同時有處罰與批准兩面，讀寫時都要依語境解碼。")
    }
    [ordered]@{
        slug = "sardonic"
        word = "Sardonic"
        partOfSpeech = "adjective"
        pronunciation = "sar-DON-ik · UK /sɑːˈdɒn.ɪk/ · US /sɑːrˈdɑː.nɪk/"
        cefr = "C2"
        zipf = "2.29"
        thesis = "不是幽默，而是笑裡帶刺、帶冷。"
        selfMeaning = "冷刺嘲諷"
        selfUse = "用在笑、評論或語氣表面平靜，底下卻帶嘲意時。"
        contrastWord = "Sarcastic"
        contrastNote = "<code>sarcastic</code> 常較直接；<code>sardonic</code> 更冷、更乾，像薄薄的一刀。"
        neighborMeaning = "直接帶刺的諷刺"
        neighborUse = "若語氣是明顯出口傷人，用 <code>sarcastic</code> 更常見。"
        flow = @("表面像在笑", "底下有冷意", "真正作用是刺而不是暖")
        hook = "把 <code>sardonic</code> 想成嘴角有笑，但眼睛一點都沒亮。"
        hookExplanation = "它的諷刺感比較冷，不像怒氣直接噴出來。"
        usage = @([ordered]@{ label = "語氣"; body = "如果一句玩笑讓人先感到冷，再意識到它在刺，那就很 <code>sardonic</code>。"}, [ordered]@{ label = "人物"; body = "形容角色時，<code>sardonic</code> 常讓他顯得聰明、疲倦又不太客氣。"})
        collocations = @([ordered]@{ phrase = "sardonic smile"; register = "敘事 / 文學" }, [ordered]@{ phrase = "sardonic remark"; register = "評論 / 人際" })
        modernUse = @("<code>sardonic</code> 在人物描寫和影評裡很常用，因為它抓的是『冷笑』而不是普通幽默。")
    }
    [ordered]@{
        slug = "scant"
        word = "Scant"
        partOfSpeech = "adjective"
        pronunciation = "SKANT · UK /skænt/ · US /skænt/"
        cefr = "C1"
        zipf = "2.52"
        thesis = "不是少，而是少到快不夠用。"
        selfMeaning = "少得發緊"
        selfUse = "用在證據、時間、衣料或資源少到邊邊緊繃時。"
        contrastWord = "Little"
        contrastNote = "<code>little</code> 只是少；<code>scant</code> 更有『少得不太夠』的緊張感。"
        neighborMeaning = "不多、數量少"
        neighborUse = "若只要一般地說不多，用 <code>little</code> 或 few 更中性。"
        flow = @("數量先偏低", "離夠用只差一線", "整體開始帶緊張感")
        hook = "把 <code>scant</code> 想成布不是沒有，但只夠勉強蓋住。"
        hookExplanation = "這個字常把『不足邊緣』寫得很明顯。"
        usage = @([ordered]@{ label = "證據"; body = "如果資料少到撐不起結論，就會被形容為 <code>scant</code> evidence。"}, [ordered]@{ label = "時間"; body = "當時間不是少，而是少得讓每一步都得縮，<code>scant</code> 很好用。"})
        collocations = @([ordered]@{ phrase = "scant evidence"; register = "研究 / 法律" }, [ordered]@{ phrase = "scant resources"; register = "管理 / 報導" })
        modernUse = @("<code>scant</code> 常用於正式寫作，因為它比 little 更能表達『少到不太夠』。")
    }
    [ordered]@{
        slug = "seethe"
        word = "Seethe"
        partOfSpeech = "verb"
        pronunciation = "SEETH · UK /siːð/ · US /siːð/"
        cefr = "C1"
        zipf = "2.63"
        thesis = "不是生氣，而是怒氣在裡面一直滾。"
        selfMeaning = "暗湧怒氣"
        selfUse = "用在情緒沒有爆開，但整個人在裡面翻滾時。"
        contrastWord = "Fume"
        contrastNote = "<code>fume</code> 也很生氣；<code>seethe</code> 更像整鍋都在裡面滾。"
        neighborMeaning = "冒著火氣抱怨"
        neighborUse = "若重點是外顯抱怨，用 <code>fume</code> 更常見。"
        flow = @("情緒先被壓住", "裡面開始翻滾", "表面安靜卻越來越燙")
        hook = "把 <code>seethe</code> 想成鍋蓋還蓋著，但裡面的水已經滾到快掀起來。"
        hookExplanation = "它寫的是被收在裡面的強烈怒氣。"
        usage = @([ordered]@{ label = "人際"; body = "有些人當場不發作，但你看得出他正在 <code>seethe</code>。"}, [ordered]@{ label = "組織"; body = "如果不滿沒有出口，就會在團隊裡慢慢 <code>seethe</code>。"})
        collocations = @([ordered]@{ phrase = "seethe with anger"; register = "敘事 / 人際" }, [ordered]@{ phrase = "seething resentment"; register = "評論 / 心理" })
        modernUse = @("<code>seethe</code> 很適合描寫沒有爆開、卻正在暗湧的怒氣，比 angry 更有動態。")
    }
    [ordered]@{
        slug = "semblance"
        word = "Semblance"
        partOfSpeech = "noun"
        pronunciation = "SEM-bləns · UK /ˈsem.bləns/ · US /ˈsem.bləns/"
        cefr = "C1"
        zipf = "2.41"
        thesis = "不是完整樣子，而是勉強還看得出像那回事的外形。"
        selfMeaning = "勉強像樣"
        selfUse = "用在某種秩序、正常或一致性只剩薄薄外觀時。"
        contrastWord = "Appearance"
        contrastNote = "<code>appearance</code> 是外表；<code>semblance</code> 更像只剩一點點像樣的殼。"
        neighborMeaning = "外觀、表面樣子"
        neighborUse = "若只是描述外表，用 <code>appearance</code> 就夠。"
        flow = @("原本應有完整形態", "實際只剩外殼", "仍勉強看得出曾經是什麼")
        hook = "把 <code>semblance</code> 想成塌掉的牆，只剩一圈輪廓讓你認得出原來是房間。"
        hookExplanation = "它帶著一點『只剩這麼多』的薄弱感。"
        usage = @([ordered]@{ label = "秩序"; body = "如果團隊只剩表面流程撐著，還能維持 a <code>semblance</code> of order。"}, [ordered]@{ label = "正常"; body = "有時候人不是恢復正常，只是勉強拼出一點 <code>semblance</code> of normalcy。"})
        collocations = @([ordered]@{ phrase = "semblance of order"; register = "管理 / 評論" }, [ordered]@{ phrase = "semblance of control"; register = "敘事 / 分析" })
        modernUse = @("<code>semblance</code> 很常用來描寫系統或關係只剩表面完整，裡面其實已經鬆掉。")
    }
    [ordered]@{
        slug = "shoddy"
        word = "Shoddy"
        partOfSpeech = "adjective"
        pronunciation = "SHOD-ee · UK /ˈʃɒd.i/ · US /ˈʃɑː.di/"
        cefr = "B2"
        zipf = "2.74"
        thesis = "不是便宜，而是粗糙到看得出不講究。"
        selfMeaning = "粗劣偷工"
        selfUse = "用在品質、工法或處理方式明顯馬虎時。"
        contrastWord = "Cheap"
        contrastNote = "<code>cheap</code> 只是便宜；<code>shoddy</code> 更直接批評品質差。"
        neighborMeaning = "價格低廉"
        neighborUse = "若只是便宜，不一定品質差，用 <code>cheap</code> 就好。"
        flow = @("看似能交差", "細看充滿馬虎", "品質感一下就垮下來")
        hook = "把 <code>shoddy</code> 想成表面有油漆，但一摸就整片掉粉。"
        hookExplanation = "這個字把『隨便做』的痕跡直接指出來。"
        usage = @([ordered]@{ label = "產品"; body = "如果一件東西一拿就知道工法很差，<code>shoddy</code> 的批評就很到位。"}, [ordered]@{ label = "流程"; body = "報告也可以很 <code>shoddy</code>，不是字醜，而是思路和細節都在偷懶。"})
        collocations = @([ordered]@{ phrase = "shoddy workmanship"; register = "製造 / 日常" }, [ordered]@{ phrase = "shoddy reporting"; register = "媒體 / 評論" })
        modernUse = @("<code>shoddy</code> 很常用來批評產品、內容和流程品質，語氣直接而不客氣。")
    }
    [ordered]@{
        slug = "solicitous"
        word = "Solicitous"
        partOfSpeech = "adjective"
        pronunciation = "suh-LIS-it-us · UK /səˈlɪs.ɪ.təs/ · US /səˈlɪs.ə.t̬əs/"
        cefr = "C2"
        zipf = "2.08"
        thesis = "不是客氣，而是帶著照看意味的關心。"
        selfMeaning = "體貼掛心"
        selfUse = "用在人對他人需求、舒適或安危特別留心時。"
        contrastWord = "Polite"
        contrastNote = "<code>polite</code> 是有禮；<code>solicitous</code> 更像真正把對方放進心裡照看。"
        neighborMeaning = "有禮貌、守分寸"
        neighborUse = "若只是表面禮貌，用 <code>polite</code> 更直接。"
        flow = @("注意到對方需要", "主動多看一眼", "關心裡帶著照料感")
        hook = "把 <code>solicitous</code> 想成不是說歡迎，而是先幫你把椅子調到最舒服。"
        hookExplanation = "這個字裡有一層溫柔的主動性。"
        usage = @([ordered]@{ label = "照顧"; body = "如果一個人關心不是停在嘴上，而是會主動顧細節，就很 <code>solicitous</code>。"}, [ordered]@{ label = "服務"; body = "過度 <code>solicitous</code> 有時也會讓人覺得被盯得太緊。"})
        collocations = @([ordered]@{ phrase = "solicitous host"; register = "人際 / 敘事" }, [ordered]@{ phrase = "solicitous concern"; register = "正式 / 評述" })
        modernUse = @("<code>solicitous</code> 常用來描寫帶照料感的關心，細緻到有時幾乎過頭。")
    }
    [ordered]@{
        slug = "sparse"
        word = "Sparse"
        partOfSpeech = "adjective"
        pronunciation = "SPAHS · UK /spɑːs/ · US /spɑːrs/"
        cefr = "B2"
        zipf = "3.00"
        thesis = "不是少，而是點和點之間隔得很開。"
        selfMeaning = "稀疏分散"
        selfUse = "用在資料、人口、植被或說明少且分布鬆散時。"
        contrastWord = "Scant"
        contrastNote = "<code>scant</code> 強調少得不夠；<code>sparse</code> 更強調分布疏開。"
        neighborMeaning = "少到接近不足"
        neighborUse = "若重點是量不夠，用 <code>scant</code> 更準。"
        flow = @("數量本來就不密", "彼此距離拉開", "整體留下很多空白")
        hook = "把 <code>sparse</code> 想成不是缺幾棵樹，而是一整片地只有零零落落幾棵。"
        hookExplanation = "它的視覺重點在空白感。"
        usage = @([ordered]@{ label = "資料"; body = "如果樣本點之間隔很大，資料看起來就會很 <code>sparse</code>。"}, [ordered]@{ label = "設計"; body = "介面也可以刻意做得 <code>sparse</code>，讓空白成為一部分訊息。"})
        collocations = @([ordered]@{ phrase = "sparse data"; register = "研究 / 工程" }, [ordered]@{ phrase = "sparse population"; register = "地理 / 報導" })
        modernUse = @("<code>sparse</code> 在資料科學、設計和地理語境都很常用，因為它精準寫出『少且疏開』。")
    }
    [ordered]@{
        slug = "staunch"
        word = "Staunch"
        partOfSpeech = "adjective"
        pronunciation = "STAWNCH · UK /stɔːntʃ/ · US /stɔːntʃ/"
        cefr = "C1"
        zipf = "2.58"
        thesis = "不是支持，而是支持得很穩、很硬。"
        selfMeaning = "堅定力挺"
        selfUse = "用在忠誠、支持或立場穩固不搖時。"
        contrastWord = "Loyal"
        contrastNote = "<code>loyal</code> 是忠誠；<code>staunch</code> 更像公開而堅定地站住。"
        neighborMeaning = "忠誠、不背叛"
        neighborUse = "若只要說忠誠，用 <code>loyal</code> 更常見。"
        flow = @("立場先明確", "外界壓力來了", "支持仍穩穩站住")
        hook = "把 <code>staunch</code> 想成不是在旁邊點頭，而是整個人站到你前面。"
        hookExplanation = "這個字稱讚的是立場的硬度。"
        usage = @([ordered]@{ label = "支持"; body = "如果一個人不是偶爾幫你，而是始終很 <code>staunch</code> 地站在那裡，他的支持就很有分量。"}, [ordered]@{ label = "立場"; body = "談價值或政策時，<code>staunch</code> 常用來形容立場非常穩的支持者。"})
        collocations = @([ordered]@{ phrase = "staunch supporter"; register = "政治 / 人際" }, [ordered]@{ phrase = "staunch defender"; register = "公共 / 評論" })
        modernUse = @("<code>staunch</code> 很適合寫那種不只是支持，而且在壓力下仍站得很穩的態度。")
    }
    [ordered]@{
        slug = "stifle"
        word = "Stifle"
        partOfSpeech = "verb"
        pronunciation = "STY-fuhl · UK /ˈstaɪ.fəl/ · US /ˈstaɪ.fəl/"
        cefr = "C1"
        zipf = "2.68"
        thesis = "不是停止，而是捂住、不讓它長出來。"
        selfMeaning = "壓住悶死"
        selfUse = "用在創意、聲音、表達或成長被壓到難以展開時。"
        contrastWord = "Suppress"
        contrastNote = "<code>suppress</code> 比較正式；<code>stifle</code> 更有被悶住、透不過氣的感覺。"
        neighborMeaning = "壓制、不讓它出來"
        neighborUse = "若是制度性壓制或正式語境，用 <code>suppress</code> 更常見。"
        flow = @("東西本來要冒出", "外力把它壓住", "結果被悶到長不開")
        hook = "把 <code>stifle</code> 想成火苗不是被水澆滅，而是被厚布悶住。"
        hookExplanation = "它讓人感到窒悶，而不只是結束。"
        usage = @([ordered]@{ label = "創意"; body = "如果流程嚴到沒人敢提新點子，那就是在 <code>stifle</code> creativity。"}, [ordered]@{ label = "情緒"; body = "人也可以 <code>stifle</code> a laugh，把快冒出的反應硬壓回去。"})
        collocations = @([ordered]@{ phrase = "stifle innovation"; register = "管理 / 產品" }, [ordered]@{ phrase = "stifle a laugh"; register = "敘事 / 日常" })
        modernUse = @("<code>stifle</code> 在組織和人際語境都好用，因為它寫的是被壓到透不過氣、發展不起來。")
    }
    [ordered]@{
        slug = "stigma"
        word = "Stigma"
        partOfSpeech = "noun"
        pronunciation = "STIG-muh · UK /ˈstɪɡ.mə/ · US /ˈstɪɡ.mə/"
        cefr = "C1"
        zipf = "3.17"
        thesis = "不是標籤，而是帶羞恥與排斥感的標記。"
        selfMeaning = "污名烙印"
        selfUse = "用在某身分、疾病或經歷被社會附著羞恥與排斥時。"
        contrastWord = "Label"
        contrastNote = "<code>label</code> 可以中性；<code>stigma</code> 幾乎一定帶負面烙印。"
        neighborMeaning = "被命名、被歸類"
        neighborUse = "若只是分類，不帶羞恥感，用 <code>label</code> 即可。"
        flow = @("社會先貼上看法", "當事人被附著羞恥", "人因此被推遠或自我收縮")
        hook = "把 <code>stigma</code> 想成不是便利貼，而是難洗掉的印記。"
        hookExplanation = "它的重點是社會眼光如何黏在人身上。"
        usage = @([ordered]@{ label = "社會"; body = "談心理健康、貧窮或疾病時，<code>stigma</code> 常指那層讓人不敢開口的社會羞恥。"}, [ordered]@{ label = "組織"; body = "如果求助被看成軟弱，團隊裡就會慢慢形成一種 <code>stigma</code>。"})
        collocations = @([ordered]@{ phrase = "social stigma"; register = "社會 / 政策" }, [ordered]@{ phrase = "stigma around mental health"; register = "醫療 / 公共" })
        modernUse = @("<code>stigma</code> 在公共衛生、社會政策與 DEI 討論都非常關鍵，因為它抓住的是羞恥如何被制度化。")
    }
    [ordered]@{
        slug = "stipulate"
        word = "Stipulate"
        partOfSpeech = "verb"
        pronunciation = "STIP-yuh-layt · UK /ˈstɪp.jə.leɪt/ · US /ˈstɪp.jə.leɪt/"
        cefr = "C1"
        zipf = "2.59"
        thesis = "不是提到，而是明白寫成必須遵守的條件。"
        selfMeaning = "明文規定"
        selfUse = "用在合約、條款或正式安排把要求寫死時。"
        contrastWord = "Mention"
        contrastNote = "<code>mention</code> 只是提到；<code>stipulate</code> 是把它寫成約束條件。"
        neighborMeaning = "說到、提及"
        neighborUse = "若沒有約束力，只是單純提到，用 <code>mention</code> 就夠。"
        flow = @("條件被提出", "寫進正式文本", "之後成為可執行要求")
        hook = "把 <code>stipulate</code> 想成不是口頭提醒，而是把規則釘進紙上。"
        hookExplanation = "它很有合約和治理的味道。"
        usage = @([ordered]@{ label = "合約"; body = "如果某條件不是建議而是必須遵守，就會被 <code>stipulate</code> 在合約裡。"}, [ordered]@{ label = "流程"; body = "制度文件常用 <code>stipulate</code> 來把模糊空間收緊。"})
        collocations = @([ordered]@{ phrase = "stipulate that"; register = "法律 / 正式" }, [ordered]@{ phrase = "stipulate the terms"; register = "合約 / 治理" })
        modernUse = @("<code>stipulate</code> 在法律、採購與治理文件特別常見，因為它精準指向『寫成硬條件』。")
    }
    [ordered]@{
        slug = "stoic"
        word = "Stoic"
        partOfSpeech = "adjective"
        pronunciation = "STOH-ik · UK /ˈstəʊ.ɪk/ · US /ˈstoʊ.ɪk/"
        cefr = "C1"
        zipf = "2.83"
        thesis = "不是沒感覺，而是不讓感覺把自己沖走。"
        selfMeaning = "克制沉著"
        selfUse = "用在人面對痛苦、壓力或混亂時仍保持克制時。"
        contrastWord = "Emotionless"
        contrastNote = "<code>emotionless</code> 像沒有情緒；<code>stoic</code> 則是有情緒但穩住不外露。"
        neighborMeaning = "缺少情緒表現"
        neighborUse = "若重點是看不出情緒，用 <code>emotionless</code> 更直白。"
        flow = @("壓力或痛苦先來", "情緒沒有失控外溢", "整個人仍穩穩站著")
        hook = "把 <code>stoic</code> 想成風很大，但人把重心壓低，沒有被吹跑。"
        hookExplanation = "這個字不是冰冷，而是克制。"
        usage = @([ordered]@{ label = "人物"; body = "如果一個人在壞消息面前沒有戲劇性崩掉，反而穩穩接住，那種感覺就很 <code>stoic</code>。"}, [ordered]@{ label = "文化"; body = "某些團隊會把 <code>stoic</code> 當成美德，但也可能因此不敢求助。"})
        collocations = @([ordered]@{ phrase = "stoic calm"; register = "敘事 / 人物" }, [ordered]@{ phrase = "stoic endurance"; register = "評論 / 正式" })
        modernUse = @("<code>stoic</code> 在現代語境既可能是稱讚，也可能暗示情緒被壓太久，要看上下文。")
    }
    [ordered]@{
        slug = "strident"
        word = "Strident"
        partOfSpeech = "adjective"
        pronunciation = "STRY-dənt · UK /ˈstraɪ.dənt/ · US /ˈstraɪ.dənt/"
        cefr = "C2"
        zipf = "2.23"
        thesis = "不是大聲，而是大聲到刺耳、壓人。"
        selfMeaning = "刺耳強硬"
        selfUse = "用在聲音、語氣或立場又硬又尖時。"
        contrastWord = "Loud"
        contrastNote = "<code>loud</code> 只是聲量大；<code>strident</code> 更像高而刺、帶壓迫感。"
        neighborMeaning = "聲音大"
        neighborUse = "若只是分貝高，用 <code>loud</code> 即可。"
        flow = @("聲量先被推高", "質地開始刺耳", "整體帶出壓迫與對抗感")
        hook = "把 <code>strident</code> 想成喇叭不只是開大，而是尖到讓人想退。"
        hookExplanation = "它批評的是聲音或立場的質地。"
        usage = @([ordered]@{ label = "語氣"; body = "有些聲明不是堅定，而是過度 <code>strident</code>，讓人先被刺到。"}, [ordered]@{ label = "媒體"; body = "形容輿論時，<code>strident</code> 常帶一種越喊越硬、越喊越尖的感覺。"})
        collocations = @([ordered]@{ phrase = "strident tone"; register = "媒體 / 評論" }, [ordered]@{ phrase = "strident criticism"; register = "公共 / 政治" })
        modernUse = @("<code>strident</code> 很適合用來批評過度尖銳、刺耳的聲音與立場，比 aggressive 更有聽覺感。")
    }
    [ordered]@{
        slug = "strife"
        word = "Strife"
        partOfSpeech = "noun"
        pronunciation = "STRYF · UK /straɪf/ · US /straɪf/"
        cefr = "C1"
        zipf = "2.59"
        thesis = "不是爭論，而是衝突已經讓關係和局面裂開。"
        selfMeaning = "衝突紛爭"
        selfUse = "用在群體、家庭、社會或組織裡長出明顯裂痕時。"
        contrastWord = "Dispute"
        contrastNote = "<code>dispute</code> 可以是單一爭議；<code>strife</code> 更像衝突蔓延成局面。"
        neighborMeaning = "一件待處理的爭議"
        neighborUse = "若只是單一糾紛，用 <code>dispute</code> 較中性。"
        flow = @("先有分歧", "衝突往外擴張", "關係和秩序被撕裂")
        hook = "把 <code>strife</code> 想成不是一條裂縫，而是整面牆開始往外崩。"
        hookExplanation = "它比 quarrel 大，也比 tension 更破。"
        usage = @([ordered]@{ label = "組織"; body = "如果分歧已經不是幾場爭執，而是讓整個團隊陷入 <code>strife</code>，問題就很深了。"}, [ordered]@{ label = "社會"; body = "新聞裡的 civil <code>strife</code> 常指衝突已經滲進整個社會。"})
        collocations = @([ordered]@{ phrase = "civil strife"; register = "政治 / 新聞" }, [ordered]@{ phrase = "internal strife"; register = "組織 / 評論" })
        modernUse = @("<code>strife</code> 常見於社會與組織衝突書寫，因為它能把裂痕已經擴成局面的感覺寫出來。")
    }
    [ordered]@{
        slug = "stymie"
        word = "Stymie"
        partOfSpeech = "verb"
        pronunciation = "STY-mee · UK /ˈstaɪ.mi/ · US /ˈstaɪ.mi/"
        cefr = "C1"
        zipf = "2.34"
        thesis = "不是延遲，而是硬生生卡住前進。"
        selfMeaning = "卡死阻住"
        selfUse = "用在進度、方案或成長被某個障礙拖到動不了時。"
        contrastWord = "Delay"
        contrastNote = "<code>delay</code> 只是慢下來；<code>stymie</code> 更像整個被卡住。"
        neighborMeaning = "延後、拖慢"
        neighborUse = "若只是往後延，用 <code>delay</code> 更簡單。"
        flow = @("前進原本還在動", "障礙突然卡進來", "進度被整個頂住")
        hook = "把 <code>stymie</code> 想成齒輪不是變慢，而是直接卡死。"
        hookExplanation = "這個字的阻塞感很強。"
        usage = @([ordered]@{ label = "專案"; body = "如果一個依賴沒打通，整個專案會被 <code>stymie</code> 得很明顯。"}, [ordered]@{ label = "成長"; body = "有些人不是不努力，而是被看不見的結構性條件 <code>stymie</code> 住。"})
        collocations = @([ordered]@{ phrase = "stymie progress"; register = "管理 / 政策" }, [ordered]@{ phrase = "stymied by regulation"; register = "商務 / 媒體" })
        modernUse = @("<code>stymie</code> 很適合描述進度卡死而不是單純變慢，常見於專案、政策與職涯討論。")
    }
    [ordered]@{
        slug = "subdued"
        word = "Subdued"
        partOfSpeech = "adjective"
        pronunciation = "sub-DOOD · UK /səbˈdjuːd/ · US /səbˈduːd/"
        cefr = "C1"
        zipf = "2.75"
        thesis = "不是安靜，而是被壓低到很收。"
        selfMeaning = "壓低收斂"
        selfUse = "用在色彩、情緒、燈光或反應被刻意收低時。"
        contrastWord = "Quiet"
        contrastNote = "<code>quiet</code> 只是安靜；<code>subdued</code> 更像原本能更高、但被壓下來。"
        neighborMeaning = "音量低、環境安靜"
        neighborUse = "若只是沒有聲音，用 <code>quiet</code> 即可。"
        flow = @("原本可能更鮮或更強", "整體被往下壓", "只留下收斂過的版本")
        hook = "把 <code>subdued</code> 想成燈不是關掉，而是調到很低。"
        hookExplanation = "它帶的是被收住、被壓暗的感覺。"
        usage = @([ordered]@{ label = "情緒"; body = "如果大家不是開心吵鬧，而是帶著一點沉著地慶祝，氣氛就很 <code>subdued</code>。"}, [ordered]@{ label = "設計"; body = "談色彩時，<code>subdued</code> 常指飽和度和衝擊感都被收低。"})
        collocations = @([ordered]@{ phrase = "subdued lighting"; register = "空間 / 設計" }, [ordered]@{ phrase = "subdued response"; register = "評論 / 人際" })
        modernUse = @("<code>subdued</code> 很適合寫那些不是沒有，而是被收斂過後的氣氛、色彩與反應。")
    }
    [ordered]@{
        slug = "succumb"
        word = "Succumb"
        partOfSpeech = "verb"
        pronunciation = "suh-KUM · UK /səˈkʌm/ · US /səˈkʌm/"
        cefr = "C1"
        zipf = "2.70"
        thesis = "不是輸，而是撐到最後還是倒下。"
        selfMeaning = "終究屈倒"
        selfUse = "用在抵抗一段時間後，最後還是被壓力、誘惑或疾病擊倒時。"
        contrastWord = "Yield"
        contrastNote = "<code>yield</code> 可以是主動讓；<code>succumb</code> 更像撐到最後還是被壓倒。"
        neighborMeaning = "讓步、退讓"
        neighborUse = "若是主動退一步，用 <code>yield</code> 更合適。"
        flow = @("先努力撐著", "力量慢慢不夠", "最後還是倒向那股壓力")
        hook = "把 <code>succumb</code> 想成不是一碰就倒，而是撐很久後膝蓋終於彎下去。"
        hookExplanation = "它帶著抵抗過的痕跡。"
        usage = @([ordered]@{ label = "壓力"; body = "如果一個人先撐住很多輪，最後還是被疲勞擊倒，就可以說他 <code>succumbed</code> to it。"}, [ordered]@{ label = "誘惑"; body = "形容人最後還是向誘惑低頭，<code>succumb</code> 比 give in 更有被拖倒的味道。"})
        collocations = @([ordered]@{ phrase = "succumb to pressure"; register = "人際 / 管理" }, [ordered]@{ phrase = "succumb to illness"; register = "醫療 / 正式" })
        modernUse = @("<code>succumb</code> 在健康、壓力與誘惑語境都很有力，因為它把『撐過、最後還是倒』寫得很清楚。")
    }
    [ordered]@{
        slug = "suffice"
        word = "Suffice"
        partOfSpeech = "verb"
        pronunciation = "suh-FYSE · UK /səˈfaɪs/ · US /səˈfaɪs/"
        cefr = "C1"
        zipf = "2.73"
        thesis = "不是很多，而是剛好夠。"
        selfMeaning = "足以夠用"
        selfUse = "用在不追求更多，只要達到足夠門檻時。"
        contrastWord = "Enough"
        contrastNote = "<code>enough</code> 很日常；<code>suffice</code> 更書面，也更像正式判定『夠了』。"
        neighborMeaning = "量或程度已經夠"
        neighborUse = "若是一般口語，直接用 <code>enough</code> 最自然。"
        flow = @("需求先被看清", "資源或說明達到門檻", "更多就不再必要")
        hook = "把 <code>suffice</code> 想成不是把杯子倒滿，而是水剛好淹過那條需要的線。"
        hookExplanation = "它很適合用來畫『夠』的邊界。"
        usage = @([ordered]@{ label = "說明"; body = "正式寫作裡常見 to <code>suffice</code> it to say，意思是講到這裡已經夠了。"}, [ordered]@{ label = "資源"; body = "有時不需要最好的方案，只要一個足以 <code>suffice</code> 的做法。"})
        collocations = @([ordered]@{ phrase = "suffice it to say"; register = "正式 / 寫作" }, [ordered]@{ phrase = "will suffice"; register = "日常 / 正式" })
        modernUse = @("<code>suffice</code> 在正式英文裡很常用來畫出『夠了，不必再多』的邊線。")
    }
    [ordered]@{
        slug = "sully"
        word = "Sully"
        partOfSpeech = "verb"
        pronunciation = "SUL-ee · UK /ˈsʌl.i/ · US /ˈsʌl.i/"
        cefr = "C1"
        zipf = "2.38"
        thesis = "不是弄髒而已，而是把原本的潔淨或名聲抹上一層污。"
        selfMeaning = "玷污抹黑"
        selfUse = "用在名聲、記憶、形象或象徵被弄髒時。"
        contrastWord = "Stain"
        contrastNote = "<code>stain</code> 可以是物理污漬；<code>sully</code> 更常延伸到名譽與象徵。"
        neighborMeaning = "留下污點或痕跡"
        neighborUse = "若是具體污漬，用 <code>stain</code> 更直接。"
        flow = @("原本有一層潔淨感", "污點被抹上去", "之後看它都帶著那層髒")
        hook = "把 <code>sully</code> 想成白襯衫不是沾灰，而是被甩上一道很難忽略的墨。"
        hookExplanation = "這個字常把物理髒轉成名聲上的髒。"
        usage = @([ordered]@{ label = "名聲"; body = "如果一件醜聞把多年建立的信任弄髒了，就很像在 <code>sully</code> that reputation。"}, [ordered]@{ label = "記憶"; body = "某些細節不一定改變事實，但會 <code>sully</code> 原本乾淨的回憶。"})
        collocations = @([ordered]@{ phrase = "sully a reputation"; register = "媒體 / 人際" }, [ordered]@{ phrase = "sully the memory"; register = "敘事 / 評論" })
        modernUse = @("<code>sully</code> 在名譽、品牌與象徵書寫裡很好用，因為它能把『變髒』延伸成『被玷污』。")
    }
    [ordered]@{
        slug = "sunder"
        word = "Sunder"
        partOfSpeech = "verb"
        pronunciation = "SUN-der · UK /ˈsʌn.də/ · US /ˈsʌn.dɚ/"
        cefr = "C2"
        zipf = "2.04"
        thesis = "不是分開，而是硬生生裂成兩邊。"
        selfMeaning = "劈裂分離"
        selfUse = "用在關係、群體或整體被劇烈扯開時。"
        contrastWord = "Separate"
        contrastNote = "<code>separate</code> 是分開；<code>sunder</code> 更像被撕裂。"
        neighborMeaning = "一般地分開、拆開"
        neighborUse = "若沒有劇烈撕裂感，用 <code>separate</code> 更中性。"
        flow = @("原本是一體", "外力把它扯開", "兩邊出現不可忽視的裂口")
        hook = "把 <code>sunder</code> 想成布不是剪開，而是從中間硬扯裂。"
        hookExplanation = "它的張力比 divide 強，也比 split 更帶撕裂。"
        usage = @([ordered]@{ label = "群體"; body = "如果一個事件把原本同陣線的人整個扯開，<code>sunder</code> 的畫面就很強。"}, [ordered]@{ label = "敘事"; body = "文學裡常用 <code>sunder</code> 寫命運或戰爭如何把人分裂。"})
        collocations = @([ordered]@{ phrase = "sundered by war"; register = "敘事 / 歷史" }, [ordered]@{ phrase = "sunder the alliance"; register = "政治 / 評論" })
        modernUse = @("<code>sunder</code> 偏文學，但在需要寫出『被硬生生扯裂』的時候，力道很足。")
    }
    [ordered]@{
        slug = "surly"
        word = "Surly"
        partOfSpeech = "adjective"
        pronunciation = "SUR-lee · UK /ˈsɜː.li/ · US /ˈsɝː.li/"
        cefr = "C1"
        zipf = "2.49"
        thesis = "不是安靜，而是不友善地板著臉。"
        selfMeaning = "板臉粗暴"
        selfUse = "用在人態度粗、臉色硬、讓人很難靠近時。"
        contrastWord = "Grumpy"
        contrastNote = "<code>grumpy</code> 可能只是心情差；<code>surly</code> 更直接帶出不友善。"
        neighborMeaning = "不高興、愛抱怨"
        neighborUse = "若只是情緒不好，用 <code>grumpy</code> 更口語。"
        flow = @("情緒先壓低", "表情開始發硬", "互動裡透出不友善")
        hook = "把 <code>surly</code> 想成門不是關著，而是你一碰門把就先被瞪一眼。"
        hookExplanation = "這個字寫的是態度的粗硬。"
        usage = @([ordered]@{ label = "服務"; body = "如果回應不是冷靜，而是帶著很明顯的不耐和刺，會顯得 <code>surly</code>。"}, [ordered]@{ label = "人物"; body = "形容角色時，<code>surly</code> 常讓人一眼知道他不好接近。"})
        collocations = @([ordered]@{ phrase = "surly attitude"; register = "人際 / 評論" }, [ordered]@{ phrase = "surly response"; register = "服務 / 敘事" })
        modernUse = @("<code>surly</code> 很適合寫表面不爆炸、但互動上明顯粗硬不友善的人。")
    }
    [ordered]@{
        slug = "sway"
        word = "Sway"
        partOfSpeech = "verb"
        pronunciation = "SWAY · UK /sweɪ/ · US /sweɪ/"
        cefr = "B2"
        zipf = "3.40"
        thesis = "不是碰到，而是把方向帶偏過去。"
        selfMeaning = "牽動改向"
        selfUse = "用在意見、情緒、票向或決定被力量帶向另一邊時。"
        contrastWord = "Influence"
        contrastNote = "<code>influence</code> 很廣；<code>sway</code> 更像把鐘擺推向另一側。"
        neighborMeaning = "造成影響"
        neighborUse = "若只想說有影響力，用 <code>influence</code> 更通用。"
        flow = @("原本還在中間", "外力開始拉扯", "方向慢慢偏過去")
        hook = "把 <code>sway</code> 想成鐘擺不是震一下，而是被一股力推到另一邊。"
        hookExplanation = "它比 affect 更有方向感。"
        usage = @([ordered]@{ label = "決策"; body = "有些數據不一定決定一切，但會明顯 <code>sway</code> 最後的判斷。"}, [ordered]@{ label = "輿論"; body = "談選舉或輿論時，<code>sway</code> 很適合寫那些把票向推動的力量。"})
        collocations = @([ordered]@{ phrase = "sway opinion"; register = "公共 / 媒體" }, [ordered]@{ phrase = "sway the decision"; register = "管理 / 分析" })
        modernUse = @("<code>sway</code> 在說服、輿論與決策語境很常見，因為它把影響寫成有方向的推動。")
    }
)

$seen = New-Object "System.Collections.Generic.HashSet[string]"

foreach ($entry in $entries) {
    if (-not $seen.Add($entry.slug)) {
        throw "Duplicate slug in new batch: $($entry.slug)"
    }
}

$manifestLines = @("payload")

foreach ($entry in $entries) {
    $wordLower = $entry.word.ToLowerInvariant()
    $sources = New-SourceNotes $entry
    $tags = New-Tags $entry
    $origin = New-Origin $entry
    $usageItems = New-UsageItems $entry
    $collocationItems = New-CollocationItems $entry

    $payload = [ordered]@{
        target = [ordered]@{
            word = $entry.word
            slug = $entry.slug
            outputPath = "prototypes/$($entry.slug).html"
        }
        page = [ordered]@{
            partOfSpeech = $entry.partOfSpeech
            pronunciation = $entry.pronunciation
            hero = [ordered]@{
                thesis = $entry.thesis
                cefrLevel = $entry.cefr
                zipfFrequency = $entry.zipf
            }
            coreIdea = Get-CoreIdea $entry
            definition = [ordered]@{
                summary = Get-DefinitionSummary $entry
                contrast = [ordered]@{
                    word = $entry.contrastWord
                    note = $entry.contrastNote
                }
                flow = $entry.flow
            }
            origin = $origin
            memory = [ordered]@{
                hook = $entry.hook
                explanation = $entry.hookExplanation
            }
            usage = $usageItems
            collocations = [ordered]@{
                note = Get-CollocationSectionNote $entry
                items = $collocationItems
            }
            neighbors = [ordered]@{
                self = [ordered]@{
                    meaning = $entry.selfMeaning
                    use = $entry.selfUse
                }
                others = @(
                    [ordered]@{
                        word = $entry.contrastWord
                        meaning = $entry.neighborMeaning
                        use = $entry.neighborUse
                    }
                )
            }
            modernUse = $entry.modernUse
            sources = $sources
        }
        indexEntry = [ordered]@{
            id = $entry.slug
            word = $entry.word
            partOfSpeech = $entry.partOfSpeech
            href = "./$($entry.slug).html"
            thesis = $entry.thesis
            tags = $tags
        }
        sourceAudit = @(
            [ordered]@{
                category = "dictionary-pronunciation"
                label = "Merriam-Webster"
                url = "https://www.merriam-webster.com/dictionary/$wordLower"
                usedFor = "definition, pronunciation, and dictionary sense support"
            }
            [ordered]@{
                category = "level-frequency"
                label = "wordfreq Zipf + repo CEFR calibration"
                url = "https://github.com/rspeer/wordfreq"
                usedFor = "Zipf frequency reference and repo-calibrated CEFR study band"
            }
            [ordered]@{
                category = "etymology-history"
                label = "Online Etymology Dictionary"
                url = "https://www.etymonline.com/word/$wordLower"
                usedFor = "etymology and word-history support"
            }
            [ordered]@{
                category = "modern-common-usage"
                label = "Merriam-Webster"
                url = "https://www.merriam-webster.com/dictionary/$wordLower"
                usedFor = "modern usage examples and current usage boundaries"
            }
        )
    }

    $json = ($payload | ConvertTo-Json -Depth 12) + "`n"
    $payloadPath = Join-Path $PayloadDir "$($entry.slug).json"
    Write-Utf8NoBom -Path $payloadPath -Content $json
    $manifestLines += "data/word-payloads/$($entry.slug).json"
}

Write-Utf8NoBom -Path $BatchPath -Content (($manifestLines -join "`n") + "`n")
Write-Host "Generated $($entries.Count) payloads and wrote $BatchPath"
