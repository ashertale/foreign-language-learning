from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from render_word_page import (
    PLACEHOLDER_RE,
    PROTOTYPES,
    ROOT,
    TEMPLATE,
    RenderError,
    load_payload,
    read_text,
    validate_content_contract,
    validate_placeholders,
    validate_target,
)


PAYLOADS = ROOT / "data" / "word-payloads"
OLD_IPA_LABELS = ("Respelling", "UK IPA", "US IPA")


def compact_text(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def html_errors(path: Path, replacements: dict[str, str]) -> list[str]:
    source = read_text(path)
    errors: list[str] = []

    leftovers = sorted(set(PLACEHOLDER_RE.findall(source)))
    if leftovers:
        errors.append("unresolved HTML placeholders: " + ", ".join(leftovers))

    for label in OLD_IPA_LABELS:
        if label in source:
            errors.append(f'HTML must not contain old IPA label "{label}"')

    ipa_matches = re.findall(r'<span class="ipa">([^<]+)</span>', source)
    if ipa_matches != [replacements["IPA"]]:
        errors.append("HTML IPA span must match templatePlaceholders.IPA exactly")

    meta_match = re.search(
        r'<dl class="lexical-meta" aria-label="詞彙難度與頻率">(?P<body>.*?)</dl>',
        source,
        re.DOTALL,
    )
    if not meta_match:
        errors.append("HTML must include lexical-meta block")
    else:
        values = [compact_text(value) for value in re.findall(r"<dd>(.*?)</dd>", meta_match.group("body"), re.DOTALL)]
        expected = [replacements["CEFR_LEVEL"], replacements["ZIPF_FREQUENCY"]]
        if values != expected:
            errors.append("HTML lexical-meta values must match CEFR_LEVEL and ZIPF_FREQUENCY")

    data_speak_count = source.count(" data-speak=")
    if data_speak_count != 1:
        errors.append(f"expected exactly one data-speak button, found {data_speak_count}")

    data_check_count = source.count(" data-check=")
    if data_check_count != 3:
        errors.append(f"expected exactly three data-check inputs, found {data_check_count}")

    return errors


def validate_payload_page(payload_path: Path) -> list[str]:
    try:
        payload = load_payload(payload_path)
        template = read_text(TEMPLATE)
        replacements = validate_placeholders(payload, template)
        validate_content_contract(replacements)
        slug, output_path = validate_target(payload, replacements)
    except RenderError as exc:
        return [str(exc)]

    if output_path.parent != PROTOTYPES:
        return ["target.outputPath must resolve directly under prototypes/"]
    if output_path.name != f"{slug}.html":
        return [f"target.outputPath must end with {slug}.html"]
    if not output_path.exists():
        return [f"missing rendered page: {output_path.relative_to(ROOT)}"]

    return html_errors(output_path, replacements)


def payload_paths(args: argparse.Namespace) -> list[Path]:
    if args.payload:
        return [path.resolve() for path in args.payload]
    return sorted(PAYLOADS.glob("*.json"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate word-page payloads and rendered HTML pages.")
    parser.add_argument("payload", nargs="*", type=Path, help="Optional payload JSON paths. Defaults to all payloads.")
    args = parser.parse_args()

    failures: list[str] = []
    paths = payload_paths(args)
    for path in paths:
        errors = validate_payload_page(path)
        for error in errors:
            failures.append(f"{path.relative_to(ROOT)}: {error}")

    if failures:
        for failure in failures:
            print(failure, file=sys.stderr)
        return 1

    print(f"validated {len(paths)} word payload/page pairs")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
