from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = ROOT / ".codex" / "skills" / "daily-vocab-word-page" / "assets" / "template" / "word-page-template.html"
PROTOTYPES = ROOT / "prototypes"
WORD_INDEX = PROTOTYPES / "word-index.js"
PLACEHOLDER_RE = re.compile(r"{{([A-Z0-9_]+)}}")
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
IPA_FORMAT_RE = re.compile(r"^[^·\n]+ · UK /[^/\n]+/ · US /[^/\n]+/$")
CEFR_RE = re.compile(r"^(A1|A2|B1|B2|C1|C2)$")
ZIPF_RE = re.compile(r"^\d(?:\.\d{2})$")
CJK_RE = re.compile(r"[\u4e00-\u9fff]")
CHINESE_PLACEHOLDER_KEYS = {
    "THESIS",
    "LEARNING_POSITION",
    "CORE_IDEA",
    "CONCEPT_FOCUS",
    "TONE_REGISTER",
    "USE_WARNING",
    "SHORT_DEFINITION",
    "CONFUSION_NOTE",
    "FLOW_1",
    "FLOW_2",
    "FLOW_3",
    "ORIGIN_PARAGRAPH",
    "ORIGIN_MEMORY",
    "MEMORY_HOOK",
    "MEMORY_EXPLANATION",
    "DAILY_USAGE",
    "PROFESSIONAL_USAGE",
    "DOMAIN_USAGE",
    "COLLOCATION_NOTE",
    "COLLOCATION_NOTE_1",
    "COLLOCATION_NOTE_2",
    "COLLOCATION_NOTE_3",
    "NEIGHBOR_SELF_USE",
    "NEIGHBOR_1_MEANING",
    "NEIGHBOR_1_USE",
    "MODERN_USE_1",
    "MODERN_USE_2",
    "DICTIONARY_SOURCE_NOTE",
    "ETYMOLOGY_SOURCE_NOTE",
    "MODERN_SOURCE_NOTE",
    "CHECK_MEANING",
    "CHECK_ORIGIN",
    "CHECK_SENTENCE",
}


class RenderError(Exception):
    pass


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def write_text(path: Path, text: str) -> None:
    path.write_text(text, encoding="utf-8", newline="\n")


def load_payload(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        raise RenderError(f"invalid JSON in {path}: {exc}") from exc

    if not isinstance(payload, dict):
        raise RenderError("payload root must be a JSON object")
    return payload


def template_placeholders(template: str) -> set[str]:
    return set(PLACEHOLDER_RE.findall(template))


def require_object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise RenderError(f"{label} must be an object")
    return value


def require_string(value: Any, label: str) -> str:
    if not isinstance(value, str):
        raise RenderError(f"{label} must be a string")
    if not value.strip():
        raise RenderError(f"{label} must not be empty")
    return value


def validate_placeholders(payload: dict[str, Any], template: str) -> dict[str, str]:
    replacements_raw = require_object(payload.get("templatePlaceholders"), "templatePlaceholders")
    expected = template_placeholders(template)
    actual = set(replacements_raw)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)

    if missing:
        raise RenderError("missing templatePlaceholders: " + ", ".join(missing))
    if extra:
        raise RenderError("extra templatePlaceholders not used by template: " + ", ".join(extra))

    replacements: dict[str, str] = {}
    for key in sorted(actual):
        replacements[key] = require_string(replacements_raw[key], f"templatePlaceholders.{key}")
    return replacements


def validate_content_contract(replacements: dict[str, str]) -> None:
    ipa = replacements["IPA"]
    forbidden_ipa_labels = ["Respelling", "UK IPA", "US IPA"]
    for label in forbidden_ipa_labels:
        if label in ipa:
            raise RenderError(f'templatePlaceholders.IPA must not include "{label}"')
    if not IPA_FORMAT_RE.fullmatch(ipa):
        raise RenderError('templatePlaceholders.IPA must look like "ih-FEM-er-uhl · UK /.../ · US /.../"')

    if not CEFR_RE.fullmatch(replacements["CEFR_LEVEL"]):
        raise RenderError("templatePlaceholders.CEFR_LEVEL must be one of A1, A2, B1, B2, C1, or C2")
    if not ZIPF_RE.fullmatch(replacements["ZIPF_FREQUENCY"]):
        raise RenderError("templatePlaceholders.ZIPF_FREQUENCY must be a one-digit Zipf value with two decimals")

    word_code = f"<code>{replacements['WORD_LOWER']}</code>"
    if word_code not in replacements["CORE_IDEA"]:
        raise RenderError(f"templatePlaceholders.CORE_IDEA must include {word_code}")

    for key in sorted(CHINESE_PLACEHOLDER_KEYS):
        if not CJK_RE.search(replacements[key]):
            raise RenderError(f"templatePlaceholders.{key} must contain Traditional Chinese learning text")


