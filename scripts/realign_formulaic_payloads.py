from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEPRECATED_NOTICE = (
    "scripts/realign_formulaic_payloads.py is deprecated because it can create "
    "template-like prose. Prefer hand-authored semantic payloads plus "
    "scripts/generate_batch_word_pages.py validation. Re-run with --force only "
    "for intentional legacy repair, then validate and review the rendered pages."
)


def load_payload(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_payload(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def contains_cjk(text: str) -> bool:
    return any("\u4e00" <= ch <= "\u9fff" for ch in text)


def pick_variant(seed: str, size: int) -> int:
    return sum(ord(ch) for ch in seed) % size


def split_thesis(thesis: str) -> tuple[str, str]:
    text = thesis.strip().rstrip("。")
    if "而是" in text:
        left, right = text.split("而是", 1)
        left = left.removeprefix("不是").strip(" ，、；：")
        right = right.strip(" ，、；：")
        return left or "表面上的近似說法", right or text
    return "表面上的近似說法", text


def clean_rejected(text: str) -> str:
    cleaned = text.strip()
    for prefix in ("單純的", "單純", "普通的", "普通", "只是", "僅僅", "單只"):
        if cleaned.startswith(prefix):
            cleaned = cleaned[len(prefix) :]
    cleaned = cleaned.replace("而已", "")
    return cleaned.strip(" 「」『』，。；：") or text.strip()


def chinese_tags(tags: list[str]) -> list[str]:
    return [tag for tag in tags if contains_cjk(tag)]


def base_definition_text(text: str) -> str:
    parts = [part.strip() for part in text.split("。") if part.strip()]
    if not parts:
        return text.strip()
    return parts[0]


def build_core_idea(word_code: str, pos: str, actual: str, focus: str, variant: int) -> str:
    if pos == "verb":
        options = [
            f"{word_code} 常用在句子需要把動作往「{focus}」這個方向收緊時。重點不只是做了什麼，而是事情因此偏向哪一種選擇。",
            f"{word_code} 不只是交代動作發生；它更常用來指出事情怎麼朝「{focus}」這條線走。",
            f"{word_code} 的力道，在於它會把動作背後那層「{actual}」說得更清楚，不讓句子只停在表面的中文對應。",
        ]
    elif pos == "noun":
        options = [
            f"{word_code} 用來把場面裡的「{focus}」正式點出來，讓它從感受或評語變成可以被命名的東西。",
            f"{word_code} 的作用，是把「{actual}」收成一個可被指出的名詞，所以句子會立刻多一層份量。",
            f"{word_code} 不只是替好壞下評語；它是在替「{focus}」這種分量找一個正式的名字。",
        ]
    else:
        options = [
            f"{word_code} 用來說某個人、系統或局面帶著「{focus}」這種質地。它不是單純加強語氣，而是改變你怎麼看整個對象。",
            f"{word_code} 真正抓住的，不是程度高低，而是整體怎麼被「{actual}」這個感覺支配。",
            f"{word_code} 一出現，通常就在提醒你：眼前這個對象不是普通地呈現，而是整體都帶著「{focus}」這層氣質。",
        ]
    return options[variant % len(options)]


def build_summary(pos: str, short_def: str, actual: str, focus: str, variant: int) -> str:
    if pos == "verb":
        options = [
            f"{short_def}。這個字常不是在描述機械動作，而是在說事情怎麼往「{focus}」這個方向走。",
            f"{short_def}。它要補上的，通常不是動作本身，而是那層更具體的「{actual}」。",
            f"{short_def}。讀到它時，最好不要只翻成中文動詞，而要留意句子想把事情收斂到哪一種走向。",
        ]
    elif pos == "noun":
        options = [
            f"{short_def}。這個名詞把場面裡那份「{focus}」收成一個可以被指出的東西。",
            f"{short_def}。它不是把事情說得更重，而是讓那份分量有一個正式的名字。",
            f"{short_def}。用到它時，句子通常已經不只是感受描述，而是在點出某個可被談論的對象。",
        ]
    else:
        options = [
            f"{short_def}。重點不是程度加強，而是整個對象都帶著「{focus}」這種質地。",
            f"{short_def}。它會影響的，不只是一個特徵，而是你怎麼判斷整個場面。",
            f"{short_def}。比起單純描述性質，它更像在標記一種會主導整體觀感的氣質。",
        ]
    return options[variant % len(options)]


def build_contrast_note(
    word_code: str,
    contrast_code: str,
    simpler_meaning: str,
    actual: str,
    focus: str,
    variant: int,
) -> str:
    clean = clean_rejected(simpler_meaning)
    options = [
        f"{contrast_code} 可以只是在說「{clean}」；換成 {word_code}，句子通常是在補上「{focus}」這層更具體的意思。",
        f"如果語境只需要比較平的「{clean}」，用 {contrast_code} 往往就夠了；{word_code} 則會把「{actual}」講得更明確。",
        f"{contrast_code} 比較像基礎說法；{word_code} 常用來把那層更具體的「{focus}」拉到前景。",
    ]
    return options[variant % len(options)]


def build_flow(pos: str, actual: str, focus: str, variant: int) -> list[str]:
    if pos == "verb":
        options = [
            [
                "先有一個人、做法、關係或局面",
                f"句子接著把動作往「{focus}」這個方向推進",
                "所以最後留下的，不只是動作完成，還有那個轉向本身",
            ],
            [
                "先有一件事正在發生",
                f"這個動詞把它收斂到「{actual}」這種更具體的走向",
                "因此你讀到的，不只是行為本身，還有行為帶出的語氣與後果",
            ],
            [
                "先有一個原本還能用一般動詞帶過的場景",
                f"接著句子選擇用「{focus}」來講它",
                "結果語感會從平鋪直述，變成更有方向感的描述",
            ],
        ]
    elif pos == "noun":
        options = [
            [
                "先有一個值得被點出的結果、狀態或評價",
                f"這個名詞把它收成「{focus}」這樣一個可指稱的東西",
                "所以句子不是在補修飾，而是在正式命名",
            ],
            [
                "先有一件原本還像感受或印象的事",
                f"再用這個名詞把它固定成「{actual}」這類可被談論的對象",
                "於是整句話會從氣氛描述，變成比較明確的指認",
            ],
            [
                "先有一個場面裡明顯存在的分量",
                f"接著用這個名詞把「{focus}」收進語言裡",
                "結果你讀到的，就不只是評語，而是一個被正式點出的東西",
            ],
        ]
    else:
        options = [
            [
                "先有一個人、流程、系統或局面",
                f"它在語境裡露出「{focus}」這種質地",
                "所以你感受到的不是單一特徵，而是整體氣氛被它帶著走",
            ],
            [
                "先有一個對象看起來還能用普通形容詞描述",
                f"接著這個字把它往「{actual}」這種更具體的樣子收緊",
                "所以它不是裝飾，而是在告訴你應該怎麼看那個對象",
            ],
            [
                "先有一個場面本身已經帶著某種性格",
                f"這個形容詞把那層「{focus}」清楚地壓到前景",
                "結果不是多一個修飾，而是整個觀感都被重新定調",
            ],
        ]
    return options[variant % len(options)]


def build_memory_explanation(word: str, actual: str, focus: str, image_tag: str, variant: int) -> str:
    options = [
        f"這個畫面有用，因為它把 {word.lower()} 從翻譯拉回場面：你先看到「{image_tag}」，再比較容易記住它其實在說「{focus}」。",
        f"記這個畫面，不是為了背故事，而是讓你下次看到 {word.lower()} 時，能先抓到「{focus}」這個核心，再回頭讀細節。",
        f"這種記法的好處，是它先讓字義落地。你不用先背抽象定義，而是先把「{actual}」看成一個會發生的場面。",
    ]
    return options[variant % len(options)]


def build_usage_bodies(
    pos: str,
    focus: str,
    actual: str,
    simpler_meaning: str,
    collocations: list[dict[str, str]],
    variant: int,
) -> list[str]:
    clean = clean_rejected(simpler_meaning)
    phrases = [item["phrase"] for item in collocations]
    registers = [item["register"] for item in collocations]
    phrase1 = phrases[0]
    phrase2 = phrases[min(1, len(phrases) - 1)]
    phrase3 = phrases[min(2, len(phrases) - 1)]
    reg1 = registers[0]
    reg2 = registers[min(1, len(registers) - 1)]
    reg3 = registers[min(2, len(registers) - 1)]

    if pos == "verb":
        sets = [
            [
                f"<code>{phrase1}</code> 這種說法會把動作放回它真正會發生的場景裡，讓你看到重點不是字面動作，而是事情怎麼往「{focus}」收過去。",
                f"在 {reg2} 裡，<code>{phrase2}</code> 常用來把語氣收得更準：它不只交代事情做了，還交代事情怎麼帶出那層「{actual}」。",
                f"到了 {reg3} 的場景，<code>{phrase3}</code> 很適合拿來練邊界，因為它會逼你分清楚一般的「{clean}」跟更具體的「{focus}」差在哪。",
            ],
            [
                f"讀到 <code>{phrase1}</code> 時，可以先別急著翻中文；先看句子是不是想把動作往「{focus}」這個方向講清楚。",
                f"<code>{phrase2}</code> 放進 {reg2} 後，常會比一般近義詞更有份量，因為它把結果之外的那層語氣也帶了進來。",
                f"如果你想把這個字放進 {reg3} 的情境，從 <code>{phrase3}</code> 這種搭配進場通常最穩，因為語感邊界很清楚。",
            ],
            [
                f"與其背這個動詞的中文，不如記 <code>{phrase1}</code>：它會直接告訴你這個字最自然的落點在哪裡。",
                f"在 {reg2} 裡，<code>{phrase2}</code> 讓句子多出的，不只是資訊，而是那股往「{focus}」推進的語氣。",
                f"碰到 {reg3} 場景時，<code>{phrase3}</code> 常能幫你把這個字用得不空，因為它讓場面自己說話。",
            ],
        ]
    elif pos == "noun":
        sets = [
            [
                f"<code>{phrase1}</code> 聽起來不像隨口描述，更像是把場面裡那份「{focus}」正式點出來。",
                f"在 {reg2} 裡，<code>{phrase2}</code> 常不是某個人的一時看法，而是已經可以被辨認、被談論的東西。",
                f"到了 {reg3} 的場景，<code>{phrase3}</code> 會讓這個字從抽象印象變成語境裡具體可指的對象。",
            ],
            [
                f"看到 <code>{phrase1}</code> 時，可以先留意一句話：這不是單純形容得更重，而是把「{focus}」正式命名。",
                f"<code>{phrase2}</code> 放到 {reg2} 裡，會讓人感覺那件事已經不是模糊氣氛，而是可以拿出來討論的對象。",
                f"如果你要在 {reg3} 裡用這個字，<code>{phrase3}</code> 是很好的入口，因為它會把名詞真正指向的東西拉清楚。",
            ],
            [
                f"與其只背名詞對應的中文，不如先記 <code>{phrase1}</code> 這個搭配：它會直接示範這個字通常怎麼被點出。",
                f"在 {reg2} 的語境裡，<code>{phrase2}</code> 常用來把場面裡的「{focus}」收成一句能被接住的話。",
                f"到了 {reg3}，<code>{phrase3}</code> 會幫你看見：這個字不是修辭，而是把某種分量正式命名。",
            ],
        ]
    else:
        sets = [
            [
                f"<code>{phrase1}</code> 會把這個字放到最自然的名詞上，讓你看到重點不是單純的「{clean}」，而是整個對象都帶著「{focus}」這種質地。",
                f"在 {reg2} 裡，<code>{phrase2}</code> 常讓語氣多一層判斷，因為它不只描述性質，還在提示你應該怎麼看這個東西。",
                f"到了 {reg3} 的場景，<code>{phrase3}</code> 很適合用來練邊界：你要講的到底是一般的「{clean}」，還是更具體的「{focus}」。",
            ],
            [
                f"看到 <code>{phrase1}</code> 時，可以先抓住一點：這不是把形容詞寫得更漂亮，而是把「{focus}」這層氣質壓到前景。",
                f"<code>{phrase2}</code> 放進 {reg2} 後，通常會比普通近義詞更有畫面，因為它讓整個對象的輪廓變得更清楚。",
                f"如果你想把這個字放進 {reg3} 的情境，從 <code>{phrase3}</code> 這種說法進場通常最自然，因為它會逼你分清楚質地差在哪。",
            ],
            [
                f"與其單背形容詞意思，不如記 <code>{phrase1}</code> 這個搭配：它會直接示範這個字最自然會貼在哪種對象上。",
                f"在 {reg2} 裡，<code>{phrase2}</code> 不是只補一個性質，而是讓讀者一眼看出這個東西正帶著怎樣的氣氛。",
                f"到了 {reg3} 場景時，<code>{phrase3}</code> 常能幫你把這個字用穩，因為它讓抽象質地真正落到名詞上。",
            ],
        ]
    return sets[variant % len(sets)]


def build_collocation_note(pos: str, focus: str, variant: int) -> str:
    if pos == "verb":
        options = [
            "這組搭配會告訴你，這個動詞最自然會把句子往哪種場面推；比只記中文更能抓到用法。",
            "看這些搭配時，重點不是詞組本身，而是這個動詞通常怎麼把事情往更具體的方向收緊。",
            "這些搭配把動作真正會發生的場面拉了出來，讓語感不會停在字典對應上。",
        ]
    elif pos == "noun":
        options = [
            "看這些搭配時，重點不是詞組本身，而是這個名詞通常在哪些場面被點出。",
            "這組搭配的價值，在於它們把名詞最常落地的語境直接攤開了。",
            "把這些搭配一起看，比單背中文更有用，因為你會知道這個名詞通常在哪裡真正站得住。",
        ]
    else:
        options = [
            "這些搭配會把抽象質地落到具體名詞上，讓你看見這個形容詞最自然的著力點。",
            "把這些搭配一起看，比只背中文更有用，因為你會知道這個形容詞通常貼在哪些對象上。",
            "這組搭配的重點，是讓「怎樣的質地」這件事不再飄在空中，而是直接落到名詞上。",
        ]
    return options[variant % len(options)]


def build_collocation_item_notes(
    pos: str,
    focus: str,
    collocations: list[dict[str, str]],
    variant: int,
) -> list[str]:
    registers = [item["register"] for item in collocations]
    if pos == "verb":
        notes = [
            f"這個搭配常出現在需要把事情往「{focus}」講清楚的句子裡。",
            f"放到 {registers[min(1, len(registers) - 1)]} 裡，它會讓動作聽起來不只發生了，還帶著明顯的語氣或後果。",
            f"在 {registers[min(2, len(registers) - 1)]} 的場景裡，這種說法能幫你看清楚它和近義詞的邊界。",
        ]
    elif pos == "noun":
        notes = [
            f"放到 {registers[0]} 的場景裡，這個搭配會把「{focus}」具體點出來。",
            f"在 {registers[min(1, len(registers) - 1)]} 裡，這種說法讓它不再只是感覺，而是可以被拿來指認的對象。",
            f"到了 {registers[min(2, len(registers) - 1)]} 的語境，這個搭配很適合幫你抓住它真正指的是什麼。",
        ]
    else:
        notes = [
            f"這個搭配會讓「{focus}」不再停在抽象定義，而是直接貼到具體名詞上。",
            f"在 {registers[min(1, len(registers) - 1)]} 裡，這種說法常帶出額外的判斷味道，而不只是中性描述。",
            f"如果你想把這個字用穩，從 {registers[min(2, len(registers) - 1)]} 常見的這個搭配進場通常最自然。",
        ]
    return notes[: len(collocations)]


def build_neighbor_self(short_def: str, cn_tags: list[str], actual: str) -> str:
    if cn_tags:
        return cn_tags[0]
    return short_def.rstrip("。")


def build_neighbor_use(pos: str, actual: str, simpler_meaning: str) -> str:
    clean = clean_rejected(simpler_meaning)
    if pos == "verb":
        return f"當你要把事情說成「{actual}」而不只是 {clean} 時"
    if pos == "noun":
        return f"當你要把「{actual}」當成一個可被點出的東西來說，而不只是 {clean} 時"
    return f"當你要強調整體帶著「{actual}」這種質地，而不只是 {clean} 時"


def build_other_use(pos: str, actual: str, simpler_meaning: str) -> str:
    clean = clean_rejected(simpler_meaning)
    if pos == "verb":
        return f"當句子只需要 {clean} 這個動作，不必補上「{actual}」那層走向時"
    if pos == "noun":
        return f"當句子只需要 {clean} 這個比較平的說法，不必把那份「{actual}」正式點名時"
    return f"當句子只需要 {clean} 這個中性描述，不必把「{actual}」這種氣質壓到前景時"


def build_modern_use(
    word_code: str,
    contrast_code: str,
    pos: str,
    focus: str,
    actual: str,
    simpler_meaning: str,
    collocations: list[dict[str, str]],
    variant: int,
) -> list[str]:
    phrase1 = collocations[0]["phrase"]
    phrase2 = collocations[min(1, len(collocations) - 1)]["phrase"]
    clean = clean_rejected(simpler_meaning)
    if pos == "verb":
        options = [
            [
                f"在今天的英文裡，{word_code} 常出現在 <code>{phrase1}</code>、<code>{phrase2}</code> 這類搭配裡。真正有用的不是背它對應哪個中文，而是看它怎麼把動作往「{focus}」這個方向收緊。",
                f"如果一句話只想表達比較平的「{clean}」，{contrast_code} 往往就夠了；但當語境需要那層更具體的「{actual}」，{word_code} 會更準。",
            ],
            [
                f"{word_code} 在現代語境裡很少只是字面動作。它常被拿來把一句話的走向講得更清楚，尤其是在 <code>{phrase1}</code> 這類搭配裡更明顯。",
                f"所以它和 {contrast_code} 的差別，通常不在難度，而在句子要不要把那層「{focus}」明白說出來。",
            ],
            [
                f"現在看到 {word_code}，可以先看它黏著哪些搭配出現。像 <code>{phrase1}</code>、<code>{phrase2}</code> 都在提醒你：這個字擅長把動作往更有方向感的地方推。",
                f"也因此，它不只是 {contrast_code} 的華麗版本，而是專門拿來補上「{actual}」這層語氣。",
            ],
        ]
    elif pos == "noun":
        options = [
            [
                f"在今天的英文裡，{word_code} 常黏在 <code>{phrase1}</code>、<code>{phrase2}</code> 這些搭配附近，因為它擅長把場面裡那份「{focus}」正式點名。",
                f"所以它和 {contrast_code} 的差別，通常不在難易，而在你要不要把那件事說成一個可被指出、可被談論的對象。",
            ],
            [
                f"{word_code} 的現代用法很少只是把語氣寫得更重。更多時候，它是在幫你把本來模糊的分量收成一句有明確指向的話。",
                f"如果只想表達比較平的「{clean}」，{contrast_code} 常常已經夠了；但要把「{focus}」正式點出來時，{word_code} 會更合適。",
            ],
            [
                f"現在看到 {word_code}，可以先看它出現在哪些固定搭配裡。像 <code>{phrase1}</code>、<code>{phrase2}</code> 都在示範：這個名詞最擅長把某種分量明確命名。",
                f"它和 {contrast_code} 的差別，不只在字面，而在句子是否要把那份「{actual}」當成一個可以被接住的東西來說。",
            ],
        ]
    else:
        options = [
            [
                f"現在看到 {word_code}，多半不是為了把語氣寫得更花，而是為了讓讀者一眼看出某個人、系統或局面正帶著「{focus}」這種質地。",
                f"也因此，它和 {contrast_code} 的差別通常不在字面強弱，而在你要不要把那種具體氣質明白地壓到前景。",
            ],
            [
                f"{word_code} 在現代英文裡最有用的地方，是它能快速替整個對象定調。像 <code>{phrase1}</code>、<code>{phrase2}</code> 這些搭配，就會讓那種氣質立刻落地。",
                f"如果只說比較平的「{clean}」，{contrast_code} 也許夠用；但當你需要的是更具體的「{actual}」，{word_code} 會更準。",
            ],
            [
                f"現在的 {word_code} 很少只是裝飾字。它一出現，通常就在要求讀者用「{focus}」這個角度重新看待眼前的對象。",
                f"所以它和 {contrast_code} 的差別，不只在詞彙強度，而在整個場面要不要被這層氣質重新定義。",
            ],
        ]
    return options[variant % len(options)]


def rewrite_payload(payload: dict[str, Any]) -> dict[str, Any]:
    word = payload["target"]["word"]
    slug = payload["target"]["slug"]
    page = payload["page"]
    variant = pick_variant(slug, 7)
    pos = page["partOfSpeech"]
    thesis = page["hero"]["thesis"]
    _, actual = split_thesis(thesis)
    cn_tag_list = chinese_tags(payload["indexEntry"]["tags"])
    focus = cn_tag_list[0] if cn_tag_list else actual
    image_tag = cn_tag_list[1] if len(cn_tag_list) > 1 else actual
    word_code = f"<code>{slug}</code>"
    contrast_word = page["definition"]["contrast"]["word"]
    contrast_code = f"<code>{contrast_word}</code>"
    contrast_meaning = page["neighbors"]["others"][0]["meaning"]
    short_def = base_definition_text(page["definition"]["summary"]).rstrip("。")
    collocations = page["collocations"]["items"]
    usage_items = page["usage"]

    page["coreIdea"] = build_core_idea(word_code, pos, actual, focus, variant)
    page["definition"]["summary"] = build_summary(pos, short_def, actual, focus, variant)
    page["definition"]["contrast"]["note"] = build_contrast_note(
        word_code, contrast_code, contrast_meaning, actual, focus, variant
    )
    page["definition"]["flow"] = build_flow(pos, actual, focus, variant)
    page["memory"]["explanation"] = build_memory_explanation(word, actual, focus, image_tag, variant)

    usage_bodies = build_usage_bodies(pos, focus, actual, contrast_meaning, collocations, variant)
    for item, body in zip(page["usage"], usage_bodies, strict=True):
        item["body"] = body

    page["collocations"]["note"] = build_collocation_note(pos, focus, variant)
    item_notes = build_collocation_item_notes(pos, focus, collocations, variant)
    for item, note in zip(page["collocations"]["items"], item_notes, strict=True):
        item["note"] = note

    page["neighbors"]["self"]["meaning"] = build_neighbor_self(short_def, cn_tag_list, actual)
    page["neighbors"]["self"]["use"] = build_neighbor_use(pos, actual, contrast_meaning)
    page["neighbors"]["others"][0]["use"] = build_other_use(pos, actual, contrast_meaning)

    page["modernUse"] = build_modern_use(
        word_code,
        contrast_code,
        pos,
        focus,
        actual,
        contrast_meaning,
        collocations,
        variant,
    )
    return payload


def resolve_payloads(inputs: list[Path]) -> list[Path]:
    paths: list[Path] = []
    for raw in inputs:
        path = (ROOT / raw).resolve() if not raw.is_absolute() else raw.resolve()
        if path.suffix.lower() == ".json":
            paths.append(path)
            continue
        if path.suffix.lower() in {".tsv", ".csv", ".txt", ".list"}:
            lines = path.read_text(encoding="utf-8").splitlines()
            for index, line in enumerate(lines):
                value = line.strip()
                if not value or value == "payload":
                    continue
                resolved = (ROOT / value).resolve()
                if resolved.suffix.lower() == ".json":
                    paths.append(resolved)
            continue
        raise SystemExit(f"unsupported input: {raw}")
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Rewrite formulaic semantic payload prose into the current concept-first narrative style."
    )
    parser.add_argument("inputs", nargs="+", type=Path, help="Payload JSON files or manifests")
    parser.add_argument("--check", action="store_true", help="Print touched files without writing")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Allow this deprecated legacy rewrite tool to write payload files.",
    )
    args = parser.parse_args()

    if not args.check and not args.force:
        parser.error(DEPRECATED_NOTICE)

    payload_paths = resolve_payloads(args.inputs)
    for path in payload_paths:
        payload = load_payload(path)
        updated = rewrite_payload(payload)
        if args.check:
            print(path.relative_to(ROOT))
            continue
        write_payload(path, updated)
        print(f"updated {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
