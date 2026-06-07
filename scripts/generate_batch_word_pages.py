from __future__ import annotations

import argparse
import csv
import sys
from dataclasses import dataclass
from pathlib import Path

from render_word_page import (
    ROOT,
    WORD_INDEX,
    RenderError,
    existing_index_values,
    find_top_level_blocks,
    load_payload,
    prepare_payload,
    read_text,
    render_page,
    render_word_page,
    write_text,
)
from sync_word_numbers import PROTOTYPES, sync_index, sync_page_kicker
from validate_word_pages import validate_payload_page


LLM_CONTENT_GUIDANCE = """\
Write one complete word-page payload for a serious English learner.

The payload must use the semantic `page` object used by this repo.
Write original section prose:

- Explain the concept, tone, register, and real usage boundary before translation.
- Let the word decide the emphasis. `usage`, `collocations.items`,
  `neighbors.others`, and `modernUse` are flexible containers, not quotas.
- Keep prose direct and concept-first. Do not write study-script lines such as
  `先讀搭配`, `如果你只能想起中文`, `最低摩擦入口`, or `這時重點是精準`.
- Do not use filler explanations that merely say the word "changes the situation"
  or "is not only about the action." Say what observable pressure, boundary,
  register, or consequence the word actually carries.
- Do not write generic page-making prose such as `這裡放在...情境時`,
  `這個搭配常用來寫...`, `本頁把...整理成...學習概念`, or
  `用在「...」這類判斷上`.
- Avoid repeating the same sentence frame inside one page. If two cards would
  start or explain themselves the same way, rewrite one around a concrete scene,
  collocation, contrast, or consequence.
- Keep usage examples natural. A usage card may carry Chinese context in its
  label while the body remains a natural example.
- Use collocations as living usage anchors and neighbors as confusion boundaries.
- If a batch starts producing repeated connector prose across words, stop and
  rewrite the affected payloads by word before rendering.
- Keep mnemonic images separate from historical claims.
- Prefer concise, specific Traditional Chinese learning prose with embedded
  English terms where they are the learning object.
- Keep `page.sources.*` and `sourceAudit` aligned to the actual source choices.
"""


@dataclass(frozen=True)
class PayloadInfo:
    path: Path
    payload: dict
    slug: str
    word: str
    href: str
    output_path: Path


def project_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def compact(value: str) -> str:
    return " ".join(value.split()).strip()


def current_index_snapshot() -> tuple[set[str], set[str], set[str]]:
    source = read_text(WORD_INDEX)
    ids, hrefs, _ = existing_index_values(source)
    words: set[str] = set()
    for block in find_top_level_blocks(source):
        marker = 'word: "'
        start = block.find(marker)
        if start == -1:
            continue
        start += len(marker)
        end = block.find('"', start)
        if end != -1:
            words.add(block[start:end].strip().lower())
    return ids, hrefs, words


def resolve_relative_path(raw: str, base: Path) -> Path:
    candidate = Path(raw.strip())
    if candidate.is_absolute():
        return candidate.resolve()

    relative_to_manifest = (base / candidate).resolve()
    if relative_to_manifest.exists():
        return relative_to_manifest

    return (ROOT / candidate).resolve()


def payloads_from_manifest(path: Path) -> list[Path]:
    with path.open("r", encoding="utf-8", newline="") as handle:
        sample = handle.readline()
        handle.seek(0)
        delimiter = "|" if "|" in sample else ","
        reader = csv.DictReader(handle, delimiter=delimiter)
        if not reader.fieldnames:
            raise RenderError(f"batch manifest is empty: {project_path(path)}")

        payload_key = next(
            (
                key
                for key in ("payload", "payload_path", "payload_json")
                if key in reader.fieldnames
            ),
            None,
        )
        if payload_key is None:
            raise RenderError(
                f"{project_path(path)} does not list payload JSON files. "
                "Batch manifests must point to complete payload JSON files; "
                "prepare semantic payload JSON files first, then provide a manifest "
                "with a payload column."
            )

        payload_paths: list[Path] = []
        for index, row in enumerate(reader, start=2):
            raw = compact(row.get(payload_key) or "")
            if not raw:
                raise RenderError(f"{project_path(path)} line {index} is missing {payload_key}")
            payload_paths.append(resolve_relative_path(raw, path.parent))

    return payload_paths


def payloads_from_text_list(path: Path) -> list[Path]:
    payload_paths: list[Path] = []
    for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        value = line.strip()
        if not value or value.startswith("#"):
            continue
        payload_paths.append(resolve_relative_path(value, path.parent))
        if not payload_paths[-1].name.endswith(".json"):
            raise RenderError(f"{project_path(path)} line {index} is not a JSON payload path")
    if not payload_paths:
        raise RenderError(f"payload list is empty: {project_path(path)}")
    return payload_paths


def payloads_from_input(path: Path) -> list[Path]:
    resolved = path.resolve()
    if resolved.is_dir():
        payload_paths = sorted(resolved.glob("*.json"))
        if not payload_paths:
            raise RenderError(f"no payload JSON files found in {project_path(resolved)}")
        return payload_paths

    if not resolved.is_file():
        raise RenderError(f"input not found: {project_path(resolved)}")

    suffix = resolved.suffix.lower()
    if suffix == ".json":
        return [resolved]
    if suffix in {".tsv", ".csv"}:
        return payloads_from_manifest(resolved)
    if suffix in {".txt", ".list"}:
        return payloads_from_text_list(resolved)

    raise RenderError(
        f"unsupported input type: {project_path(resolved)}. "
        "Use payload JSON files, a directory of payload JSON files, "
        "or a manifest with a payload column."
    )


