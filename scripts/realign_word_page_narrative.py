from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

from backfill_word_page_origins_and_collocations import collocation_note_for_index, generic_collocation_note

ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "data" / "word-payloads"

CORE_JUDGMENT_RE = re.compile(
    r"^先把 <code>(?P<word>[^<]+)</code> 看成一個判斷詞。它讓你知道句子不是停在 <code>(?P<confusion>[^<]+)</code> 那個外圈。$"
)
CORE_FOCUS_RE = re.compile(
    r"^用 <code>(?P<word>[^<]+)</code> 時，句子通常在做一個收焦動作：把讀者帶到「(?P<focus>.+)」那個更窄的位置。$"
)
FLOW_READ_RE = re.compile(r"^先讀搭配$")
MEMORY_IF_ONLY_CHINESE_RE = re.compile(
    r"^如果你只能想起中文，這個字會很快和 <code>(?P<confusion>[^<]+)</code> 混在一起；畫面能幫你多留一層邊界。$"
)
MEMORY_NEXT_TIME_RE = re.compile(
    r"^下次看到 <code>(?P<word>[^<]+)</code>，先讓這個畫面浮上來，再檢查上下文是否真的有「(?P<focus>.+)」。$"
)
DAILY_REVEALS_CORE_RE = re.compile(
    r"^在 (?P<context>.+) 裡，<code>(?P<collocation>.+)</code> 通常能把這個字的核心露出來。先讀這個搭配，再讀其他例子。$"
)
DAILY_LOW_FRICTION_RE = re.compile(
    r"^<code>(?P<collocation>.+)</code> 是最低摩擦入口；它讓你不用先背完整定義，也能感到「(?P<focus>.+)」。$"
)
DAILY_SCENE_RE = re.compile(
    r"^在 (?P<context>.+) 的語境裡，<code>(?P<collocation>.+)</code> 很能代表 <code>(?P<word>[^<]+)</code>，因為它把「(?P<focus>.+)」直接放到句子前景。$"
)
CONFUSION_CAMERA_RE = re.compile(
    r"^兩者不是難易差，而是焦距差。<code>(?P<confusion>[^<]+)</code> 像外框，<code>(?P<word>[^<]+)</code> 像把鏡頭對到關鍵細節。$"
)
FLOW_OUTER_RING_RE = re.compile(r"^先有 (?P<outer>.+) 的外圈$")
FLOW_NEED_RE = re.compile(r"^再出現「(?P<focus>.+)」的需要$")
FLOW_POSITION_RE = re.compile(r"^(?P<word>[a-z-]+) 才有位置$")
PROFESSIONAL_CONTEXT_RE = re.compile(
    r"^<code>(?P<collocation>.+)</code> 把語境推到 (?P<context>.+)。這時重點是精準，不是把句子寫得更艱深。$"
)
PROFESSIONAL_SCENE_RE = re.compile(
    r"^在 (?P<context>.+) 的語境裡，<code>(?P<collocation>.+)</code> 會把 <code>(?P<word>[^<]+)</code> 的邊界說得更清楚，因為它談的不是泛泛狀態，而是「(?P<focus>.+)」。$"
)
PRACTICE_SWAP_CHECK_RE = re.compile(
    r"^先造句，再回頭檢查：這句若換成 <code>(?P<confusion>.+)</code>，意思是否變太寬？$"
)
MODERN_WORD_CHOICE_RE = re.compile(
    r"^如果一句話只需要大意，別急著用 <code>(?P<word>.+)</code>；如果要處理「(?P<focus>.+)」，它才值得出場。$"
)
MODERN_SCENE_RE = re.compile(
    r"^在現代用法裡，<code>(?P<word>[^<]+)</code> 常透過像 (?P<collocations>.+) 這樣的搭配定形；一看見它們，就比較容易抓到這個字真正的邊界。$"
)
MODERN_NECESSARY_RE = re.compile(
    r"^<code>(?P<word>[^<]+)</code> 真正適合出場的時刻，是句子需要把「(?P<focus>.+)」說得更準的時候；如果只是泛泛帶過，常用詞往往就夠了。$"
)
MODERN_COMPARE_RE = re.compile(
    r"^和 <code>(?P<confusion>[^<]+)</code> 相比，<code>(?P<word>[^<]+)</code> 的價值不是更難，而是更能說明「(?P<focus>.+)」。$"
)
MEMORY_BRIDGE_RE = re.compile(
    r"^記憶鉤子不是答案，它只是把你帶回搭配：(?P<collocations>.+)。$"
)
ORIGIN_HISTORY_RE = re.compile(
    r"^<code>(?P<word>[^<]+)</code>，在英語裡約見於 (?P<attested>.+?)，的詞史和較早的(?P<history>.+?)有關，後來才慢慢落到今天這種「(?P<sense>.+)」的語境。$"
)
ORIGIN_MEMORY_PREFIX_RE = re.compile(r"^這個鉤子只負責喚回語感：(?P<focus>.+)$")
ORIGIN_MEMORY_PREFIXES = (
    "這個鉤子只負責喚回語感：",
    "可用的記憶入口：",
    "先記畫面，不急著求完整解釋：",
    "把畫面收成一句話：",
)
FLOW_PROCESS_MARKERS = (
    "先讀",
    "先找",
    "入手",
    "把語感帶到",
    "最後用",
    "最後才背",
    "固定語氣",
    "測試輸出",
    "確認它往",
)
MEMORY_META_MARKERS = (
    "把畫面、搭配、鄰近字一起記",
    "三者合起來才會變成可用的語感",
)
DAILY_META_MARKERS = (
    "先拿 <code>",
    "練第一句",
    "先讓句子自然",
    "多看三個中文解釋",
    "寫一個你真的會遇到的場景",
)
PROFESSIONAL_META_MARKERS = (
    "先從 <code>",
    "讀 <code>",
    "檢查語域",
    "從認得走向會判斷",
    "看語氣",
    "提供理由",
    "變得必要",
)
MODERN_USE_1_META_MARKERS = (
    "實際閱讀時，<code>",
    "先留意 <code>",
    "先看旁邊的名詞或動詞",
    "閱讀中的訊號",
)
MODERN_USE_2_META_MARKERS = (
    "真正掌握它的標準是",
    "為什麼這裡該用 <code>",
)
COLLOCATION_NOTE_META_MARKERS = (
    "這個字常靠 ",
    "不只停在抽象定義",
)
COLLOCATION_CARD_META_MARKERS = (
    "語氣會比單說一般形容更具體",
    "不只停在抽象說明",
    "不只停在抽象名詞",
    "讓語氣更像特定領域裡的自然用法",
    "也更容易看出語域",
)


