from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from render_word_page import (
    PROTOTYPES,
    ROOT,
    TEMPLATE,
    RenderError,
    load_payload,
    normalize_payload_sources,
    read_text,
    render_template,
    validate_content_contract,
    validate_placeholders,
    validate_source_policy,
    validate_target,
    write_text,
)


PAYLOADS = ROOT / "data" / "word-payloads"
KICKER_RE = re.compile(r'(<p class="kicker">)Word\s+(\d+)(\s*/\s*[^<]+</p>)')


def serialize_payload(payload: dict) -> str:
    return json.dumps(payload, ensure_ascii=False, indent=2) + "\n"


def preserve_word_number(rendered_page: str, current_page: str | None) -> str:
    if current_page is None:
        return rendered_page

    current_match = KICKER_RE.search(current_page)
    if not current_match:
        return rendered_page

    number = current_match.group(2)
    return KICKER_RE.sub(rf"\1Word {number}\3", rendered_page, count=1)


def payload_paths(args: argparse.Namespace) -> list[Path]:
    if args.payload:
        return [path.resolve() for path in args.payload]
    return sorted(PAYLOADS.glob("*.json"))


def normalize_payload_page(payload_path: Path, check: bool) -> list[str]:
    payload = load_payload(payload_path)
    normalize_payload_sources(payload)

    template = read_text(TEMPLATE)
    replacements = validate_placeholders(payload, template)
    validate_content_contract(replacements)
    validate_source_policy(payload, replacements)
    _, output_path = validate_target(payload, replacements)
    if output_path.parent != PROTOTYPES:
        raise RenderError("target.outputPath must resolve directly under prototypes/")

    current_page = read_text(output_path) if output_path.exists() else None
    rendered_page = preserve_word_number(render_template(template, replacements), current_page)
    next_payload = serialize_payload(payload)
    current_payload = read_text(payload_path)

    operations: list[str] = []
    if next_payload != current_payload:
        operations.append(f"update {payload_path.relative_to(ROOT)}")

    if current_page != rendered_page:
        verb = "update" if current_page is not None else "create"
        operations.append(f"{verb} {output_path.relative_to(ROOT)}")

    if check or not operations:
        return operations

    write_text(payload_path, next_payload)
    write_text(output_path, rendered_page)
    return operations


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Normalize source labels, sourceAudit, and rendered pages for all word payload/page pairs."
    )
    parser.add_argument("payload", nargs="*", type=Path, help="Optional payload JSON paths. Defaults to all payloads.")
    parser.add_argument("--check", action="store_true", help="Report drift without writing files.")
    args = parser.parse_args()

    failures: list[str] = []
    operations: list[str] = []
    paths = payload_paths(args)
    for path in paths:
        try:
            changes = normalize_payload_page(path, args.check)
        except RenderError as exc:
            failures.append(f"{path.relative_to(ROOT)}: {exc}")
            continue
        for change in changes:
            operations.append(change)

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        return 1

    if args.check:
        if operations:
            for change in operations:
                print(change)
            return 1
        print(f"source policy already normalized for {len(paths)} payload/page pairs")
        return 0

    for change in operations:
        print(change)
    print(f"normalized source policy for {len(paths)} payload/page pairs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
