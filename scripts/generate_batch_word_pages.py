from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

from render_word_page import (
    ROOT,
    WORD_INDEX,
    RenderError,
    existing_index_values,
    find_top_level_blocks,
    read_text,
    render_word_page,
    write_text,
)
from sync_word_numbers import PROTOTYPES, sync_index, sync_page_kicker
from validate_word_pages import validate_payload_page


PAYLOAD_DIR = ROOT / "data" / "word-payloads"
DICTIONARY_LABEL = "Merriam-Webster"
DICTIONARY_BASE = "https://www.merriam-webster.com/dictionary/"
ETYMOLOGY_LABEL = "Online Etymology Dictionary"
ETYMOLOGY_BASE = "https://www.etymonline.com/word/"
LEVEL_LABEL = "wordfreq Zipf + repo CEFR calibration"
LEVEL_URL = "https://github.com/rspeer/wordfreq"
SOURCE_AUDIT = [
    ("dictionary-pronunciation", "definition, pronunciation, and dictionary sense support"),
    ("level-frequency", "Zipf frequency reference and repo-calibrated CEFR study band"),
    ("etymology-history", "etymology and word-history support"),
    ("modern-common-usage", "modern usage examples and current usage boundaries"),
]


def compact(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def title_word(word: str) -> str:
    return word[:1].upper() + word[1:]


def parse_tags(raw: str) -> list[str]:
    return [compact(part) for part in raw.split(",") if compact(part)]


def pos_flow(part_of_speech: str, formula: str) -> tuple[str, str, str]:
    if part_of_speech == "verb":
        return (
            "先有情況、對象或目標",
            f"用 {formula} 的方式推進",
            "結果慢慢變得可見或可感",
        )
    if part_of_speech == "noun":
        return (
            "先有情境或觀察",
            f"用這個詞抓住 {formula} 的核心",
            "讓理解與表達更聚焦",
        )
    return (
        "先有對象或情境",
        f"它呈現 {formula} 的狀態",
        "因此語氣、判斷或效果被拉向那個方向",
    )


def default_tone(domain: str, formula: str) -> str:
    return f"這個字常見於 {domain}；語氣上不是空泛形容，而是用來抓住 {formula} 這種狀態或動作。"


def default_domain_usage(domain: str, collocation: str, formula: str) -> str:
    return f"{domain} 這類場景特別適合放進 <code>{collocation}</code>，因為那裡常需要描述 {formula}。"


def current_index_snapshot() -> tuple[set[str], set[str], set[str]]:
    source = read_text(WORD_INDEX)
    ids, hrefs, _ = existing_index_values(source)
    words: set[str] = set()
    for block in find_top_level_blocks(source):
        match = re.search(r'word:\s*"([^"]+)"', block)
        if match:
            words.add(match.group(1).strip().lower())
    return ids, hrefs, words


def load_specs(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        raise RenderError(f"batch spec not found: {path.relative_to(ROOT) if path.is_absolute() and path.is_relative_to(ROOT) else path}")
    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="|")
        rows = [{key: compact(value or "") for key, value in row.items()} for row in reader]
    if not rows:
        raise RenderError(f"batch spec is empty: {path.relative_to(ROOT)}")
    return rows


def validate_specs(rows: list[dict[str, str]], allow_existing_payloads: bool = False) -> None:
    existing_ids, existing_hrefs, existing_words = current_index_snapshot()
    batch_ids: set[str] = set()
    batch_words: set[str] = set()

    required = [
        "slug",
        "word",
        "part_of_speech",
        "ipa",
        "cefr",
        "zipf",
        "formula",
        "thesis",
        "short_definition",
        "contrast_word",
        "contrast_meaning",
        "hook",
        "domain",
        "collocation_1",
        "register_1",
        "collocation_2",
        "register_2",
        "collocation_3",
        "register_3",
        "tags",
    ]

    for index, row in enumerate(rows, start=1):
        label = f"row {index} ({row.get('slug') or row.get('word') or 'unknown'})"
        for key in required:
            if not row.get(key):
                raise RenderError(f"{label} is missing {key}")

        slug = row["slug"]
        word_lower = row["word"].lower()
        href = f"./{slug}.html"
        payload_path = PAYLOAD_DIR / f"{slug}.json"
        output_path = PROTOTYPES / f"{slug}.html"

        if slug in existing_ids:
            raise RenderError(f"{label} duplicates existing id {slug}")
        if href in existing_hrefs:
            raise RenderError(f"{label} duplicates existing href {href}")
        if word_lower in existing_words:
            raise RenderError(f"{label} duplicates existing displayed word {row['word']}")
        if slug in batch_ids:
            raise RenderError(f"{label} duplicates another batch slug {slug}")
        if word_lower in batch_words:
            raise RenderError(f"{label} duplicates another batch displayed word {row['word']}")
        if payload_path.exists() and not allow_existing_payloads:
            raise RenderError(f"{label} would overwrite existing payload {payload_path.relative_to(ROOT)}")
        if output_path.exists():
            raise RenderError(f"{label} would overwrite existing page {output_path.relative_to(ROOT)}")

        batch_ids.add(slug)
        batch_words.add(word_lower)


def build_payload(row: dict[str, str]) -> dict[str, object]:
    slug = row["slug"]
    word = row["word"]
    word_title = title_word(word)
    word_lower = word.lower()
    part_of_speech = row["part_of_speech"]
    formula = row["formula"]
    thesis = row["thesis"]
    short_definition = row["short_definition"]
    contrast_word = row["contrast_word"]
    contrast_word_title = title_word(contrast_word)
    contrast_meaning = row["contrast_meaning"]
    hook = row["hook"]
    domain = row["domain"]
    collocation_1 = row["collocation_1"]
    collocation_2 = row["collocation_2"]
    collocation_3 = row["collocation_3"]
    register_1 = row["register_1"]
    register_2 = row["register_2"]
    register_3 = row["register_3"]
    flow_1, flow_2, flow_3 = pos_flow(part_of_speech, formula)
    dictionary_url = DICTIONARY_BASE + slug
    etymology_url = ETYMOLOGY_BASE + slug
    tags = parse_tags(row["tags"])

    replacements = {
        "WORD_TITLE": word_title,
        "WORD_SLUG": slug,
        "WORD_LOWER": word_lower,
        "PART_OF_SPEECH": part_of_speech,
        "IPA": row["ipa"],
        "THESIS": thesis,
        "LEARNING_POSITION": f"把 {word_lower} 記成「{formula}」：{thesis}",
        "CEFR_LEVEL": row["cefr"],
        "ZIPF_FREQUENCY": row["zipf"],
        "CORE_IDEA": f"<code>{word_lower}</code> {short_definition}",
        "CONCEPT_FOCUS": f"核心畫面是 {formula}。",
        "TONE_REGISTER": default_tone(domain, formula),
        "USE_WARNING": (
            f"不要把 {word_lower} 只看成 {contrast_word.lower()}；"
            f"<code>{contrast_word.lower()}</code> 多半只是 {contrast_meaning}，而 "
            f"<code>{word_lower}</code> 更強調 {formula}。"
        ),
        "SHORT_DEFINITION": short_definition,
        "CONFUSION_WORD": contrast_word_title,
        "CONFUSION_NOTE": (
            f"<code>{contrast_word.lower()}</code> 多半只是 {contrast_meaning}；"
            f"<code>{word_lower}</code> 則更偏向 {formula}。"
        ),
        "FLOW_1": flow_1,
        "FLOW_2": flow_2,
        "FLOW_3": flow_3,
        "ORIGIN_PARAGRAPH": (
            f"學 <code>{word_lower}</code> 時，先不用把它當成冷知識題；"
            f"更重要的是抓住它如今穩定的核心畫面：{formula}。"
        ),
        "ORIGIN_MEMORY": f"把歷史感先壓縮成一個可記的畫面：{hook}",
        "MEMORY_HOOK": f"<code>{word_lower}</code> 的畫面是：{hook}",
        "MEMORY_EXPLANATION": (
            f"只要你記得這個畫面，下次看到 {word_lower}，"
            "就不會只把它翻成單薄的中文對應。"
        ),
        "DAILY_USAGE": f"日常英文裡，你會看到像 <code>{collocation_1}</code> 這樣的搭配。",
        "PROFESSIONAL_USAGE": (
            f"在專業語境裡，也常會用到 <code>{collocation_2}</code> 來表達更精確的意思。"
        ),
        "DOMAIN_USAGE": default_domain_usage(domain, collocation_3, formula),
        "COLLOCATION_NOTE": (
            f"{word_title} 很適合透過固定搭配來抓語感，尤其是你想把 {formula} 說得更自然時。"
        ),
        "COLLOCATION_1": collocation_1,
        "REGISTER_1": register_1,
        "COLLOCATION_NOTE_1": f"這個搭配能把 {formula} 的語感直接帶出來。",
        "COLLOCATION_2": collocation_2,
        "REGISTER_2": register_2,
        "COLLOCATION_NOTE_2": f"放到 {domain} 的語境裡，這個搭配特別自然。",
        "COLLOCATION_3": collocation_3,
        "REGISTER_3": register_3,
        "COLLOCATION_NOTE_3": f"這個搭配很適合拿來練 {word_lower} 的實際使用邊界。",
        "NEIGHBOR_SELF": formula,
        "NEIGHBOR_SELF_USE": (
            f"當你想說的不只是 {contrast_meaning}，而是 {formula} 這層語感時"
        ),
        "NEIGHBOR_1": contrast_word_title,
        "NEIGHBOR_1_MEANING": contrast_meaning,
        "NEIGHBOR_1_USE": (
            f"只想表達 {contrast_meaning}，而不需要 {formula} 這層細節時"
        ),
        "MODERN_USE_1": (
            f"現代英文裡，<code>{word_lower}</code> 常和 "
            f"<code>{collocation_1}</code>、<code>{collocation_2}</code>、"
            f"<code>{collocation_3}</code> 這類搭配一起出現。"
        ),
        "MODERN_USE_2": (
            f"放到 {domain} 的語境裡，這個字能比一般近義詞更精準地抓住 {formula}。"
        ),
        "DICTIONARY_SOURCE_NOTE": f"基本定義與發音參考 {DICTIONARY_LABEL}。",
        "DICTIONARY_URL": dictionary_url,
        "DICTIONARY_LABEL": DICTIONARY_LABEL,
        "ETYMOLOGY_SOURCE_NOTE": (
            f"字源與歷史語感以 {ETYMOLOGY_LABEL} 為參考，頁內先以現代核心語感為主。"
        ),
        "ETYMOLOGY_URL": etymology_url,
        "ETYMOLOGY_LABEL": ETYMOLOGY_LABEL,
        "MODERN_SOURCE_NOTE": (
            f"現代搭配與使用邊界以 {DICTIONARY_LABEL} 的常見義與例句方向為參考。"
        ),
        "MODERN_SOURCE_URL": dictionary_url,
        "MODERN_SOURCE_LABEL": DICTIONARY_LABEL,
        "CHECK_MEANING": f"我能說出 {word_lower} 和 {contrast_word.lower()} 的差異。",
        "CHECK_ORIGIN": f"我記得這個畫面：{hook}",
        "CHECK_SENTENCE": (
            f"我能用 <code>{collocation_1}</code> 或 <code>{collocation_2}</code> 造一句自然英文。"
        ),
        "PRACTICE_SENTENCE": (
            f"先用 <code>{collocation_1}</code> 或 <code>{collocation_2}</code>，"
            "造一句和你最近工作或生活有關的英文句子。"
        ),
        "REFERENCE_URL": dictionary_url,
        "REFERENCE_LABEL": DICTIONARY_LABEL,
    }

    return {
        "target": {
            "word": word_title,
            "slug": slug,
            "outputPath": f"prototypes/{slug}.html",
        },
        "templatePlaceholders": replacements,
        "indexEntry": {
            "id": slug,
            "word": word_title,
            "partOfSpeech": part_of_speech,
            "href": f"./{slug}.html",
            "thesis": thesis,
            "tags": tags,
            "checks": [
                {"id": "meaning", "label": f"說出 {word_lower} 和 {contrast_word.lower()} 的差異"},
                {"id": "origin", "label": f"記得這個畫面：{hook}"},
                {
                    "id": "sentence",
                    "label": f"用 {collocation_1} 或 {collocation_2} 造一句自然英文",
                },
            ],
        },
        "sourceAudit": [
            {
                "category": SOURCE_AUDIT[0][0],
                "label": DICTIONARY_LABEL,
                "url": dictionary_url,
                "usedFor": SOURCE_AUDIT[0][1],
            },
            {
                "category": SOURCE_AUDIT[1][0],
                "label": LEVEL_LABEL,
                "url": LEVEL_URL,
                "usedFor": SOURCE_AUDIT[1][1],
            },
            {
                "category": SOURCE_AUDIT[2][0],
                "label": ETYMOLOGY_LABEL,
                "url": etymology_url,
                "usedFor": SOURCE_AUDIT[2][1],
            },
            {
                "category": SOURCE_AUDIT[3][0],
                "label": DICTIONARY_LABEL,
                "url": dictionary_url,
                "usedFor": SOURCE_AUDIT[3][1],
            },
        ],
    }


def write_payloads(rows: list[dict[str, str]]) -> list[Path]:
    payload_paths: list[Path] = []
    for row in rows:
        payload = build_payload(row)
        payload_path = PAYLOAD_DIR / f"{row['slug']}.json"
        write_text(payload_path, json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
        payload_paths.append(payload_path)
    return payload_paths


def dry_run_payloads(payload_paths: list[Path]) -> None:
    failures: list[str] = []
    for path in payload_paths:
        try:
            render_word_page(path, dry_run=True)
        except RenderError as exc:
            failures.append(f"{path.relative_to(ROOT)}: {exc}")
    if failures:
        raise RenderError("\n".join(failures))


def render_payloads(payload_paths: list[Path]) -> None:
    for path in payload_paths:
        render_word_page(path, dry_run=False)


def sync_numbers() -> None:
    original_index = read_text(WORD_INDEX)
    next_index, entries = sync_index(original_index)
    if next_index != original_index:
        write_text(WORD_INDEX, next_index)

    for order, entry in enumerate(entries, start=1):
        page_name = entry.href.removeprefix("./")
        path = PROTOTYPES / page_name
        original_page = read_text(path)
        next_page = sync_page_kicker(path, order)
        if next_page != original_page:
            write_text(path, next_page)


def validate_rendered_payloads(payload_paths: list[Path]) -> None:
    failures: list[str] = []
    for path in payload_paths:
        errors = validate_payload_page(path)
        for error in errors:
            failures.append(f"{path.relative_to(ROOT)}: {error}")
    if failures:
        raise RenderError("\n".join(failures))


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate payloads and optionally render a batch of new word pages.")
    parser.add_argument(
        "specs",
        type=Path,
        help="Pipe-delimited spec file describing the batch to generate.",
    )
    parser.add_argument(
        "--payload-only",
        action="store_true",
        help="Write payload JSON files only; skip render, sync, and validation.",
    )
    parser.add_argument(
        "--reuse-payloads",
        action="store_true",
        help="Allow resuming when payload JSON files already exist; existing rendered HTML pages are still rejected.",
    )
    args = parser.parse_args()

    specs_path = args.specs.resolve()

    try:
        rows = load_specs(specs_path)
        validate_specs(rows, allow_existing_payloads=args.reuse_payloads)
        payload_paths = write_payloads(rows)
        print(f"wrote {len(payload_paths)} payload files from {specs_path.relative_to(ROOT)}")

        dry_run_payloads(payload_paths)
        print(f"dry-run validated {len(payload_paths)} payloads")

        if args.payload_only:
            return 0

        render_payloads(payload_paths)
        print(f"rendered {len(payload_paths)} word pages")

        sync_numbers()
        print("synced word numbering and index order")

        validate_rendered_payloads(payload_paths)
        print(f"validated {len(payload_paths)} rendered payload/page pairs")
    except RenderError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