def compact(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def trim_terminal_punctuation(value: str) -> str:
    return compact(value).rstrip("。！？；;")


def strip_wrapping_quotes(value: str) -> str:
    text = trim_terminal_punctuation(value)
    if len(text) >= 2 and text[0] in "「『\"“" and text[-1] in "」』\"”":
        return text[1:-1].strip()
    return text


def clean_definition(value: str) -> str:
    text = compact(value)
    for prefix in (
        "名詞，指",
        "名詞，",
        "動詞，指",
        "形容",
        "表示",
        "指",
        "用來描述",
        "用來表示",
    ):
        if text.startswith(prefix):
            return text[len(prefix) :].strip()
    return text


def extract_focus_phrase(placeholders: dict[str, str]) -> str:
    thesis = compact(placeholders["THESIS"])
    if "而是" in thesis:
        phrase = thesis.split("而是", 1)[1]
    else:
        phrase = clean_definition(placeholders["SHORT_DEFINITION"])
    return strip_wrapping_quotes(phrase)


def narrative_flow(part_of_speech: str) -> tuple[str, str, str]:
    part = part_of_speech.lower()
    if "verb" in part:
        return ("情境成形", "核心動作發生", "結果顯現")
    if "adjective" in part:
        return ("對象出現", "特質被感到", "整體語氣定型")
    if "noun" in part:
        return ("現象浮現", "核心特質成形", "這個概念被命名")
    return ("情境出現", "核心特徵浮現", "語氣邊界變清楚")


def contains_any(text: str, markers: tuple[str, ...]) -> bool:
    return any(marker in text for marker in markers)


def collocation_summary(*collocations: str) -> str:
    values = [value for value in collocations if value]
    if not values:
        return ""
    if len(values) == 1:
        return f"<code>{values[0]}</code>"
    return " 和 ".join(f"<code>{value}</code>" for value in values[:2])


def update_if_changed(placeholders: dict[str, str], key: str, value: str, counters: dict[str, int], counter_key: str) -> None:
    if placeholders[key] != value:
        placeholders[key] = value
        counters[counter_key] = counters.get(counter_key, 0) + 1


def rewrite_payload(payload: dict[str, Any], counters: dict[str, int]) -> bool:
    placeholders = payload["templatePlaceholders"]
    word = placeholders["WORD_LOWER"]
    word_code = f"<code>{word}</code>"
    confusion = placeholders["CONFUSION_WORD"]
    focus_phrase = extract_focus_phrase(placeholders)
    changed = False

    core_idea = compact(placeholders["CORE_IDEA"])
    memory_explanation = compact(placeholders["MEMORY_EXPLANATION"])
    daily_usage = compact(placeholders["DAILY_USAGE"])
    professional_usage = compact(placeholders["PROFESSIONAL_USAGE"])
    modern_use_1 = compact(placeholders["MODERN_USE_1"])
    modern_use_2 = compact(placeholders["MODERN_USE_2"])
    origin_memory = compact(placeholders["ORIGIN_MEMORY"])
    origin_paragraph = compact(placeholders["ORIGIN_PARAGRAPH"])
    confusion_note = compact(placeholders["CONFUSION_NOTE"])
    collocation_note = compact(placeholders["COLLOCATION_NOTE"])
    collocation_1 = placeholders["COLLOCATION_1"]
    collocation_2 = placeholders["COLLOCATION_2"]
    register_1 = placeholders["REGISTER_1"]
    register_2 = placeholders["REGISTER_2"]
    flow_values = (
        compact(placeholders["FLOW_1"]),
        compact(placeholders["FLOW_2"]),
        compact(placeholders["FLOW_3"]),
    )

    if CORE_JUDGMENT_RE.fullmatch(core_idea):
        next_value = (
            f"{word_code} 不只是 <code>{confusion}</code> 的近義替代；"
            f"它用來描述「{focus_phrase}」這種更窄、更準確的情境。"
        )
        update_if_changed(placeholders, "CORE_IDEA", next_value, counters, "core_judgment")
        changed = True
    elif match := CORE_FOCUS_RE.fullmatch(core_idea):
        focused = strip_wrapping_quotes(match.group("focus"))
        next_value = f"{word_code} 用來描述「{focused}」這種更窄、更準確的情境；它不是泛稱，而是帶邊界的選字。"
        update_if_changed(placeholders, "CORE_IDEA", next_value, counters, "core_focus")
        changed = True

    if CONFUSION_CAMERA_RE.fullmatch(confusion_note):
        next_value = (
            f"<code>{confusion}</code> 可以先說大方向；{word_code} 用在你要把「{focus_phrase}」"
            "這條語氣邊界說得更準的時候。"
        )
        update_if_changed(placeholders, "CONFUSION_NOTE", next_value, counters, "confusion_camera")
        changed = True

    if ORIGIN_HISTORY_RE.fullmatch(origin_paragraph):
        match = ORIGIN_HISTORY_RE.fullmatch(origin_paragraph)
        assert match is not None
        attested = compact(match.group("attested"))
        history = compact(match.group("history")).strip("，, ")
        sense = strip_wrapping_quotes(match.group("sense"))
        next_value = (
            f"{word_code} 在英語裡可追到 {attested}；它的詞史往前接到較早的 {history}，"
            f"進入英語後才慢慢收斂成今天這種「{sense}」的用法。"
        )
        update_if_changed(placeholders, "ORIGIN_PARAGRAPH", next_value, counters, "origin_history")
        changed = True

    if FLOW_READ_RE.fullmatch(compact(placeholders["FLOW_1"])) or FLOW_OUTER_RING_RE.fullmatch(flow_values[0]) or (
        FLOW_NEED_RE.fullmatch(flow_values[1]) and FLOW_POSITION_RE.fullmatch(flow_values[2])
    ) or any(
        contains_any(flow_value, FLOW_PROCESS_MARKERS) for flow_value in flow_values
    ):
        flow_1, flow_2, flow_3 = narrative_flow(placeholders["PART_OF_SPEECH"])
        update_if_changed(placeholders, "FLOW_1", flow_1, counters, "flow_rewrite")
        update_if_changed(placeholders, "FLOW_2", flow_2, counters, "flow_rewrite")
        update_if_changed(placeholders, "FLOW_3", flow_3, counters, "flow_rewrite")
        changed = True

    if MEMORY_IF_ONLY_CHINESE_RE.fullmatch(memory_explanation) or contains_any(memory_explanation, MEMORY_META_MARKERS):
        next_value = (
            f"這個畫面能幫你把 {word_code} 和 <code>{confusion}</code> 分開，"
            f"因為它把「{focus_phrase}」那條界線變得可見。"
        )
        update_if_changed(placeholders, "MEMORY_EXPLANATION", next_value, counters, "memory_confusion")
        changed = True
    elif match := MEMORY_NEXT_TIME_RE.fullmatch(memory_explanation):
        focused = strip_wrapping_quotes(match.group("focus"))
        next_value = (
            f"這個畫面之所以有用，是因為它能幫你確認 {word_code} 是否真的在談「{focused}」；"
            "一旦畫面對上，語氣邊界就會清楚很多。"
        )
        update_if_changed(placeholders, "MEMORY_EXPLANATION", next_value, counters, "memory_scene")
        changed = True
    elif MEMORY_BRIDGE_RE.fullmatch(memory_explanation):
        next_value = (
            f"這個畫面有用，是因為它先把「{focus_phrase}」釘住；回到實際搭配時，"
            f"就不容易把它和 <code>{confusion}</code> 混成一團。"
        )
        update_if_changed(placeholders, "MEMORY_EXPLANATION", next_value, counters, "memory_bridge")
        changed = True

    if match := DAILY_REVEALS_CORE_RE.fullmatch(daily_usage):
        context = match.group("context")
        collocation = match.group("collocation")
        next_value = (
            f"像 <code>{collocation}</code> 這樣的說法，多半出現在 {context} 的場景；"
            f"句子真正要說的，就是「{focus_phrase}」。"
        )
        update_if_changed(placeholders, "DAILY_USAGE", next_value, counters, "daily_reveals_core")
        changed = True
    elif match := DAILY_SCENE_RE.fullmatch(daily_usage):
        context = match.group("context")
        collocation = match.group("collocation")
        focused = strip_wrapping_quotes(match.group("focus"))
        next_value = (
            f"像 <code>{collocation}</code> 這樣的說法，多半出現在 {context} 的場景；"
            f"句子真正要說的，就是「{focused}」。"
        )
        update_if_changed(placeholders, "DAILY_USAGE", next_value, counters, "daily_scene")
        changed = True
    elif match := DAILY_LOW_FRICTION_RE.fullmatch(daily_usage):
        collocation = match.group("collocation")
        focused = strip_wrapping_quotes(match.group("focus"))
        next_value = (
            f"像 <code>{collocation}</code> 這樣的說法，焦點通常就在「{focused}」上；"
            "你一看到這個搭配，就能很快抓到句子真正想推的方向。"
        )
        update_if_changed(placeholders, "DAILY_USAGE", next_value, counters, "daily_low_friction")
        changed = True
    elif contains_any(daily_usage, DAILY_META_MARKERS):
        next_value = (
            f"像 <code>{collocation_1}</code> 這樣的說法，多半出現在 {register_1} 的場景；"
            f"句子真正要說的，就是「{focus_phrase}」。"
        )
        update_if_changed(placeholders, "DAILY_USAGE", next_value, counters, "daily_meta_rewrite")
        changed = True

    if match := PROFESSIONAL_CONTEXT_RE.fullmatch(professional_usage):
        context = match.group("context")
        collocation = match.group("collocation")
        next_value = (
            f"到了 {context} 的場景，<code>{collocation}</code> 會更常出現；"
            f"這裡要說清楚的，正是「{focus_phrase}」。"
        )
        update_if_changed(placeholders, "PROFESSIONAL_USAGE", next_value, counters, "professional_context")
        changed = True
    elif match := PROFESSIONAL_SCENE_RE.fullmatch(professional_usage):
        context = match.group("context")
        collocation = match.group("collocation")
        focused = strip_wrapping_quotes(match.group("focus"))
        next_value = (
            f"到了 {context} 的場景，<code>{collocation}</code> 會更常出現；"
            f"這裡要說清楚的，正是「{focused}」。"
        )
        update_if_changed(placeholders, "PROFESSIONAL_USAGE", next_value, counters, "professional_scene")
        changed = True
    elif contains_any(professional_usage, PROFESSIONAL_META_MARKERS):
        next_value = (
            f"到了 {register_2} 的場景，<code>{collocation_2}</code> 會更常出現；"
            f"這裡要說清楚的，正是「{focus_phrase}」。"
        )
        update_if_changed(placeholders, "PROFESSIONAL_USAGE", next_value, counters, "professional_meta_rewrite")
        changed = True

    if match := MODERN_SCENE_RE.fullmatch(modern_use_1):
        summary = compact(match.group("collocations"))
        next_value = (
            f"現在最常見的就是 {summary} 這類說法；"
            f"它們一出現，通常就在替句子劃清「{focus_phrase}」的範圍。"
        )
        update_if_changed(placeholders, "MODERN_USE_1", next_value, counters, "modern_scene")
        changed = True
    elif contains_any(modern_use_1, MODERN_USE_1_META_MARKERS):
        summary = collocation_summary(collocation_1, collocation_2)
        next_value = (
            f"現在最常見的就是 {summary} 這類說法；"
            f"它們一出現，通常就在替句子劃清「{focus_phrase}」的範圍。"
        )
        update_if_changed(placeholders, "MODERN_USE_1", next_value, counters, "modern_use_1_rewrite")
        changed = True

    if match := MODERN_NECESSARY_RE.fullmatch(modern_use_2):
        focused = strip_wrapping_quotes(match.group("focus"))
        next_value = (
            f"當句子要把「{focused}」說準時，{word_code} 才真的有必要；"
            "如果只是一般描述，常見近義詞通常就夠。"
        )
        update_if_changed(placeholders, "MODERN_USE_2", next_value, counters, "modern_necessary")
        changed = True
    elif match := MODERN_WORD_CHOICE_RE.fullmatch(modern_use_2):
        focused = strip_wrapping_quotes(match.group("focus"))
        next_value = (
            f"當句子要把「{focused}」說準時，{word_code} 才真的有必要；"
            "如果只是一般描述，常見近義詞通常就夠。"
        )
        update_if_changed(placeholders, "MODERN_USE_2", next_value, counters, "modern_word_choice")
        changed = True
    elif match := MODERN_COMPARE_RE.fullmatch(modern_use_2):
        compared = match.group("confusion")
        focused = strip_wrapping_quotes(match.group("focus"))
        next_value = (
            f"比起 <code>{compared}</code>，{word_code} 更適合用在你想直接點出「{focused}」的時候。"
        )
        update_if_changed(placeholders, "MODERN_USE_2", next_value, counters, "modern_compare")
        changed = True
    elif contains_any(modern_use_2, MODERN_USE_2_META_MARKERS):
        next_value = (
            f"當句子要把「{focus_phrase}」說準時，{word_code} 才真的有必要；"
            "如果只是一般描述，常見近義詞通常就夠。"
        )
        update_if_changed(placeholders, "MODERN_USE_2", next_value, counters, "modern_meta_rewrite")
        changed = True

    if contains_any(collocation_note, COLLOCATION_NOTE_META_MARKERS):
        next_value = generic_collocation_note(placeholders)
        update_if_changed(placeholders, "COLLOCATION_NOTE", next_value, counters, "collocation_summary")
        changed = True

    for index in (1, 2, 3):
        collocation_key = f"COLLOCATION_{index}"
        note_key = f"COLLOCATION_NOTE_{index}"
        note_value = compact(placeholders.get(note_key, ""))
        if not compact(placeholders.get(collocation_key, "")) or not note_value:
            continue
        if contains_any(note_value, COLLOCATION_CARD_META_MARKERS):
            next_value = collocation_note_for_index(placeholders, index)
            update_if_changed(placeholders, note_key, next_value, counters, f"collocation_note_{index}")
            changed = True

    if match := ORIGIN_MEMORY_PREFIX_RE.fullmatch(origin_memory):
        next_value = strip_wrapping_quotes(match.group("focus"))
        update_if_changed(placeholders, "ORIGIN_MEMORY", next_value, counters, "origin_memory_image")
        changed = True
    else:
        for prefix in ORIGIN_MEMORY_PREFIXES[1:]:
            if origin_memory.startswith(prefix):
                next_value = strip_wrapping_quotes(origin_memory[len(prefix) :])
                update_if_changed(placeholders, "ORIGIN_MEMORY", next_value, counters, "origin_memory_prefix")
                changed = True
                break

    return changed


def iter_payload_paths(inputs: list[str]) -> list[Path]:
    if not inputs:
        return sorted(PAYLOADS.glob("*.json"))

    paths: list[Path] = []
    for raw in inputs:
        candidate = (ROOT / raw).resolve() if not Path(raw).is_absolute() else Path(raw).resolve()
        if candidate.is_dir():
            paths.extend(sorted(candidate.glob("*.json")))
            continue
        if candidate.is_file() and candidate.suffix.lower() == ".json":
            paths.append(candidate)
            continue
        raise SystemExit(f"unsupported input: {raw}")

    seen: set[Path] = set()
    unique_paths: list[Path] = []
    for path in paths:
        if path not in seen:
            seen.add(path)
            unique_paths.append(path)
    return unique_paths


def write_payload(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Realign word-page payload narrative tone toward the Ephemeral baseline.")
    parser.add_argument("inputs", nargs="*", help="Optional payload JSON files or directories. Defaults to data/word-payloads")
    parser.add_argument("--check", action="store_true", help="Report files that would change without writing them")
    args = parser.parse_args()

    counters: dict[str, int] = {}
    changed_files: list[str] = []
    for path in iter_payload_paths(args.inputs):
        payload = json.loads(path.read_text(encoding="utf-8"))
        if rewrite_payload(payload, counters):
            changed_files.append(path.name)
            if not args.check:
                write_payload(path, payload)

    mode = "would update" if args.check else "updated"
    print(f"{mode} {len(changed_files)} payload files")
    for key in sorted(counters):
        print(f"{key}: {counters[key]}")
    if args.check and changed_files:
        preview = ", ".join(changed_files[:20])
        print(f"sample: {preview}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