def resolve_payload_inputs(inputs: list[Path]) -> list[Path]:
    payload_paths: list[Path] = []
    for path in inputs:
        payload_paths.extend(payloads_from_input(path))

    seen: set[Path] = set()
    unique_paths: list[Path] = []
    for path in payload_paths:
        resolved = path.resolve()
        if resolved in seen:
            raise RenderError(f"duplicate payload input: {project_path(resolved)}")
        seen.add(resolved)
        unique_paths.append(resolved)

    return unique_paths


def inspect_payload(path: Path) -> PayloadInfo:
    if not path.is_file():
        raise RenderError(f"payload not found: {project_path(path)}")
    payload = load_payload(path)
    model = prepare_payload(payload)
    return PayloadInfo(
        path=path,
        payload=payload,
        slug=model["slug"],
        word=str(model["word"]),
        href=str(model["indexEntry"]["href"]),
        output_path=Path(model["outputPath"]),
    )


def validate_payload_batch(payload_paths: list[Path], update_existing: bool) -> list[PayloadInfo]:
    existing_ids, existing_hrefs, existing_words = current_index_snapshot()
    batch_ids: set[str] = set()
    batch_hrefs: set[str] = set()
    batch_words: set[str] = set()
    infos: list[PayloadInfo] = []

    for path in payload_paths:
        info = inspect_payload(path)
        label = project_path(path)
        word_lower = info.word.lower()

        if info.slug in batch_ids:
            raise RenderError(f"{label} duplicates another batch id {info.slug}")
        if info.href in batch_hrefs:
            raise RenderError(f"{label} duplicates another batch href {info.href}")
        if word_lower in batch_words:
            raise RenderError(f"{label} duplicates another batch displayed word {info.word}")

        if update_existing:
            if info.slug not in existing_ids:
                raise RenderError(f"{label} cannot update missing index id {info.slug}")
            if info.href not in existing_hrefs:
                raise RenderError(f"{label} cannot update missing index href {info.href}")
            if not info.output_path.exists():
                raise RenderError(f"{label} cannot update missing page {project_path(info.output_path)}")
        else:
            if info.slug in existing_ids:
                raise RenderError(f"{label} duplicates existing id {info.slug}")
            if info.href in existing_hrefs:
                raise RenderError(f"{label} duplicates existing href {info.href}")
            if word_lower in existing_words:
                raise RenderError(f"{label} duplicates existing displayed word {info.word}")
            if info.output_path.exists():
                raise RenderError(f"{label} would overwrite existing page {project_path(info.output_path)}")

        batch_ids.add(info.slug)
        batch_hrefs.add(info.href)
        batch_words.add(word_lower)
        infos.append(info)

    return infos


def render_existing_payload(info: PayloadInfo) -> None:
    model = prepare_payload(info.payload)
    rendered = render_page(model)
    write_text(info.output_path, rendered)


def dry_run_payloads(payload_paths: list[Path]) -> None:
    failures: list[str] = []
    for path in payload_paths:
        try:
            render_word_page(path, dry_run=True)
        except RenderError as exc:
            failures.append(f"{project_path(path)}: {exc}")
    if failures:
        raise RenderError("\n".join(failures))


def render_new_payloads(payload_paths: list[Path]) -> None:
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
        if not path.exists():
            continue
        original_page = read_text(path)
        next_page = sync_page_kicker(path, order)
        if next_page != original_page:
            write_text(path, next_page)


def validate_rendered_payloads(payload_paths: list[Path]) -> None:
    failures: list[str] = []
    for path in payload_paths:
        errors = validate_payload_page(path)
        for error in errors:
            failures.append(f"{project_path(path)}: {error}")
    if failures:
        raise RenderError("\n".join(failures))


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Batch-validate and render semantic word-page payload JSON files."
    )
    parser.add_argument(
        "inputs",
        nargs="*",
        type=Path,
        help=(
            "Payload JSON files, directories of payload JSON files, or manifests "
            "with a payload column."
        ),
    )
    parser.add_argument(
        "--print-llm-guidance",
        action="store_true",
        help="Print the narrative guidance used when asking an LLM to write payload content.",
    )
    parser.add_argument(
        "--validate-only",
        "--payload-only",
        action="store_true",
        dest="validate_only",
        help="Validate payloads only; skip render, sync, and rendered page validation.",
    )
    parser.add_argument(
        "--update-existing",
        action="store_true",
        help="Re-render existing indexed pages from payload JSON without appending word-index.js.",
    )
    parser.add_argument(
        "--reuse-payloads",
        action="store_true",
        help="Deprecated compatibility flag; payload JSON inputs are always reused.",
    )
    args = parser.parse_args()

    if args.print_llm_guidance:
        print(LLM_CONTENT_GUIDANCE)
        if not args.inputs:
            return 0

    if not args.inputs:
        parser.error("inputs are required unless --print-llm-guidance is used")

    try:
        payload_paths = resolve_payload_inputs(args.inputs)
        infos = validate_payload_batch(payload_paths, update_existing=args.update_existing)
        print(f"validated {len(infos)} semantic payloads")

        if not args.update_existing:
            dry_run_payloads(payload_paths)
            print(f"dry-run validated {len(payload_paths)} new page renders")

        if args.validate_only:
            return 0

        if args.update_existing:
            for info in infos:
                render_existing_payload(info)
            print(f"updated {len(infos)} existing word pages")
        else:
            render_new_payloads(payload_paths)
            print(f"rendered {len(payload_paths)} new word pages")

        sync_numbers()
        print("synced word numbering and index order")

        validate_rendered_payloads(payload_paths)
        print(f"validated {len(payload_paths)} rendered payload/page pairs")
    except RenderError as exc:
        print(exc, file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