def validate_target(payload: dict[str, Any], replacements: dict[str, str]) -> tuple[str, Path]:
    target = require_object(payload.get("target"), "target")
    slug = require_string(target.get("slug"), "target.slug")

    if not SLUG_RE.fullmatch(slug):
        raise RenderError("target.slug must use lowercase letters, digits, and single hyphens")
    if replacements.get("WORD_SLUG") != slug:
        raise RenderError("templatePlaceholders.WORD_SLUG must match target.slug")

    output_path = target.get("outputPath") or f"prototypes/{slug}.html"
    output_text = require_string(output_path, "target.outputPath")
    expected_output = f"prototypes/{slug}.html"
    normalized_output = output_text.replace("\\", "/")
    if normalized_output != expected_output:
        raise RenderError(f"target.outputPath must be {expected_output}")

    resolved_output = (ROOT / output_text).resolve()
    try:
        resolved_output.relative_to(PROTOTYPES.resolve())
    except ValueError as exc:
        raise RenderError("target.outputPath must stay inside prototypes/") from exc

    return slug, resolved_output


def validate_index_entry(payload: dict[str, Any], slug: str) -> dict[str, Any]:
    entry = require_object(payload.get("indexEntry"), "indexEntry")
    required_strings = ["id", "word", "partOfSpeech", "href", "thesis"]
    for key in required_strings:
        require_string(entry.get(key), f"indexEntry.{key}")

    if entry["id"] != slug:
        raise RenderError("indexEntry.id must match target.slug")
    if entry["href"] != f"./{slug}.html":
        raise RenderError(f'indexEntry.href must be "./{slug}.html"')

    tags = entry.get("tags")
    if not isinstance(tags, list) or not tags:
        raise RenderError("indexEntry.tags must be a non-empty array")
    for index, tag in enumerate(tags):
        require_string(tag, f"indexEntry.tags[{index}]")

    checks = entry.get("checks")
    if not isinstance(checks, list) or not checks:
        raise RenderError("indexEntry.checks must be a non-empty array")
    for index, check in enumerate(checks):
        check_obj = require_object(check, f"indexEntry.checks[{index}]")
        require_string(check_obj.get("id"), f"indexEntry.checks[{index}].id")
        require_string(check_obj.get("label"), f"indexEntry.checks[{index}].label")

    return entry


def render_template(template: str, replacements: dict[str, str]) -> str:
    rendered = template
    for key, value in replacements.items():
        rendered = rendered.replace(f"{{{{{key}}}}}", value)

    leftover = sorted(set(PLACEHOLDER_RE.findall(rendered)))
    if leftover:
        raise RenderError("unresolved placeholders after render: " + ", ".join(leftover))
    return rendered


def find_top_level_blocks(source: str) -> list[str]:
    lines = source.splitlines(keepends=True)
    blocks: list[str] = []
    start: int | None = None
    block_start_offset = 0
    offset = 0

    for line in lines:
        stripped = line.strip()
        is_top_level_indent = line.startswith("  ") and not line.startswith("    ")
        if is_top_level_indent and stripped == "{":
            start = offset
            block_start_offset = offset
        elif start is not None and is_top_level_indent and stripped in {"},", "}"}:
            blocks.append(source[block_start_offset : offset + len(line)])
            start = None
        offset += len(line)

    return blocks


