(function () {
  const words = Array.isArray(window.WORD_INDEX) ? window.WORD_INDEX : [];
  const backlogKey = "vocab-backlog:v1";

  const elements = {
    form: document.querySelector("#backlog-form"),
    wordInput: document.querySelector("#backlog-word"),
    noteInput: document.querySelector("#backlog-note"),
    tableBody: document.querySelector("#backlog-body"),
    summary: document.querySelector("#backlog-summary"),
    status: document.querySelector("#backlog-status")
  };

  function readJson(key, fallback) {
    try {
      return JSON.parse(localStorage.getItem(key)) || fallback;
    } catch {
      return fallback;
    }
  }

  function writeItems(items) {
    localStorage.setItem(backlogKey, JSON.stringify(items));
  }

  function normalizeText(value) {
    return String(value || "").trim().toLowerCase();
  }

  function generatedWordMap() {
    const map = new Map();

    words.forEach((word) => {
      map.set(normalizeText(word.word), word);
    });

    return map;
  }

  function backlogItemKey(item) {
    return item.backlogId || item.id;
  }

  function readItems() {
    const items = readJson(backlogKey, []);
    return Array.isArray(items) ? items : [];
  }

  function formatDate(value) {
    if (!value) return "-";

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return "-";

    return date.toLocaleDateString("zh-Hant", {
      year: "numeric",
      month: "2-digit",
      day: "2-digit"
    });
  }

  function pendingItems(items) {
    const generated = generatedWordMap();
    return items.filter((item) => !generated.has(normalizeText(item.word)));
  }

  function setStatus(message, type) {
    if (!elements.status) return;

    elements.status.textContent = message;
    elements.status.dataset.status = type || "";
  }

  function createStatusCell(item, generated) {
    const cell = document.createElement("td");
    const generatedWord = generated.get(normalizeText(item.word));

    if (generatedWord) {
      const link = document.createElement("a");
      link.href = generatedWord.href;
      link.textContent = "已有頁面";
      cell.append(link);
      return cell;
    }

    cell.textContent = "待生成";
    return cell;
  }

  function render() {
    const items = readItems();
    const generated = generatedWordMap();
    const pending = pendingItems(items);

    elements.summary.textContent = `${pending.length} pending / ${items.length} total`;
    elements.tableBody.replaceChildren();

    if (!items.length) {
      const row = document.createElement("tr");
      const cell = document.createElement("td");
      cell.colSpan = 5;
      cell.className = "table-empty";
      cell.textContent = "目前還沒有陌生字。";
      row.append(cell);
      elements.tableBody.append(row);
      return;
    }

    items.forEach((item) => {
      const row = document.createElement("tr");

      const word = document.createElement("td");
      word.className = "table-word";
      word.textContent = item.word;

      const note = document.createElement("td");
      note.textContent = item.note || "-";

      const date = document.createElement("td");
      date.textContent = formatDate(item.createdAt);

      const action = document.createElement("td");
      const remove = document.createElement("button");
      remove.className = "tiny-button";
      remove.type = "button";
      remove.textContent = "移除";
      remove.addEventListener("click", () => {
        writeItems(readItems().filter((entry) => backlogItemKey(entry) !== backlogItemKey(item)));
        render();
      });
      action.append(remove);

      row.append(word, note, createStatusCell(item, generated), date, action);
      elements.tableBody.append(row);
    });
  }

  elements.form.addEventListener("submit", (event) => {
    event.preventDefault();

    const word = elements.wordInput.value.trim();
    const note = elements.noteInput.value.trim();
    if (!word) return;

    const items = readItems();
    const generated = generatedWordMap();
    const normalizedWord = normalizeText(word);
    const existingPage = generated.get(normalizedWord);
    const exists = items.some((item) => normalizeText(item.word) === normalizedWord);

    if (existingPage) {
      setStatus(`${existingPage.word} 已有單字頁，不會加入待補清單。`, "warning");
      elements.wordInput.focus();
      return;
    }

    if (exists) {
      setStatus(`${word} 已在待補清單，不重複新增。`, "warning");
      elements.wordInput.focus();
      return;
    }

    items.unshift({
      backlogId: `backlog-${Date.now()}-${Math.random().toString(16).slice(2)}`,
      word,
      note,
      createdAt: new Date().toISOString()
    });
    writeItems(items);
    setStatus(`${word} 已加入待補清單。`, "success");

    elements.wordInput.value = "";
    elements.noteInput.value = "";
    elements.wordInput.focus();
    render();
  });

  window.addEventListener("pageshow", render);
  window.addEventListener("storage", render);
  render();
})();
