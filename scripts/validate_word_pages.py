from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from render_word_page import PROTOTYPES, ROOT, RenderError, load_payload, prepare_payload, read_text, render_page


PAYLOADS = ROOT / "data" / "word-payloads"
KICKER_RE = re.compile(r'(<p class="kicker">)Word\s+(\d+)(\s*/\s*[^<]+</p>)')
REMOVED_UI_LABELS = ("今日定位", "概念焦點", "語氣質地", "使用提醒", "字源來源", "主動回想")
OLD_IPA_LABELS = ("Respelling", "UK IPA", "US IPA")
WORD_PAGE_SCRIPT = PROTOTYPES / "word-page.js"


def preserve_word_number(rendered_page: str, current_page: str) -> str:
    current_match = KICKER_RE.search(current_page)
    if not current_match:
        return rendered_page
    number = current_match.group(2)
    return KICKER_RE.sub(rf"\1Word {number}\3", rendered_page, count=1)


def html_errors(path: Path, expected_html: str) -> list[str]:
    source = read_text(path)
    errors: list[str] = []

    if preserve_word_number(expected_html, source) != source:
        errors.append("rendered HTML does not match the current payload")

    if "{{" in source or "}}" in source:
        errors.append("HTML must not contain unresolved template placeholders")

    for label in OLD_IPA_LABELS:
        if label in source:
            errors.append(f'HTML must not contain old IPA label "{label}"')

    for label in REMOVED_UI_LABELS:
        if label in source:
            errors.append(f'HTML must not contain removed section label "{label}"')

    data_speak_count = source.count(" data-speak=")
    if data_speak_count != 1:
        errors.append(f"expected exactly one data-speak button, found {data_speak_count}")

    data_check_count = source.count(" data-check=")
    if data_check_count != 0:
        errors.append(f"word pages must not contain page-local review inputs; found {data_check_count}")

    return errors


def validate_payload_page(payload_path: Path) -> list[str]:
    try:
        payload = load_payload(payload_path)
        model = prepare_payload(payload)
    except RenderError as exc:
        return [str(exc)]

    output_path = Path(model["outputPath"])
    if output_path.parent != PROTOTYPES:
        return ["target.outputPath must resolve directly under prototypes/"]
    if output_path.name != f"{model['slug']}.html":
        return [f"target.outputPath must end with {model['slug']}.html"]
    if not output_path.exists():
        return [f"missing rendered page: {output_path.relative_to(ROOT)}"]

    return html_errors(output_path, render_page(model))


def speech_playback_errors() -> list[str]:
    source = read_text(WORD_PAGE_SCRIPT)
    errors: list[str] = []

    if "SPEECH_WARMUP" in source or "startSpeechWithWarmup" in source:
        errors.append("speech playback must not include an audible warmup utterance")

    if "SPEECH_REPEAT_SEPARATOR" not in source:
        errors.append("missing repeated actual utterance separator for clipped speech playback")

    if not re.search(r"\$\{\s*text\s*\}\$\{\s*SPEECH_REPEAT_SEPARATOR\s*\}\$\{\s*text\s*\}", source):
        errors.append("actual speech utterance must repeat the original word in the same utterance")

    if not re.search(r"onStart\(\s*createEnglishUtterance\(\s*text\s*,\s*\{\s*repeatForClipping:\s*true,?\s*\}\s*\)\s*\)", source):
        errors.append("speech utterance must use repeated playback")

    if re.search(r"volume:\s*0(?:[,}\n])", source) or re.search(r"SPEECH_WARMUP_VOLUME\s*=\s*0(?:[;\n])", source):
        errors.append("speech playback must not use skipped zero-volume utterances")

    if "speechUtterancesInFlight" not in source or "retainUtterance(utterance)" not in source:
        errors.append("speech utterances must be retained until end/error to avoid browser GC truncation")

    return errors


def payload_paths(args: argparse.Namespace) -> list[Path]:
    if args.payload:
        return [path.resolve() for path in args.payload]
    return sorted(PAYLOADS.glob("*.json"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate semantic word-page payloads and rendered HTML pages.")
    parser.add_argument("payload", nargs="*", type=Path, help="Optional payload JSON paths. Defaults to all payloads.")
    args = parser.parse_args()

    failures: list[str] = []
    for error in speech_playback_errors():
        failures.append(f"{WORD_PAGE_SCRIPT.relative_to(ROOT)}: {error}")

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
