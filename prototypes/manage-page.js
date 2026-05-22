(function () {
  const words = Array.isArray(window.WORD_INDEX) ? window.WORD_INDEX : [];
  const backlogKey = "vocab-backlog:v1";
  const cefrLevels = ["A1", "A2", "B1", "B2", "C1", "C2"];

  const elements = {
    totalWords: document.querySelector("#total-words"),
    pendingWords: document.querySelector("#pending-words"),
    searchInput: document.querySelector("#word-search"),
    sortWords: document.querySelector("#sort-words"),
    clearSearch: document.querySelector("#clear-search"),
    searchCount: document.querySelector("#search-count"),
    wordResults: document.querySelector("#word-results")
  };

  let activeResultIndex = 0;
  let hasActiveResult = false;
  let visibleResults = [];

  function readJson(key, fallback) {
    try {
      return JSON.parse(localStorage.getItem(key)) || fallback;
    } catch {
      return fallback;
    }
  }

  function normalizeText(value) {
    return String(value || "").trim().toLowerCase();
  }

  function cefrRank(value) {
    const level = String(value || "").trim().toUpperCase();
    const rank = cefrLevels.indexOf(level);
    return rank >= 0 ? rank : cefrLevels.length;
  }

  function zipfValue(value) {
    const number = Number(value);
    return Number.isFinite(number) ? number : null;
  }

  function formatZipf(value) {
    const number = zipfValue(value);
    return number === null ? "—" : number.toFixed(2);
  }

  function compareByOrder(a, b) {
    return a.order - b.order
      || a.word.localeCompare(b.word, "en", { sensitivity: "base" });
  }

  function generatedWordKeys() {
    return new Set(
      words.map((word) => normalizeText(word.word))
    );
  }

  function pendingBacklogItems() {
    const generated = generatedWordKeys();
    const items = readJson(backlogKey, []);
    return Array.isArray(items)
      ? items.filter((item) => !generated.has(normalizeText(item.word)))
      : [];
  }

  function searchableFields(word) {
    return [
      ["word", word.word],
      ...(Array.isArray(word.tags) ? word.tags.map((tag) => ["tag", tag]) : [])
    ];
  }

  function matchesWord(word, query) {
    if (!query) return true;
    return searchableFields(word).some(([, value]) => normalizeText(value).includes(query));
  }

  function matchedFieldLabel(word, query) {
    if (!query) return "";

    const match = searchableFields(word).find(([, value]) => normalizeText(value).includes(query));
    return match ? match[0] : "";
  }

  function compareWords(a, b) {
    const sortMode = elements.sortWords ? elements.sortWords.value : "order";

    if (sortMode === "az") {
      return a.word.localeCompare(b.word, "en", { sensitivity: "base" });
    }

    if (sortMode === "length") {
      return a.word.length - b.word.length
        || a.word.localeCompare(b.word, "en", { sensitivity: "base" });
    }

    if (sortMode === "cefr") {
      return cefrRank(a.cefr) - cefrRank(b.cefr)
        || (zipfValue(b.zipf) ?? -Infinity) - (zipfValue(a.zipf) ?? -Infinity)
        || compareByOrder(a, b);
    }

    if (sortMode === "zipf") {
      const zipfA = zipfValue(a.zipf);
      const zipfB = zipfValue(b.zipf);
      if (zipfA === null && zipfB === null) return compareByOrder(a, b);
      if (zipfA === null) return 1;
      if (zipfB === null) return -1;
      return zipfB - zipfA || compareByOrder(a, b);
    }

    return compareByOrder(a, b);
  }

  function validateWordNumbers() {
    const numbers = words
      .map((word) => Number(word.order))
      .filter((number) => Number.isInteger(number));
    const unique = new Set(numbers);
    const missing = [];

    for (let index = 1; index <= numbers.length; index += 1) {
      if (!unique.has(index)) missing.push(index);
    }

    if (unique.size !== numbers.length || missing.length) {
      console.warn("WORD_INDEX order should stay contiguous from Word 01.", {
        numbers,
        missing
      });
    }
  }

  function appendHighlightedText(parent, text, query) {
    const value = String(text || "");
    const lowerValue = value.toLowerCase();
    const index = query ? lowerValue.indexOf(query) : -1;

    if (index < 0) {
      parent.append(document.createTextNode(value));
      return;
    }

    parent.append(document.createTextNode(value.slice(0, index)));

    const mark = document.createElement("mark");
    mark.textContent = value.slice(index, index + query.length);
    parent.append(mark, document.createTextNode(value.slice(index + query.length)));
  }

  function createMetric(label, value) {
    const item = document.createElement("div");
    item.className = "result-metric";

    const term = document.createElement("dt");
    term.textContent = label;

    const description = document.createElement("dd");
    description.textContent = value || "—";

    item.append(term, description);
    return item;
  }

  function createResultMetrics(word) {
    const metrics = document.createElement("dl");
    metrics.className = "result-metrics";
    metrics.setAttribute("aria-label", "詞彙難度與頻率");
    metrics.append(
      createMetric("CEFR", word.cefr),
      createMetric("ZIPF", formatZipf(word.zipf))
    );
    return metrics;
  }

  function createResultRow(word, query, index) {
    const row = document.createElement("article");
    row.className = "result-row";
    row.dataset.resultIndex = String(index);
    row.setAttribute("role", "option");
    row.setAttribute("aria-selected", "false");

    const main = document.createElement("div");
    main.className = "result-main";

    const meta = document.createElement("span");
    meta.className = "result-meta";
    meta.textContent = `Word ${String(word.order).padStart(2, "0")} / ${word.partOfSpeech}`;

    const title = document.createElement("h3");
    appendHighlightedText(title, word.word, query);

    const thesis = document.createElement("p");
    appendHighlightedText(thesis, word.thesis, query);

    const match = matchedFieldLabel(word, query);
    if (match) {
      const matchLabel = document.createElement("span");
      matchLabel.className = "result-match";
      matchLabel.textContent = `matched in ${match}`;
      main.append(meta, title, thesis, matchLabel);
    } else {
      main.append(meta, title, thesis);
    }

    const actions = document.createElement("div");
    actions.className = "result-actions";

    const open = document.createElement("a");
    open.className = "control-link";
    open.href = word.href;
    open.textContent = "開啟";
    actions.append(open);

    row.append(main, createResultMetrics(word), actions);
    return row;
  }

  function renderStats() {
    if (elements.totalWords) elements.totalWords.textContent = String(words.length);
    if (elements.pendingWords) elements.pendingWords.textContent = String(pendingBacklogItems().length);
  }

  function updateActiveResult(options = {}) {
    if (!hasActiveResult || !visibleResults.length) {
      elements.wordResults.querySelectorAll(".result-row").forEach((row) => {
        row.classList.remove("is-active");
        row.setAttribute("aria-selected", "false");
      });
      return;
    }

    activeResultIndex = Math.max(0, Math.min(activeResultIndex, visibleResults.length - 1));
    elements.wordResults.querySelectorAll(".result-row").forEach((row) => {
      const isActive = Number(row.dataset.resultIndex) === activeResultIndex;
      row.classList.toggle("is-active", isActive);
      row.setAttribute("aria-selected", String(isActive));
      if (isActive && options.scroll) row.scrollIntoView({ block: "nearest" });
    });
  }

  function renderSearch() {
    const rawQuery = elements.searchInput.value.trim();
    const query = normalizeText(rawQuery);
    visibleResults = words
      .filter((word) => matchesWord(word, query))
      .sort(compareWords);

    elements.wordResults.replaceChildren();

    if (!visibleResults.length) {
      const empty = document.createElement("p");
      empty.className = "empty-state";
      empty.textContent = "沒有符合的單字頁。可以先到陌生字清單記下，之後再生成頁面。";
      elements.wordResults.append(empty);
    } else {
      visibleResults.forEach((word, index) => {
        elements.wordResults.append(createResultRow(word, query, index));
      });
      hasActiveResult = Boolean(query) || hasActiveResult;
      updateActiveResult();
    }

    elements.searchCount.textContent = `${visibleResults.length} / ${words.length}`;
    elements.clearSearch.disabled = !query;
  }

  elements.searchInput.addEventListener("input", () => {
    activeResultIndex = 0;
    hasActiveResult = Boolean(normalizeText(elements.searchInput.value));
    renderSearch();
  });
  elements.searchInput.addEventListener("keydown", (event) => {
    if (!visibleResults.length) return;

    if (event.key === "Enter") {
      event.preventDefault();
      if (!hasActiveResult && !normalizeText(elements.searchInput.value)) return;
      window.location.href = visibleResults[activeResultIndex].href;
    } else if (event.key === "ArrowDown") {
      event.preventDefault();
      if (!hasActiveResult) {
        hasActiveResult = true;
        activeResultIndex = 0;
        updateActiveResult({ scroll: true });
        return;
      }
      hasActiveResult = true;
      activeResultIndex = (activeResultIndex + 1) % visibleResults.length;
      updateActiveResult({ scroll: true });
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      if (!hasActiveResult) {
        hasActiveResult = true;
        activeResultIndex = visibleResults.length - 1;
        updateActiveResult({ scroll: true });
        return;
      }
      hasActiveResult = true;
      activeResultIndex = (activeResultIndex - 1 + visibleResults.length) % visibleResults.length;
      updateActiveResult({ scroll: true });
    }
  });
  if (elements.sortWords) {
    elements.sortWords.addEventListener("change", () => {
      activeResultIndex = 0;
      hasActiveResult = Boolean(normalizeText(elements.searchInput.value));
      renderSearch();
    });
  }
  elements.clearSearch.addEventListener("click", () => {
    elements.searchInput.value = "";
    elements.searchInput.focus();
    activeResultIndex = 0;
    hasActiveResult = false;
    renderSearch();
  });

  window.addEventListener("pageshow", () => {
    renderStats();
    renderSearch();
  });
  window.addEventListener("storage", renderStats);

  validateWordNumbers();
  renderStats();
  renderSearch();
})();
