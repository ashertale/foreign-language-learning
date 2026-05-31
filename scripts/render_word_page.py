from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
PROTOTYPES = ROOT / "prototypes"
WORD_INDEX = PROTOTYPES / "word-index.js"
SLUG_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
IPA_FORMAT_RE = re.compile(r"^[^·\n]+ · UK /[^/\n]+/ · US /[^/\n]+/$")
CEFR_RE = re.compile(r"^(A1|A2|B1|B2|C1|C2)$")
ZIPF_RE = re.compile(r"^\d(?:\.\d{2})$")
CJK_RE = re.compile(r"[\u4e00-\u9fff]")
OLD_IPA_LABELS = ("Respelling", "UK IPA", "US IPA")
BANNED_META_PHRASES = (
    "先讀搭配",
    "如果你只能想起中文",
    "最低摩擦入口",
    "這時重點是精準",
    "真正掌握它的標準是",
    "先讓這個畫面浮上來",
    "先造句，再回頭檢查",
)
SOURCE_POLICY_ORDER = (
    "dictionary-pronunciation",
    "level-frequency",
    "etymology-history",
    "modern-common-usage",
)
SOURCE_POLICY = {
    "dictionary-pronunciation": {
        "usedFor": "definition, pronunciation, and dictionary sense support",
        "options": (
            {"label": "Cambridge Dictionary", "rank": 1, "domains": ("dictionary.cambridge.org",)},
            {"label": "Merriam-Webster", "rank": 2, "domains": ("merriam-webster.com",)},
            {"label": "Oxford Learner's Dictionaries", "rank": 3, "domains": ("oxfordlearnersdictionaries.com",)},
            {"label": "Britannica Dictionary", "rank": 3, "domains": ("britannica.com",)},
        ),
    },
    "level-frequency": {
        "usedFor": "Zipf frequency reference and repo-calibrated CEFR study band",
        "options": (
            {
                "label": "wordfreq Zipf + repo CEFR calibration",
                "rank": 1,
                "domains": ("github.com",),
                "pathFragment": "/rspeer/wordfreq",
            },
        ),
    },
    "etymology-history": {
        "usedFor": "etymology and word-history support",
        "options": (
            {"label": "Online Etymology Dictionary", "rank": 1, "domains": ("etymonline.com",)},
            {"label": "Merriam-Webster", "rank": 2, "domains": ("merriam-webster.com",)},
        ),
    },
    "modern-common-usage": {
        "usedFor": "modern usage examples and current usage boundaries",
        "options": (
            {"label": "Merriam-Webster", "rank": 1, "domains": ("merriam-webster.com",)},
            {"label": "Cambridge Dictionary", "rank": 2, "domains": ("dictionary.cambridge.org",)},
            {"label": "Britannica Dictionary", "rank": 3, "domains": ("britannica.com",)},
        ),
    },
}
SOURCE_LABEL_ALIASES = {
    "Cambridge examples": "Cambridge Dictionary",
    "Cambridge Pronunciation": "Cambridge Dictionary",
    "CEFR study label + wordfreq": "wordfreq Zipf + repo CEFR calibration",
    "CEFR study label + wordfreq-style Zipf": "wordfreq Zipf + repo CEFR calibration",
    "Merriam-Webster examples": "Merriam-Webster",
    "Oxford Learner's": "Oxford Learner's Dictionaries",
}
SOURCE_AUDIT_STATIC = {
    "level-frequency": {
        "label": "wordfreq Zipf + repo CEFR calibration",
        "url": "https://github.com/rspeer/wordfreq",
    }
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


def require_object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise RenderError(f"{label} must be an object")
    return value


def require_string(value: Any, label: str) -> str:
    if not isinstance(value, str):
        raise RenderError(f"{label} must be a string")
    if not value.strip():
        raise RenderError(f"{label} must not be empty")
    return value.strip()


def require_optional_string(value: Any, label: str) -> str:
    if value is None:
        return ""
    if not isinstance(value, str):
        raise RenderError(f"{label} must be a string when present")
    return value.strip()


def require_list(value: Any, label: str, *, min_items: int = 0) -> list[Any]:
    if not isinstance(value, list):
        raise RenderError(f"{label} must be an array")
    if len(value) < min_items:
        raise RenderError(f"{label} must contain at least {min_items} item(s)")
    return value


def compact_text(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def ensure_cjk(value: str, label: str) -> None:
    if not CJK_RE.search(value):
        raise RenderError(f"{label} must contain Traditional Chinese learning text")


def ensure_narrative_voice(value: str, label: str) -> None:
    normalized = compact_text(value)
    for phrase in BANNED_META_PHRASES:
        if phrase in normalized:
            raise RenderError(f"{label} still reads like a study script: {phrase}")


def normalize_source_label(label: str) -> str:
    base = compact_text(label).split(":", 1)[0].strip()
    return SOURCE_LABEL_ALIASES.get(base, base)


def normalized_host(url: str) -> str:
    parsed = urlparse(url)
    host = parsed.netloc.strip().lower()
    if host.startswith("www."):
        host = host[4:]
    return host


def source_url_matches(option: dict[str, Any], url: str) -> bool:
    parsed = urlparse(url)
    host = normalized_host(url)
    if not host:
        return False
    for domain in option["domains"]:
        domain_text = str(domain).lower()
        if host == domain_text or host.endswith("." + domain_text):
            path_fragment = option.get("pathFragment")
            if path_fragment and path_fragment not in parsed.path.lower():
                return False
            return True
    return False


def canonical_source_choice(category: str, label: str, url: str, field_label: str) -> tuple[str, str]:
    options = SOURCE_POLICY[category]["options"]
    normalized_label = normalize_source_label(label)
    normalized_url = compact_text(url)
    by_url = [option for option in options if source_url_matches(option, normalized_url)]

    if by_url:
        for option in by_url:
            if normalized_label == option["label"]:
                return option["label"], normalized_url
        return by_url[0]["label"], normalized_url

    for option in options:
        if normalized_label == option["label"]:
            return option["label"], normalized_url

    allowed = ", ".join(f"{option['label']} (rank {option['rank']})" for option in options)
    raise RenderError(f"{field_label} must use an approved source for {category}: {allowed}")


def source_audit_entries(source_audit: Any) -> dict[str, dict[str, Any]]:
    entries = require_list(source_audit, "sourceAudit", min_items=len(SOURCE_POLICY_ORDER))
    entries_by_category: dict[str, dict[str, Any]] = {}
    for index, entry in enumerate(entries):
        entry_obj = require_object(entry, f"sourceAudit[{index}]")
        category = require_string(entry_obj.get("category"), f"sourceAudit[{index}].category")
        if category in entries_by_category:
            raise RenderError(f"sourceAudit must not repeat category {category}")
        entries_by_category[category] = entry_obj

    expected = set(SOURCE_POLICY_ORDER)
    actual = set(entries_by_category)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing:
        raise RenderError("sourceAudit is missing categories: " + ", ".join(missing))
    if extra:
        raise RenderError("sourceAudit has unsupported categories: " + ", ".join(extra))
    return entries_by_category


def canonical_etymology_audit(payload: dict[str, Any]) -> tuple[str, str]:
    entries_by_category = source_audit_entries(payload.get("sourceAudit"))
    entry = entries_by_category["etymology-history"]
    label = require_string(entry.get("label"), "sourceAudit[etymology-history].label")
    url = require_string(entry.get("url"), "sourceAudit[etymology-history].url")
    return canonical_source_choice("etymology-history", label, url, "sourceAudit[etymology-history]")


def expected_source_audit(page: dict[str, Any], etymology_source: tuple[str, str]) -> list[dict[str, str]]:
    sources = page["sources"]
    return [
        {
            "category": "dictionary-pronunciation",
            "label": sources["dictionary"]["label"],
            "url": sources["dictionary"]["url"],
            "usedFor": SOURCE_POLICY["dictionary-pronunciation"]["usedFor"],
        },
        {
            "category": "level-frequency",
            "label": SOURCE_AUDIT_STATIC["level-frequency"]["label"],
            "url": SOURCE_AUDIT_STATIC["level-frequency"]["url"],
            "usedFor": SOURCE_POLICY["level-frequency"]["usedFor"],
        },
        {
            "category": "etymology-history",
            "label": etymology_source[0],
            "url": etymology_source[1],
            "usedFor": SOURCE_POLICY["etymology-history"]["usedFor"],
        },
        {
            "category": "modern-common-usage",
            "label": sources["modern"]["label"],
            "url": sources["modern"]["url"],
            "usedFor": SOURCE_POLICY["modern-common-usage"]["usedFor"],
        },
    ]


def validate_target(payload: dict[str, Any]) -> tuple[dict[str, str], str, Path]:
    target = require_object(payload.get("target"), "target")
    word = require_string(target.get("word"), "target.word")
    slug = require_string(target.get("slug"), "target.slug")

    if not SLUG_RE.fullmatch(slug):
        raise RenderError("target.slug must use lowercase letters, digits, and single hyphens")

    output_path = require_string(target.get("outputPath") or f"prototypes/{slug}.html", "target.outputPath")
    expected_output = f"prototypes/{slug}.html"
    normalized_output = output_path.replace("\\", "/")
    if normalized_output != expected_output:
        raise RenderError(f"target.outputPath must be {expected_output}")

    resolved_output = (ROOT / output_path).resolve()
    try:
        resolved_output.relative_to(PROTOTYPES.resolve())
    except ValueError as exc:
        raise RenderError("target.outputPath must stay inside prototypes/") from exc

    return {"word": word, "slug": slug, "outputPath": normalized_output}, slug, resolved_output


def validate_page(payload: dict[str, Any], target: dict[str, str]) -> dict[str, Any]:
    page = require_object(payload.get("page"), "page")
    part_of_speech = require_string(page.get("partOfSpeech"), "page.partOfSpeech")
    pronunciation = require_string(page.get("pronunciation"), "page.pronunciation")
    for label in OLD_IPA_LABELS:
        if label in pronunciation:
            raise RenderError(f'page.pronunciation must not include "{label}"')
    if not IPA_FORMAT_RE.fullmatch(pronunciation):
        raise RenderError('page.pronunciation must look like "ih-FEM-er-uhl · UK /.../ · US /.../"')

    hero = require_object(page.get("hero"), "page.hero")
    thesis = require_string(hero.get("thesis"), "page.hero.thesis")
    ensure_cjk(thesis, "page.hero.thesis")
    ensure_narrative_voice(thesis, "page.hero.thesis")

    cefr_level = require_string(hero.get("cefrLevel"), "page.hero.cefrLevel")
    if not CEFR_RE.fullmatch(cefr_level):
        raise RenderError("page.hero.cefrLevel must be one of A1, A2, B1, B2, C1, or C2")

    zipf_frequency = require_string(hero.get("zipfFrequency"), "page.hero.zipfFrequency")
    if not ZIPF_RE.fullmatch(zipf_frequency):
        raise RenderError("page.hero.zipfFrequency must be a one-digit Zipf value with two decimals")

    core_idea = require_string(page.get("coreIdea"), "page.coreIdea")
    ensure_cjk(core_idea, "page.coreIdea")
    ensure_narrative_voice(core_idea, "page.coreIdea")

    definition = require_object(page.get("definition"), "page.definition")
    summary = require_string(definition.get("summary"), "page.definition.summary")
    ensure_cjk(summary, "page.definition.summary")
    ensure_narrative_voice(summary, "page.definition.summary")

    contrast = require_object(definition.get("contrast"), "page.definition.contrast")
    contrast_word = require_string(contrast.get("word"), "page.definition.contrast.word")
    contrast_note = require_string(contrast.get("note"), "page.definition.contrast.note")
    ensure_cjk(contrast_note, "page.definition.contrast.note")
    ensure_narrative_voice(contrast_note, "page.definition.contrast.note")

    flow = require_list(definition.get("flow"), "page.definition.flow", min_items=2)
    flow_values: list[str] = []
    for index, item in enumerate(flow):
        value = require_string(item, f"page.definition.flow[{index}]")
        ensure_cjk(value, f"page.definition.flow[{index}]")
        ensure_narrative_voice(value, f"page.definition.flow[{index}]")
        flow_values.append(value)

    origin = None
    if page.get("origin") is not None:
        origin_raw = require_object(page.get("origin"), "page.origin")
        history = require_optional_string(origin_raw.get("history"), "page.origin.history")
        memory_lens = require_optional_string(origin_raw.get("memoryLens"), "page.origin.memoryLens")
        if not history and not memory_lens:
            raise RenderError("page.origin must contain history or memoryLens when present")
        if history:
            ensure_cjk(history, "page.origin.history")
            ensure_narrative_voice(history, "page.origin.history")
        if memory_lens:
            ensure_cjk(memory_lens, "page.origin.memoryLens")
            ensure_narrative_voice(memory_lens, "page.origin.memoryLens")
        origin = {
            "history": history,
            "memoryLens": memory_lens,
        }

    memory = require_object(page.get("memory"), "page.memory")
    memory_hook = require_string(memory.get("hook"), "page.memory.hook")
    memory_explanation = require_string(memory.get("explanation"), "page.memory.explanation")
    ensure_cjk(memory_hook, "page.memory.hook")
    ensure_cjk(memory_explanation, "page.memory.explanation")
    ensure_narrative_voice(memory_hook, "page.memory.hook")
    ensure_narrative_voice(memory_explanation, "page.memory.explanation")

    usage = require_list(page.get("usage"), "page.usage", min_items=1)
    usage_items: list[dict[str, str]] = []
    for index, item in enumerate(usage):
        item_obj = require_object(item, f"page.usage[{index}]")
        label = require_string(item_obj.get("label"), f"page.usage[{index}].label")
        body = require_string(item_obj.get("body"), f"page.usage[{index}].body")
        ensure_cjk(body, f"page.usage[{index}].body")
        ensure_narrative_voice(body, f"page.usage[{index}].body")
        usage_items.append({"label": label, "body": body})

    collocations_raw = require_object(page.get("collocations"), "page.collocations")
    collocation_note = require_optional_string(collocations_raw.get("note"), "page.collocations.note")
    if collocation_note:
        ensure_cjk(collocation_note, "page.collocations.note")
        ensure_narrative_voice(collocation_note, "page.collocations.note")

    collocation_items = require_list(collocations_raw.get("items"), "page.collocations.items", min_items=1)
    collocations: list[dict[str, str]] = []
    for index, item in enumerate(collocation_items):
        item_obj = require_object(item, f"page.collocations.items[{index}]")
        phrase = require_string(item_obj.get("phrase"), f"page.collocations.items[{index}].phrase")
        register = require_string(item_obj.get("register"), f"page.collocations.items[{index}].register")
        note = require_optional_string(item_obj.get("note"), f"page.collocations.items[{index}].note")
        if note:
            ensure_cjk(note, f"page.collocations.items[{index}].note")
            ensure_narrative_voice(note, f"page.collocations.items[{index}].note")
        collocations.append({"phrase": phrase, "register": register, "note": note})

    neighbors_raw = require_object(page.get("neighbors"), "page.neighbors")
    self_entry = require_object(neighbors_raw.get("self"), "page.neighbors.self")
    self_meaning = require_string(self_entry.get("meaning"), "page.neighbors.self.meaning")
    self_use = require_string(self_entry.get("use"), "page.neighbors.self.use")
    ensure_cjk(self_meaning, "page.neighbors.self.meaning")
    ensure_cjk(self_use, "page.neighbors.self.use")
    ensure_narrative_voice(self_meaning, "page.neighbors.self.meaning")
    ensure_narrative_voice(self_use, "page.neighbors.self.use")

    others_raw = require_list(neighbors_raw.get("others"), "page.neighbors.others", min_items=1)
    neighbors: list[dict[str, str]] = []
    for index, item in enumerate(others_raw):
        item_obj = require_object(item, f"page.neighbors.others[{index}]")
        word = require_string(item_obj.get("word"), f"page.neighbors.others[{index}].word")
        meaning = require_string(item_obj.get("meaning"), f"page.neighbors.others[{index}].meaning")
        use = require_string(item_obj.get("use"), f"page.neighbors.others[{index}].use")
        ensure_cjk(meaning, f"page.neighbors.others[{index}].meaning")
        ensure_cjk(use, f"page.neighbors.others[{index}].use")
        ensure_narrative_voice(meaning, f"page.neighbors.others[{index}].meaning")
        ensure_narrative_voice(use, f"page.neighbors.others[{index}].use")
        neighbors.append({"word": word, "meaning": meaning, "use": use})

    modern_use_raw = require_list(page.get("modernUse"), "page.modernUse", min_items=1)
    modern_use: list[str] = []
    for index, item in enumerate(modern_use_raw):
        value = require_string(item, f"page.modernUse[{index}]")
        ensure_cjk(value, f"page.modernUse[{index}]")
        ensure_narrative_voice(value, f"page.modernUse[{index}]")
        modern_use.append(value)

    sources_raw = require_object(page.get("sources"), "page.sources")
    dictionary_raw = require_object(sources_raw.get("dictionary"), "page.sources.dictionary")
    modern_raw = require_object(sources_raw.get("modern"), "page.sources.modern")

    dictionary = {
        "note": require_string(dictionary_raw.get("note"), "page.sources.dictionary.note"),
        "url": require_string(dictionary_raw.get("url"), "page.sources.dictionary.url"),
        "label": require_string(dictionary_raw.get("label"), "page.sources.dictionary.label"),
    }
    modern = {
        "note": require_string(modern_raw.get("note"), "page.sources.modern.note"),
        "url": require_string(modern_raw.get("url"), "page.sources.modern.url"),
        "label": require_string(modern_raw.get("label"), "page.sources.modern.label"),
    }
    ensure_cjk(dictionary["note"], "page.sources.dictionary.note")
    ensure_cjk(modern["note"], "page.sources.modern.note")
    ensure_narrative_voice(dictionary["note"], "page.sources.dictionary.note")
    ensure_narrative_voice(modern["note"], "page.sources.modern.note")

    return {
        "partOfSpeech": part_of_speech,
        "pronunciation": pronunciation,
        "hero": {
            "thesis": thesis,
            "cefrLevel": cefr_level,
            "zipfFrequency": zipf_frequency,
        },
        "coreIdea": core_idea,
        "definition": {
            "summary": summary,
            "contrast": {
                "word": contrast_word,
                "note": contrast_note,
            },
            "flow": flow_values,
        },
        "origin": origin,
        "memory": {
            "hook": memory_hook,
            "explanation": memory_explanation,
        },
        "usage": usage_items,
        "collocations": {
            "note": collocation_note,
            "items": collocations,
        },
        "neighbors": {
            "self": {
                "word": target["word"],
                "meaning": self_meaning,
                "use": self_use,
            },
            "others": neighbors,
        },
        "modernUse": modern_use,
        "sources": {
            "dictionary": dictionary,
            "modern": modern,
        },
    }


def validate_source_policy(payload: dict[str, Any], page: dict[str, Any]) -> None:
    sources = page["sources"]
    dictionary_label, dictionary_url = canonical_source_choice(
        "dictionary-pronunciation",
        sources["dictionary"]["label"],
        sources["dictionary"]["url"],
        "page.sources.dictionary",
    )
    if sources["dictionary"]["label"] != dictionary_label:
        raise RenderError(f"page.sources.dictionary.label must use canonical source label {dictionary_label}")
    if sources["dictionary"]["url"] != dictionary_url:
        raise RenderError("page.sources.dictionary.url must use a normalized source URL without extra whitespace")

    modern_label, modern_url = canonical_source_choice(
        "modern-common-usage",
        sources["modern"]["label"],
        sources["modern"]["url"],
        "page.sources.modern",
    )
    if sources["modern"]["label"] != modern_label:
        raise RenderError(f"page.sources.modern.label must use canonical source label {modern_label}")
    if sources["modern"]["url"] != modern_url:
        raise RenderError("page.sources.modern.url must use a normalized source URL without extra whitespace")

    entries_by_category = source_audit_entries(payload.get("sourceAudit"))
    etymology_source = canonical_etymology_audit(payload)
    expected = expected_source_audit(page, etymology_source)
    for expected_entry in expected:
        entry = entries_by_category[expected_entry["category"]]
        label = require_string(entry.get("label"), f"sourceAudit[{expected_entry['category']}].label")
        url = require_string(entry.get("url"), f"sourceAudit[{expected_entry['category']}].url")
        used_for = require_string(entry.get("usedFor"), f"sourceAudit[{expected_entry['category']}].usedFor")
        if label != expected_entry["label"] or url != expected_entry["url"]:
            raise RenderError(f"sourceAudit[{expected_entry['category']}] must mirror the selected payload source exactly")
        if used_for != expected_entry["usedFor"]:
            raise RenderError(f"sourceAudit[{expected_entry['category']}].usedFor must be {expected_entry['usedFor']}")


def normalize_payload_sources(payload: dict[str, Any]) -> bool:
    page = require_object(payload.get("page"), "page")
    sources = require_object(page.get("sources"), "page.sources")
    dictionary = require_object(sources.get("dictionary"), "page.sources.dictionary")
    modern = require_object(sources.get("modern"), "page.sources.modern")
    changed = False

    dictionary_label, dictionary_url = canonical_source_choice(
        "dictionary-pronunciation",
        require_string(dictionary.get("label"), "page.sources.dictionary.label"),
        require_string(dictionary.get("url"), "page.sources.dictionary.url"),
        "page.sources.dictionary",
    )
    if dictionary["label"] != dictionary_label:
        dictionary["label"] = dictionary_label
        changed = True
    if dictionary["url"] != dictionary_url:
        dictionary["url"] = dictionary_url
        changed = True

    modern_label, modern_url = canonical_source_choice(
        "modern-common-usage",
        require_string(modern.get("label"), "page.sources.modern.label"),
        require_string(modern.get("url"), "page.sources.modern.url"),
        "page.sources.modern",
    )
    if modern["label"] != modern_label:
        modern["label"] = modern_label
        changed = True
    if modern["url"] != modern_url:
        modern["url"] = modern_url
        changed = True

    etymology_source = canonical_etymology_audit(payload)
    next_audit = expected_source_audit(page, etymology_source)
    if payload.get("sourceAudit") != next_audit:
        payload["sourceAudit"] = next_audit
        changed = True

    return changed


def validate_index_entry(
    payload: dict[str, Any],
    slug: str,
    word: str,
    part_of_speech: str,
    thesis: str,
) -> dict[str, Any]:
    entry = require_object(payload.get("indexEntry"), "indexEntry")
    for key in ("id", "word", "partOfSpeech", "href", "thesis"):
        require_string(entry.get(key), f"indexEntry.{key}")

    if entry["id"] != slug:
        raise RenderError("indexEntry.id must match target.slug")
    if entry["href"] != f"./{slug}.html":
        raise RenderError(f'indexEntry.href must be "./{slug}.html"')
    if entry["word"] != word:
        raise RenderError("indexEntry.word must match target.word")
    if entry["partOfSpeech"] != part_of_speech:
        raise RenderError("indexEntry.partOfSpeech must match page.partOfSpeech")
    if entry["thesis"] != thesis:
        raise RenderError("indexEntry.thesis must match page.hero.thesis")

    tags = require_list(entry.get("tags"), "indexEntry.tags", min_items=1)
    for index, tag in enumerate(tags):
        require_string(tag, f"indexEntry.tags[{index}]")

    checks = require_list(entry.get("checks"), "indexEntry.checks", min_items=1)
    for index, check in enumerate(checks):
        check_obj = require_object(check, f"indexEntry.checks[{index}]")
        require_string(check_obj.get("id"), f"indexEntry.checks[{index}].id")
        require_string(check_obj.get("label"), f"indexEntry.checks[{index}].label")

    return entry


def prepare_payload(payload: dict[str, Any]) -> dict[str, Any]:
    target, slug, output_path = validate_target(payload)
    page = validate_page(payload, target)
    validate_source_policy(payload, page)
    index_entry = validate_index_entry(
        payload,
        slug,
        target["word"],
        page["partOfSpeech"],
        page["hero"]["thesis"],
    )
    return {
        "target": target,
        "slug": slug,
        "word": target["word"],
        "wordLower": target["word"].lower(),
        "outputPath": output_path,
        "page": page,
        "indexEntry": index_entry,
    }


def render_flow(flow: list[str]) -> str:
    parts: list[str] = ['        <div class="concept-flow" aria-label="概念流程">']
    for index, item in enumerate(flow):
        parts.append(f'          <div class="flow-step">{item}</div>')
        if index != len(flow) - 1:
            parts.append('          <div class="flow-arrow">→</div>')
    parts.append("        </div>")
    return "\n".join(parts)


def render_origin(origin: dict[str, str] | None) -> str:
    if not origin:
        return ""

    parts = [
        '      <section class="chapter" id="origin">',
        '        <p class="section-label">Origin</p>',
        "        <h2>字源</h2>",
    ]
    if origin["history"]:
        parts.append(f"        <p>{origin['history']}</p>")
    if origin["memoryLens"]:
        parts.append(f"        <p>{origin['memoryLens']}</p>")
    parts.append("      </section>")
    return "\n".join(parts)


def render_usage_cards(usage: list[dict[str, str]]) -> str:
    parts = ['        <div class="example-grid">']
    for item in usage:
        parts.extend(
            [
                '          <div class="example">',
                f"            <strong>{item['label']}</strong>",
                f"            <p>{item['body']}</p>",
                "          </div>",
            ]
        )
    parts.append("        </div>")
    return "\n".join(parts)


def render_collocations(collocations: dict[str, Any], word_lower: str) -> str:
    parts = [
        f'        <div class="collocation-list" aria-label="{word_lower} collocations">'
    ]
    for item in collocations["items"]:
        parts.extend(
            [
                '          <article class="collocation-card">',
                "            <div>",
                f"              <strong>{item['phrase']}</strong>",
                f"              <span class=\"register-tag\">{item['register']}</span>",
                "            </div>",
            ]
        )
        if item["note"]:
            parts.append(f"            <p>{item['note']}</p>")
        parts.append("          </article>")
    parts.append("        </div>")
    return "\n".join(parts)


def render_neighbor_rows(model: dict[str, Any]) -> str:
    neighbors = model["page"]["neighbors"]
    rows = [
        "              <tr>",
        f"                <td>{neighbors['self']['word']}</td>",
        f"                <td>{neighbors['self']['meaning']}</td>",
        f"                <td>{neighbors['self']['use']}</td>",
        "              </tr>",
    ]
    for item in neighbors["others"]:
        rows.extend(
            [
                "              <tr>",
                f"                <td>{item['word']}</td>",
                f"                <td>{item['meaning']}</td>",
                f"                <td>{item['use']}</td>",
                "              </tr>",
            ]
        )
    return "\n".join(rows)


def render_modern_use(paragraphs: list[str]) -> str:
    return "\n".join(f"        <p>{paragraph}</p>" for paragraph in paragraphs)


def render_nav(origin: dict[str, str] | None) -> str:
    parts = [
        '    <aside class="compass" aria-label="頁內導覽">',
        "      <span>Reading Path</span>",
        '      <a href="#core">核心</a>',
        '      <a href="#definition">定義</a>',
    ]
    if origin:
        parts.append('      <a href="#origin">字源</a>')
    parts.extend(
        [
            '      <a href="#memory">記憶</a>',
            '      <a href="#usage">情境</a>',
            '      <a href="#collocations">搭配詞</a>',
            '      <a href="#neighbors">辨析</a>',
            '      <a href="#modern">現代</a>',
            '      <a href="#sources">來源</a>',
            "    </aside>",
        ]
    )
    return "\n".join(parts)


def render_page(model: dict[str, Any]) -> str:
    page = model["page"]
    origin_section = render_origin(page["origin"])
    usage_cards = render_usage_cards(page["usage"])
    collocation_cards = render_collocations(page["collocations"], model["wordLower"])
    flow_markup = render_flow(page["definition"]["flow"])
    neighbor_rows = render_neighbor_rows(model)
    modern_use = render_modern_use(page["modernUse"])
    nav_markup = render_nav(page["origin"])
    collocation_note = ""
    if page["collocations"]["note"]:
        collocation_note = f'        <p class="overlap-note">{page["collocations"]["note"]}</p>\n'

    return "\n".join(
        [
            "<!doctype html>",
            '<html lang="zh-Hant">',
            "<head>",
            '  <meta charset="utf-8">',
            '  <meta name="viewport" content="width=device-width, initial-scale=1">',
            f"  <title>{model['word']} | Daily English Vocabulary</title>",
            '  <link rel="stylesheet" href="./word-page.css">',
            "</head>",
            f'<body class="word-{model["slug"]}">',
            '  <nav class="topbar" aria-label="單字頁導覽">',
            '    <div class="topbar-inner">',
            '      <a class="brand" href="#top">Daily English Vocabulary</a>',
            '      <div class="topbar-links">',
            '        <a href="./index.html">單字庫</a>',
            "      </div>",
            "    </div>",
            "  </nav>",
            "",
            '  <header class="hero" id="top">',
            '    <div class="hero-inner">',
            "      <div>",
            f'        <p class="kicker">Word 00 / {page["partOfSpeech"]}</p>',
            f"        <h1>{model['word']}</h1>",
            '        <div class="pronunciation">',
            f'          <span class="ipa">{page["pronunciation"]}</span>',
            f'          <button class="audio-button" type="button" data-speak="{model["wordLower"]}" aria-label="播放 {model["wordLower"]} 發音">',
            '            <span aria-hidden="true">&#9658;</span>',
            '            <span data-audio-label>Listen</span>',
            "          </button>",
            "        </div>",
            f'        <p class="thesis">{page["hero"]["thesis"]}</p>',
            "      </div>",
            '      <aside class="hero-note" aria-label="詞彙資訊">',
            '        <dl class="lexical-meta" aria-label="詞彙難度與頻率">',
            "          <div>",
            "            <dt>CEFR</dt>",
            f'            <dd>{page["hero"]["cefrLevel"]}</dd>',
            "          </div>",
            "          <div>",
            "            <dt>Zipf Frequency</dt>",
            f'            <dd>{page["hero"]["zipfFrequency"]}</dd>',
            "          </div>",
            "        </dl>",
            "      </aside>",
            "    </div>",
            "  </header>",
            "",
            '  <main class="main-shell">',
            nav_markup,
            "",
            '    <article class="article">',
            '      <section class="chapter" id="core">',
            '        <div class="core-card">',
            '          <p class="section-label">Core Idea</p>',
            f'          <p>{page["coreIdea"]}</p>',
            "        </div>",
            "      </section>",
            "",
            '      <section class="chapter" id="definition">',
            '        <p class="section-label">Meaning</p>',
            "        <h2>簡短定義</h2>",
            '        <div class="definition-grid">',
            '          <div class="tile">',
            f"            <strong>{model['word']}</strong>",
            f'            <p>{page["definition"]["summary"]}</p>',
            "          </div>",
            '          <div class="tile">',
            f'            <strong>不是 {page["definition"]["contrast"]["word"]}</strong>',
            f'            <p>{page["definition"]["contrast"]["note"]}</p>',
            "          </div>",
            "        </div>",
            flow_markup,
            "      </section>",
            "",
            origin_section,
            "" if origin_section else "",
            '      <section class="chapter" id="memory">',
            '        <p class="section-label">Memory Hook</p>',
            "        <h2>記憶鉤子</h2>",
            f'        <p class="quote-line">{page["memory"]["hook"]}</p>',
            f'        <p>{page["memory"]["explanation"]}</p>',
            "      </section>",
            "",
            '      <section class="chapter" id="usage">',
            '        <p class="section-label">Usage</p>',
            "        <h2>生活與專業情境</h2>",
            usage_cards,
            "      </section>",
            "",
            '      <section class="chapter" id="collocations">',
            '        <p class="section-label">Collocations</p>',
            "        <h2>常見搭配與語域</h2>",
            collocation_note.rstrip("\n"),
            collocation_cards,
            "      </section>",
            "",
            '      <section class="chapter" id="neighbors">',
            '        <p class="section-label">Neighbors</p>',
            "        <h2>對立與鄰近概念</h2>",
            '        <div class="table-wrap">',
            "          <table>",
            "            <thead>",
            "              <tr>",
            "                <th>概念</th>",
            "                <th>核心精神</th>",
            "                <th>最自然的使用時機</th>",
            "              </tr>",
            "            </thead>",
            "            <tbody>",
            neighbor_rows,
            "            </tbody>",
            "          </table>",
            "        </div>",
            "      </section>",
            "",
            '      <section class="chapter" id="modern">',
            '        <p class="section-label">Modern Use</p>',
            "        <h2>現代延伸</h2>",
            modern_use,
            "      </section>",
            "",
            '      <section class="chapter" id="sources">',
            '        <p class="section-label">Source Notes</p>',
            "        <h2>來源備註</h2>",
            '        <div class="source-grid">',
            '          <article class="source-card">',
            "            <strong>詞典來源</strong>",
            f'            <p>{page["sources"]["dictionary"]["note"]}</p>',
            f'            <a href="{page["sources"]["dictionary"]["url"]}" target="_blank" rel="noreferrer">{page["sources"]["dictionary"]["label"]}</a>',
            "          </article>",
            '          <article class="source-card">',
            "            <strong>現代用法</strong>",
            f'            <p>{page["sources"]["modern"]["note"]}</p>',
            f'            <a href="{page["sources"]["modern"]["url"]}" target="_blank" rel="noreferrer">{page["sources"]["modern"]["label"]}</a>',
            "          </article>",
            "        </div>",
            "      </section>",
            "",
            '      <section class="chapter">',
            '        <div class="reference-box">',
            "          <div>",
            '            <p class="section-label">Reference</p>',
            "            <h2>外部參考</h2>",
            "            <p>查看詞典定義、發音與更多例句。</p>",
            "          </div>",
            f'          <a class="reference-link" href="{page["sources"]["dictionary"]["url"]}" target="_blank" rel="noreferrer">{page["sources"]["dictionary"]["label"]}</a>',
            "        </div>",
            "      </section>",
            "    </article>",
            "  </main>",
            "",
            '  <script src="./word-page.js"></script>',
            "</body>",
            "</html>",
            "",
        ]
    )


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
    model = prepare_payload(payload)
    output_path = Path(model["outputPath"])
    if output_path.exists():
        raise RenderError(f"output page already exists: {output_path.relative_to(ROOT)}")

    entry = dict(model["indexEntry"])
    entry["cefr"] = model["page"]["hero"]["cefrLevel"]
    entry["zipf"] = model["page"]["hero"]["zipfFrequency"]

    index_source = read_text(WORD_INDEX)
    rendered_page = render_page(model)
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
        description="Render a semantic word-page payload into prototypes/<word-slug>.html and append word-index.js."
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
