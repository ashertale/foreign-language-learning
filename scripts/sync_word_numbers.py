from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROTOTYPES = ROOT / "prototypes"
WORD_INDEX = PROTOTYPES / "word-index.js"
NON_WORD_PAGES = {"index.html", "backlog.html", "review.html"}


@dataclass
class IndexEntry:
    href: str
    block: str


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="\n")


def js_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def find_top_level_blocks(source: str) -> list[tuple[int, int, str]]:
    lines = source.splitlines(keepends=True)
    blocks: list[tuple[int, int, str]] = []
    start: int | None = None

    offset = 0
    block_start_offset = 0
    for line in lines:
        stripped = line.strip()
        is_top_level_indent = line.startswith("  ") and not line.startswith("    ")

        if is_top_level_indent and stripped == "{":
            start = offset
            block_start_offset = offset
        elif start is not None and is_top_level_indent and stripped in {"},", "}"}:
            end = offset + len(line)
            blocks.append((block_start_offset, end, source[block_start_offset:end]))
            start = None
        offset += len(line)

    return blocks


def parse_entries(source: str) -> list[IndexEntry]:
    entries: list[IndexEntry] = []
    for _, _, block in find_top_level_blocks(source):
        href = re.search(r'href:\s*"(?P<href>\./[^"]+\.html)"', block)
        if href:
            entries.append(IndexEntry(href=href.group("href"), block=block))
    return entries


def is_word_page(path: Path) -> bool:
    if path.name in NON_WORD_PAGES:
        return False
    if not path.name.endswith(".html"):
        return False
    return bool(re.search(r'<body\s+class="word-[^"]+"', read_text(path), re.IGNORECASE))


def extract_first(pattern: str, source: str, default: str = "") -> str:
    match = re.search(pattern, source, re.IGNORECASE | re.DOTALL)
    return re.sub(r"\s+", " ", match.group(1)).strip() if match else default


def metadata_from_page(path: Path) -> dict[str, str]:
    source = read_text(path)
    word = extract_first(r"<h1>(.*?)</h1>", source, path.stem.title())
    part = extract_first(r'<p class="kicker">\s*Word\s+\d+\s*/\s*([^<]+)</p>', source, "unknown")
    thesis = extract_first(r'<p class="thesis">(.*?)</p>', source)
    return {
        "id": path.stem,
        "word": word,
        "part": part,
        "href": f"./{path.name}",
        "thesis": thesis,
    }


def minimal_entry(page: Path) -> str:
    meta = metadata_from_page(page)
    return (
        "  {\n"
        f'    id: "{js_string(meta["id"])}",\n'
        f'    word: "{js_string(meta["word"])}",\n'
        f'    partOfSpeech: "{js_string(meta["part"])}",\n'
        f'    href: "{js_string(meta["href"])}",\n'
        "    order: 0,\n"
        f'    thesis: "{js_string(meta["thesis"])}",\n'
        "    tags: [],\n"
        "    checks: []\n"
        "  }"
    )


def replace_order(block: str, order: int) -> str:
    return re.sub(r"order:\s*\d+,", f"order: {order},", block, count=1)


def sync_index(source: str) -> tuple[str, list[IndexEntry]]:
    blocks = find_top_level_blocks(source)
    entries = parse_entries(source)
    indexed_hrefs = {entry.href for entry in entries}
    word_pages = sorted(path for path in PROTOTYPES.glob("*.html") if is_word_page(path))
    missing_pages = [path for path in word_pages if f"./{path.name}" not in indexed_hrefs]

    if missing_pages:
        insertion = ",\n" + ",\n".join(minimal_entry(path) for path in missing_pages)
        source = re.sub(r"\n\];\s*$", f"{insertion}\n];\n", source, count=1)
        blocks = find_top_level_blocks(source)

    next_source = source
    shift = 0
    synced_entries: list[IndexEntry] = []

    for order, (start, end, block) in enumerate(blocks, start=1):
        href = re.search(r'href:\s*"(?P<href>\./[^"]+\.html)"', block)
        if not href:
            continue

        updated = replace_order(block, order)
        actual_start = start + shift
        actual_end = end + shift
        next_source = next_source[:actual_start] + updated + next_source[actual_end:]
        shift += len(updated) - (end - start)
        synced_entries.append(IndexEntry(href=href.group("href"), block=updated))

    return next_source, synced_entries


def sync_page_kicker(path: Path, order: int) -> str:
    source = read_text(path)
    return re.sub(
        r'(<p class="kicker">)Word\s+\d+(\s*/\s*[^<]+</p>)',
        rf"\1Word {order:02d}\2",
        source,
        count=1,
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync Word NN numbering between word-index.js and word pages.")
    parser.add_argument("--check", action="store_true", help="Report drift without writing files.")
    args = parser.parse_args()

    original_index = read_text(WORD_INDEX)
    next_index, entries = sync_index(original_index)
    changes: list[Path] = []

    if next_index != original_index:
        changes.append(WORD_INDEX)
        if not args.check:
            write_text(WORD_INDEX, next_index)

    for order, entry in enumerate(entries, start=1):
        page_name = entry.href.removeprefix("./")
        path = PROTOTYPES / page_name
        if not path.exists():
            print(f"warning: indexed page does not exist: {entry.href}", file=sys.stderr)
            continue

        original_page = read_text(path)
        next_page = sync_page_kicker(path, order)
        if next_page != original_page:
            changes.append(path)
            if not args.check:
                write_text(path, next_page)

    if args.check and changes:
        for path in changes:
            print(f"would update {path.relative_to(ROOT)}")
        return 1

    if changes:
        for path in changes:
            print(f"updated {path.relative_to(ROOT)}")
    else:
        print("word numbering is already in sync")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
