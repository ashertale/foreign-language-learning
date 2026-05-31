from __future__ import annotations

import argparse
import html
import json
import re
import sys
import time
from collections import Counter
from pathlib import Path
from typing import Any
from urllib.parse import urlparse
from urllib.request import Request, urlopen


ROOT = Path(__file__).resolve().parents[1]
PAYLOADS = ROOT / "data" / "word-payloads"
NO_ORIGIN_TEXT = "目前沒有補到可確認的詞源／歷史說明。"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/137.0.0.0 Safari/537.36"
)
PREPOSITIONS = (
    "for",
    "with",
    "to",
    "of",
    "between",
    "in",
    "on",
    "over",
    "under",
    "about",
    "against",
    "among",
)


def compact(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def is_placeholder_pointer(value: str) -> bool:
    return bool(re.fullmatch(r"\$\w+", compact(value)))


def compact_html(value: str) -> str:
    text = compact(value)
    text = re.sub(r"\s+([，。！？；：、）】」])", r"\1", text)
    text = re.sub(r"([（【「])\s+", r"\1", text)
    text = re.sub(r"</code>\s+<code>", "</code>、<code>", text)
    return text.strip()


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")


def iter_payload_paths(inputs: list[Path]) -> list[Path]:
    if not inputs:
        return sorted(PAYLOADS.glob("*.json"))

    paths: list[Path] = []
    for raw in inputs:
        candidate = raw if raw.is_absolute() else (ROOT / raw)
        resolved = candidate.resolve()
        if resolved.is_dir():
            paths.extend(sorted(resolved.glob("*.json")))
        elif resolved.is_file():
            paths.append(resolved)
        else:
            raise FileNotFoundError(f"payload input not found: {raw}")
    return paths


def source_audit_entry(payload: dict[str, Any], category: str) -> dict[str, Any] | None:
    source_audit = payload.get("sourceAudit")
    if not isinstance(source_audit, list):
        return None
    for entry in source_audit:
        if isinstance(entry, dict) and entry.get("category") == category:
            return entry
    return None


def etymonline_tw_url(url: str) -> str | None:
    parsed = urlparse(url)
    host = parsed.netloc.lower()
    if "etymonline" not in host:
        return None
    slug = parsed.path.rstrip("/").split("/")[-1]
    if not slug:
        return None
    return f"https://www.etymonline.net/tw/word/{slug}"


def fetch_text(url: str, cache: dict[str, str]) -> str:
    if url in cache:
        return cache[url]
    request = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(request, timeout=30) as response:
        text = response.read().decode("utf-8", errors="replace")
    cache[url] = text
    return text


def extract_between_markers(source: str, start_marker: str, end_marker: str) -> str | None:
    start = source.find(start_marker)
    if start == -1:
        return None
    start += len(start_marker)
    end = source.find(end_marker, start)
    if end == -1:
        return None
    try:
        return json.loads(f'"{source[start:end]}"')
    except json.JSONDecodeError:
        return None


def extract_translated_etymology(source: str) -> str | None:
    return extract_between_markers(
        source,
        '\\"etymology\\":\\"',
        '\\",\\"etymology_plain\\":\\"',
    ) or extract_between_markers(
        source,
        '"etymology":"',
        '","etymology_plain":"',
    )


def extract_english_etymology_plain(source: str) -> str | None:
    return extract_between_markers(
        source,
        '\\"etymology_plain\\":\\"',
        '\\",\\"first_recorded\\":\\"',
    ) or extract_between_markers(
        source,
        '"etymology_plain":"',
        '","first_recorded":"',
    )


def strip_tags(value: str) -> str:
    return re.sub(r"<[^>]+>", "", value)


def clean_translated_etymology(raw_html: str) -> str:
    if is_placeholder_pointer(raw_html):
        return ""

    paragraph_match = re.search(r"<p>(.*?)</p>", raw_html, re.DOTALL)
    if paragraph_match:
        text = paragraph_match.group(1)
    else:
        text = raw_html

    text = re.sub(
        r'<span[^>]*class="foreign notranslate"[^>]*>(.*?)</span>',
        lambda match: f"<code>{strip_tags(match.group(1)).strip()}</code>",
        text,
        flags=re.DOTALL,
    )
    text = re.sub(
        r"<a [^>]*>(.*?)</a>",
        lambda match: f"<code>{strip_tags(match.group(1)).strip()}</code>",
        text,
        flags=re.DOTALL,
    )
    text = text.replace("</p><p>", " ")
    text = re.sub(r"<br\s*/?>", " ", text)
    text = re.sub(r"</?(em|i|strong|b)>", "", text)
    text = re.sub(r"<(?!/?code\b)[^>]+>", "", text)
    text = html.unescape(text)
    text = text.replace("\xa0", " ")
    text = re.sub(r"相關詞彙：.*$", "", text)
    text = compact_html(text)
    return text.rstrip("；; ")


def summarize_english_etymology(placeholders: dict[str, str], plain_text: str) -> str:
    word = placeholders["WORD_LOWER"]
    short_definition = compact(placeholders["SHORT_DEFINITION"]).rstrip("。")
    first_recorded_match = re.search(r"^(.*?)(?:,|;)", plain_text)
    first_recorded = first_recorded_match.group(1) if first_recorded_match else ""
    literal_match = re.search(r'literally "([^"]+)"', plain_text)
    meaning_shift_match = re.search(r'Meaning "([^"]+)" is recorded by ([^.;]+)', plain_text)
    source_match = re.search(
        r'from ([A-Z][A-Za-z -]+?) ([A-Za-z*āēīōūȳæœĀĒĪŌŪȲ\'’.-]+)(?:, [^"]*)? "([^"]+)"',
        plain_text,
    )

    parts: list[str] = []
    if first_recorded:
        parts.append(f"<code>{word}</code> 在英語裡可追到 {first_recorded}")
    else:
        parts.append(f"<code>{word}</code>")
    if source_match:
        language = source_match.group(1)
        source_word = source_match.group(2)
        gloss = source_match.group(3)
        parts.append(f"它來自 {language} <code>{source_word}</code>，早期義項接近「{gloss}」")
    elif "from " in plain_text:
        parts.append("它的詞史一路接回更早的拉丁、希臘或法語層")
    if literal_match:
        parts.append(f"字面上可理解成「{literal_match.group(1)}」")
    if meaning_shift_match:
        parts.append(f"進入英語後，語氣才慢慢收斂成今天這種「{short_definition}」的用法")
    elif short_definition:
        parts.append(f"後來才慢慢收斂成今天這種「{short_definition}」的用法")
    return compact_html("。".join(parts) + "。")


def backfill_origin(payload: dict[str, Any], cache: dict[str, str]) -> str:
    placeholders = payload["templatePlaceholders"]
    source = source_audit_entry(payload, "etymology-history")
    source_url = source.get("url", "") if source else ""
    tw_url = etymonline_tw_url(str(source_url))

    if tw_url:
        try:
            translated_page = fetch_text(tw_url, cache)
            translated_html = extract_translated_etymology(translated_page)
            if translated_html:
                cleaned = clean_translated_etymology(translated_html)
                if cleaned:
                    return cleaned
        except Exception:
            pass

        try:
            english_page = fetch_text(str(source_url), cache)
            plain_text = extract_english_etymology_plain(english_page)
            if plain_text:
                summary = summarize_english_etymology(placeholders, plain_text)
                if summary:
                    return summary
        except Exception:
            pass

    return NO_ORIGIN_TEXT


def extract_focus_phrase(placeholders: dict[str, str]) -> str:
    thesis = compact(placeholders["THESIS"]).rstrip("。")
    if "而是" in thesis:
        return thesis.split("而是", 1)[1].rstrip("。")

    definition = compact(placeholders["SHORT_DEFINITION"]).rstrip("。")
    for prefix in ("表示", "形容", "指", "用來描述", "用來表示"):
        if definition.startswith(prefix):
            return definition[len(prefix) :].strip()
    return definition


def code_join(values: list[str]) -> str:
    wrapped = [f"<code>{value}</code>" for value in values if value]
    if not wrapped:
        return ""
    if len(wrapped) == 1:
        return wrapped[0]
    if len(wrapped) == 2:
        return f"{wrapped[0]} 和 {wrapped[1]}"
    return "、".join(wrapped[:-1]) + f" 和 {wrapped[-1]}"


def text_join(values: list[str]) -> str:
    cleaned = [compact(value) for value in values if compact(value)]
    if not cleaned:
        return ""
    if len(cleaned) == 1:
        return cleaned[0]
    if len(cleaned) == 2:
        return f"{cleaned[0]} 和 {cleaned[1]}"
    return "、".join(cleaned[:-1]) + f" 和 {cleaned[-1]}"


def generic_collocation_note(placeholders: dict[str, str]) -> str:
    collocations = [
        compact(placeholders.get("COLLOCATION_1", "")),
        compact(placeholders.get("COLLOCATION_2", "")),
        compact(placeholders.get("COLLOCATION_3", "")),
    ]
    collocations = [value for value in collocations if value]
    registers = [
        compact(placeholders.get("REGISTER_1", "")),
        compact(placeholders.get("REGISTER_2", "")),
        compact(placeholders.get("REGISTER_3", "")),
    ]
    registers = [value for value in registers if value]
    focus = extract_focus_phrase(placeholders)
    collocation_text = code_join(collocations[:3])
    register_text = text_join(registers[:3])

    if register_text:
        return f"常見用法集中在 {collocation_text}；這幾個搭配分別落在 {register_text} 的場景裡。"
    return f"常見用法集中在 {collocation_text}；看這些搭配，比單看定義更容易抓到「{focus}」怎麼落地。"


def noun_collocation_target(collocation: str) -> str | None:
    prep_match = re.search(rf"\b({'|'.join(PREPOSITIONS)})\b\s+(.+)$", collocation, re.IGNORECASE)
    if prep_match:
        return prep_match.group(2).strip()
    return None


def collocation_note_for_index(placeholders: dict[str, str], index: int) -> str:
    word = placeholders["WORD_LOWER"]
    collocation = compact(placeholders[f"COLLOCATION_{index}"])
    register = compact(placeholders[f"REGISTER_{index}"])
    focus = extract_focus_phrase(placeholders)
    part_of_speech = placeholders["PART_OF_SPEECH"].lower()
    lower_collocation = collocation.lower()

    if "verb" in part_of_speech and lower_collocation.startswith(word + " "):
        target = collocation[len(word) :].strip()
        return (
            f"在 {register} 的語境裡，這個搭配會把動作直接落在 <code>{target}</code> 上。"
        )

    if "adjective" in part_of_speech and lower_collocation.startswith(word + " "):
        target = collocation[len(word) :].strip()
        return (
            f"在 {register} 的語境裡，這個搭配通常就在形容 <code>{target}</code> 的狀態或氣質。"
        )

    if "noun" in part_of_speech:
        prep_target = noun_collocation_target(collocation)
        if prep_target:
            return (
                f"在 {register} 的語境裡，這個搭配會把關係直接指向 <code>{prep_target}</code>。"
            )

        if lower_collocation.endswith(word):
            modifier = collocation[: len(collocation) - len(word)].strip()
            if modifier:
                return (
                    f"在 {register} 的語境裡，前面的 <code>{modifier}</code> 會把這個概念限定到更具體的場景。"
                )

    return (
        f"在 {register} 的語境裡，這個搭配最容易看出「{focus}」實際怎麼落在句子裡。"
    )


def backfill_payload(payload: dict[str, Any], cache: dict[str, str], counters: Counter[str]) -> bool:
    placeholders = payload["templatePlaceholders"]
    changed = False

    if not compact(placeholders.get("ORIGIN_PARAGRAPH", "")) or is_placeholder_pointer(placeholders.get("ORIGIN_PARAGRAPH", "")):
        placeholders["ORIGIN_PARAGRAPH"] = backfill_origin(payload, cache)
        counters["origin"] += 1
        if placeholders["ORIGIN_PARAGRAPH"] == NO_ORIGIN_TEXT:
            counters["origin_none"] += 1
        changed = True
        time.sleep(0.05)

    if not compact(placeholders.get("COLLOCATION_NOTE", "")):
        placeholders["COLLOCATION_NOTE"] = generic_collocation_note(placeholders)
        counters["collocation_summary"] += 1
        changed = True

    for index in (1, 2, 3):
        collocation_key = f"COLLOCATION_{index}"
        note_key = f"COLLOCATION_NOTE_{index}"
        if compact(placeholders.get(collocation_key, "")) and not compact(placeholders.get(note_key, "")):
            placeholders[note_key] = collocation_note_for_index(placeholders, index)
            counters[f"collocation_note_{index}"] += 1
            changed = True

    return changed


def main() -> int:
    parser = argparse.ArgumentParser(description="Backfill missing etymology paragraphs and collocation notes.")
    parser.add_argument("payload", nargs="*", type=Path, help="Optional payload JSON paths or directories.")
    parser.add_argument("--check", action="store_true", help="Report changes without writing files.")
    parser.add_argument("--limit", type=int, default=0, help="Only process the first N payloads after expansion.")
    args = parser.parse_args()

    try:
        paths = iter_payload_paths(args.payload)
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if args.limit > 0:
        paths = paths[: args.limit]

    cache: dict[str, str] = {}
    counters: Counter[str] = Counter()
    changed_paths: list[Path] = []

    for path in paths:
        payload = load_json(path)
        if backfill_payload(payload, cache, counters):
            changed_paths.append(path)
            if not args.check:
                write_json(path, payload)

    action = "would update" if args.check else "updated"
    print(f"{action} {len(changed_paths)} payload files")
    if counters:
        for key in sorted(counters):
            print(f"{key}: {counters[key]}")

    if changed_paths:
        preview = ", ".join(path.stem for path in changed_paths[:12])
        print(f"examples: {preview}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