def existing_index_values(source: str) -> tuple[set[str], set[str], int]:
    ids: set[str] = set()
    hrefs: set[str] = set()
    blocks = find_top_level_blocks(source)
    for block in blocks:
        id_match = re.search(r'id:\s*"([^"]+)"', block)
        href_match = re.search(r'href:\s*"([^"]+)"', block)
        if id_match:
            ids.add(id_match.group(1))
        if href_match:
            hrefs.add(href_match.group(1))
    return ids, hrefs, len(blocks)


def js_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def format_string_array(values: list[str], indent: str) -> str:
    inner = ",\n".join(f"{indent}  {js_string(value)}" for value in values)
    return "[\n" + inner + f"\n{indent}]"


def format_checks(checks: list[dict[str, str]], indent: str) -> str:
    parts = []
    for check in checks:
        parts.append(
            "\n".join(
                [
                    f"{indent}  {{",
                    f"{indent}    id: {js_string(check['id'])},",
                    f"{indent}    label: {js_string(check['label'])}",
                    f"{indent}  }}",
                ]
            )
        )
    return "[\n" + ",\n".join(parts) + f"\n{indent}]"


def format_index_entry(entry: dict[str, Any], order: int) -> str:
    tags = [str(tag) for tag in entry["tags"]]
    checks = [{"id": str(check["id"]), "label": str(check["label"])} for check in entry["checks"]]
    return "\n".join(
        [
            "  {",
            f"    id: {js_string(entry['id'])},",
            f"    word: {js_string(entry['word'])},",
            f"    partOfSpeech: {js_string(entry['partOfSpeech'])},",
            f"    href: {js_string(entry['href'])},",
            f"    order: {order},",
            f"    cefr: {js_string(entry['cefr'])},",
            f"    zipf: {entry['zipf']},",
            f"    thesis: {js_string(entry['thesis'])},",
            f"    tags: {format_string_array(tags, '    ')},",
            f"    checks: {format_checks(checks, '    ')}",
            "  }",
        ]
    )


def append_index_entry(source: str, entry: dict[str, Any]) -> str:
    ids, hrefs, count = existing_index_values(source)
    if entry["id"] in ids:
        raise RenderError(f'word-index.js already has id "{entry["id"]}"')
    if entry["href"] in hrefs:
        raise RenderError(f'word-index.js already has href "{entry["href"]}"')

    rendered_entry = format_index_entry(entry, count + 1)
    next_source, replacements = re.subn(r"\n\];\s*$", f",\n{rendered_entry}\n];\n", source, count=1)
    if replacements != 1:
        raise RenderError("could not find the closing window.WORD_INDEX array in word-index.js")
    return next_source


def render_word_page(payload_path: Path, dry_run: bool) -> list[str]:
    payload = load_payload(payload_path)
    template = read_text(TEMPLATE)
    replacements = validate_placeholders(payload, template)
    validate_content_contract(replacements)
    slug, output_path = validate_target(payload, replacements)
    entry = validate_index_entry(payload, slug)
    entry["cefr"] = replacements["CEFR_LEVEL"]
    entry["zipf"] = replacements["ZIPF_FREQUENCY"]

    if output_path.exists():
        raise RenderError(f"output page already exists: {output_path.relative_to(ROOT)}")

    index_source = read_text(WORD_INDEX)
    rendered_page = render_template(template, replacements)
    next_index = append_index_entry(index_source, entry)

    operations = [
        ("create", output_path.relative_to(ROOT)),
        ("update", WORD_INDEX.relative_to(ROOT)),
    ]

    if dry_run:
        return [f"would {action} {path}" for action, path in operations]

    write_text(output_path, rendered_page)
    write_text(WORD_INDEX, next_index)
    return [f"{action}d {path}" for action, path in operations]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Render a word-page payload into prototypes/<word-slug>.html and append word-index.js."
    )
    parser.add_argument("payload", type=Path, help="Path to a word-page payload JSON file.")
    parser.add_argument("--dry-run", action="store_true", help="Validate and report changes without writing files.")
    args = parser.parse_args()

    try:
        messages = render_word_page(args.payload.resolve(), args.dry_run)
    except RenderError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    for message in messages:
        print(message)
    if not args.dry_run:
        print("next: uv run python scripts\\sync_word_numbers.py")
        print("then: uv run python scripts\\validate_word_pages.py")
        print("then: uv run python scripts\\sync_word_numbers.py --check")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
