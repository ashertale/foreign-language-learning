(function () {
  const words = Array.isArray(window.WORD_INDEX) ? window.WORD_INDEX : [];
  const reviewKey = "vocab-review:v1";
  const sessionLimit = 8;
  const ratingDays = {
    again: 0,
    hard: 1,
    good: 3,
    easy: 7
  };

  const elements = {
    dueCount: document.querySelector("#due-count"),
    doneCount: document.querySelector("#done-count"),
    queueCount: document.querySelector("#queue-count"),
    resetSession: document.querySelector("#reset-session"),
    progressLabel: document.querySelector("#progress-label"),
    progressFill: document.querySelector("#progress-fill"),
    remainingCopy: document.querySelector("#remaining-copy"),
    front: document.querySelector("#card-front"),
    back: document.querySelector("#card-back"),
    cardMeta: document.querySelector("#card-meta"),
    cardClue: document.querySelector("#card-clue"),
    cardTags: document.querySelector("#card-tags"),
    recallInput: document.querySelector("#recall-input"),
    recallEcho: document.querySelector("#recall-echo"),
    recallGuess: document.querySelector("#recall-guess"),
    reveal: document.querySelector("#reveal-card"),
    answerMeta: document.querySelector("#answer-meta"),
    answerWord: document.querySelector("#answer-word"),
    answerThesis: document.querySelector("#answer-thesis"),
    answerCoreIdea: document.querySelector("#answer-core-idea"),
    answerChecks: document.querySelector("#answer-checks"),
    speakAnswer: document.querySelector("#speak-answer"),
    openWordPage: document.querySelector("#open-word-page"),
    undoRating: document.querySelector("#undo-rating"),
    status: document.querySelector("#review-status")
  };

  let deck = [];
  let currentIndex = 0;
  let doneCount = 0;
  let currentWord = null;
  let selectedVoice = null;
  let speechRetryTimer = 0;
  let coreIdeaRequestId = 0;
  let lastReviewAction = null;
  const speechIdlePollMs = 40;
  const speechIdleMaxPolls = 25;

  function readJson(key, fallback) {
    try {
      return JSON.parse(localStorage.getItem(key)) || fallback;
    } catch {
      return fallback;
    }
  }

  function writeReviewState(state) {
    localStorage.setItem(reviewKey, JSON.stringify(state));
  }

  function todayUtcDate() {
    const now = new Date();
    return new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
  }

  function addDays(date, days) {
    const next = new Date(date);
    next.setUTCDate(next.getUTCDate() + days);
    return next;
  }

  function toDateKey(date) {
    return date.toISOString().slice(0, 10);
  }

  function dueDateFor(word, state) {
    return state[word.id]?.due || "";
  }

  function isDue(word, state) {
    const due = dueDateFor(word, state);
    return !due || due <= toDateKey(todayUtcDate());
  }

  function wordPriority(word, state) {
    const record = state[word.id] || {};
    const reviewedAt = record.reviewedAt || "";
    const due = dueDateFor(word, state);
    const isNew = reviewedAt ? 1 : 0;
    return [
      isNew,
      due || "0000-00-00",
      -(Number(word.zipf) || 0),
      word.order || 0
    ];
  }

  function compareWords(a, b, state) {
    const priorityA = wordPriority(a, state);
    const priorityB = wordPriority(b, state);
    for (let index = 0; index < priorityA.length; index += 1) {
      if (priorityA[index] < priorityB[index]) return -1;
      if (priorityA[index] > priorityB[index]) return 1;
    }
    return a.word.localeCompare(b.word, "en", { sensitivity: "base" });
  }

  function buildDeck() {
    const state = readJson(reviewKey, {});
    const dueWords = words
      .filter((word) => isDue(word, state))
      .sort((a, b) => compareWords(a, b, state));
    return dueWords.slice(0, sessionLimit);
  }

  function countDueWords(state) {
    return words.filter((word) => isDue(word, state)).length;
  }

  function setStatus(message) {
    elements.status.textContent = message || "";
  }

  function renderUndoButton() {
    elements.undoRating.classList.toggle("is-hidden", !lastReviewAction);
  }

  function renderStats() {
    const state = readJson(reviewKey, {});
    const due = countDueWords(state);
    const remaining = Math.max(deck.length - currentIndex, 0);
    const activeCardNumber = currentWord ? currentIndex + 1 : Math.min(doneCount, deck.length);
    const progress = deck.length ? Math.min(currentIndex / deck.length, 1) * 100 : 0;

    elements.dueCount.textContent = String(due);
    elements.doneCount.textContent = String(doneCount);
    elements.queueCount.textContent = String(remaining);
    elements.progressLabel.textContent = deck.length ? `${activeCardNumber} / ${deck.length}` : "0 / 0";
    elements.progressFill.style.width = `${progress}%`;
    elements.remainingCopy.textContent = currentWord
      ? `本輪剩餘 ${remaining} 張`
      : due > 0
        ? `仍有 ${due} 張到期`
        : "今天已完成";
    elements.resetSession.disabled = !currentWord && due === 0;
    elements.resetSession.textContent = !currentWord && due > 0
      ? `開始下一輪 ${Math.min(sessionLimit, due)} 張`
      : currentWord
        ? "重排本輪牌組"
        : "今天已完成";
    renderUndoButton();
  }

  function renderTags(word) {
    elements.cardTags.replaceChildren();
    [word.partOfSpeech, word.cefr, ...(word.tags || []).slice(0, 4)].filter(Boolean).forEach((tag) => {
      const item = document.createElement("span");
      item.textContent = tag;
      elements.cardTags.append(item);
    });
  }

  function renderChecks(word) {
    elements.answerChecks.replaceChildren();
    (word.checks || []).forEach((check) => {
      const item = document.createElement("li");
      item.textContent = check.label;
      elements.answerChecks.append(item);
    });
  }

  function hideRecallEcho() {
    elements.recallEcho.classList.add("is-hidden");
    elements.recallGuess.textContent = "";
  }

  function renderRecallEcho() {
    const guess = elements.recallInput.value.trim();
    if (!guess) {
      hideRecallEcho();
      return;
    }

    elements.recallGuess.textContent = guess;
    elements.recallEcho.classList.remove("is-hidden");
  }

  async function loadCoreIdea(word) {
    const requestId = ++coreIdeaRequestId;
    elements.answerCoreIdea.textContent = "讀取核心概念中...";

    try {
      const response = await fetch(word.href, { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const html = await response.text();
      const documentFragment = new DOMParser().parseFromString(html, "text/html");
      const coreIdea = documentFragment.querySelector(".core-card p:not(.section-label)");

      if (requestId !== coreIdeaRequestId) return;
      if (!coreIdea || !coreIdea.textContent.trim()) {
        elements.answerCoreIdea.textContent = "這張單字頁還沒有可讀取的核心概念。";
        return;
      }

      elements.answerCoreIdea.innerHTML = coreIdea.innerHTML;
    } catch {
      if (requestId !== coreIdeaRequestId) return;
      elements.answerCoreIdea.textContent = "暫時讀不到單字頁的核心概念。";
    }
  }

  function showFront() {
    elements.front.classList.remove("is-hidden");
    elements.back.classList.add("is-hidden");
  }

  function showBack() {
    renderRecallEcho();
    elements.front.classList.add("is-hidden");
    elements.back.classList.remove("is-hidden");
    elements.speakAnswer.focus({ preventScroll: true });
  }

  function renderEmpty() {
    const state = readJson(reviewKey, {});
    const due = countDueWords(state);
    coreIdeaRequestId += 1;
    currentWord = null;
    elements.cardMeta.textContent = "Done";
    elements.cardClue.textContent = due > 0
      ? "本輪牌組完成。還有到期卡片，可以重開本輪牌組繼續。"
      : "今天沒有到期的卡片。可以回單字庫隨機讀一頁。";
    elements.cardTags.replaceChildren();
    elements.recallInput.value = "";
    elements.recallInput.disabled = true;
    elements.reveal.disabled = true;
    elements.answerWord.textContent = "--";
    elements.answerThesis.textContent = "";
    elements.answerCoreIdea.textContent = "";
    elements.answerChecks.replaceChildren();
    elements.speakAnswer.disabled = true;
    elements.openWordPage.href = "./index.html";
    hideRecallEcho();
    showFront();
    setStatus(due > 0 ? `本輪完成；仍有 ${due} 張到期卡片。` : "今天的複習完成。");
    renderStats();
  }

  function renderCard() {
    currentWord = deck[currentIndex] || null;
    renderStats();

    if (!currentWord) {
      renderEmpty();
      return;
    }

    elements.reveal.disabled = false;
    elements.recallInput.disabled = false;
    elements.recallInput.value = "";
    elements.speakAnswer.disabled = false;
    elements.cardMeta.textContent = `Card ${currentIndex + 1} / ${deck.length} · Word ${String(currentWord.order).padStart(2, "0")}`;
    elements.cardClue.textContent = currentWord.thesis || "想起這個單字的核心概念。";
    elements.answerMeta.textContent = `${currentWord.partOfSpeech} · CEFR ${currentWord.cefr} · Zipf ${Number(currentWord.zipf).toFixed(2)}`;
    elements.answerWord.textContent = currentWord.word;
    elements.answerThesis.textContent = currentWord.thesis || "";
    loadCoreIdea(currentWord);
    elements.openWordPage.href = currentWord.href;
    renderTags(currentWord);
    renderChecks(currentWord);
    hideRecallEcho();
    showFront();
    setStatus("先輸入或在腦中說出英文，再翻面。");
  }

  function chooseEnglishVoice() {
    if (!("speechSynthesis" in window)) return null;
    const voices = window.speechSynthesis.getVoices();
    selectedVoice = voices.find((voice) => /^en[-_]/i.test(voice.lang) && /us|english/i.test(voice.name))
      || voices.find((voice) => /^en[-_]/i.test(voice.lang))
      || null;
    return selectedVoice;
  }

  function primeVoices() {
    if (!("speechSynthesis" in window)) return;
    chooseEnglishVoice();
    window.speechSynthesis.addEventListener("voiceschanged", chooseEnglishVoice, { once: true });
  }

  function waitForSpeechIdle(remainingPolls, callback) {
    if (!("speechSynthesis" in window)) return;
    if (!window.speechSynthesis.speaking && !window.speechSynthesis.pending) {
      callback();
      return;
    }

    if (remainingPolls <= 0) {
      callback();
      return;
    }

    speechRetryTimer = window.setTimeout(() => {
      waitForSpeechIdle(remainingPolls - 1, callback);
    }, speechIdlePollMs);
  }

  function speakWord(word) {
    if (!word || !("speechSynthesis" in window)) {
      setStatus("這個瀏覽器不支援 Web Speech API。");
      return;
    }

    const originalText = elements.speakAnswer.textContent;
    elements.speakAnswer.disabled = true;
    elements.speakAnswer.textContent = "播放中";
    window.clearTimeout(speechRetryTimer);

    const synth = window.speechSynthesis;
    const beginSpeaking = () => {
      const utterance = new SpeechSynthesisUtterance(word.word);
      const voice = selectedVoice || chooseEnglishVoice();
      utterance.lang = selectedVoice?.lang || "en-US";
      if (voice) {
        utterance.voice = voice;
        utterance.lang = voice.lang || utterance.lang;
      }
      utterance.rate = 0.82;
      utterance.pitch = 1;
      utterance.volume = 1;

      let didReset = false;
      function resetButton() {
        if (didReset) return;
        didReset = true;
        elements.speakAnswer.disabled = false;
        elements.speakAnswer.textContent = originalText;
      }

      const resetTimer = window.setTimeout(resetButton, 4000);
      utterance.onend = utterance.onerror = () => {
        window.clearTimeout(resetTimer);
        resetButton();
      };
      synth.speak(utterance);
    };

    if (synth.speaking || synth.pending) {
      synth.cancel();
      waitForSpeechIdle(speechIdleMaxPolls, beginSpeaking);
      return;
    }

    beginSpeaking();
  }

  function rateCurrentWord(rating) {
    if (!currentWord) return;
    const state = readJson(reviewKey, {});
    const previous = state[currentWord.id] || {};
    const hadPreviousRecord = Object.prototype.hasOwnProperty.call(state, currentWord.id);
    const today = todayUtcDate();
    const due = toDateKey(addDays(today, ratingDays[rating] ?? 1));
    const streak = rating === "again" ? 0 : (previous.streak || 0) + 1;
    const lapses = rating === "again" ? (previous.lapses || 0) + 1 : (previous.lapses || 0);
    const ratedWord = currentWord;

    lastReviewAction = {
      word: ratedWord,
      previousRecord: previous,
      hadPreviousRecord,
      previousIndex: currentIndex,
      previousDoneCount: doneCount
    };

    state[ratedWord.id] = {
      due,
      rating,
      streak,
      lapses,
      reviewedAt: new Date().toISOString()
    };
    writeReviewState(state);

    doneCount += 1;
    currentIndex += 1;
    renderCard();
    setStatus(`${ratedWord.word} 已排到 ${due}。`);
  }

  function undoLastRating() {
    if (!lastReviewAction) return;

    const state = readJson(reviewKey, {});
    if (lastReviewAction.hadPreviousRecord) {
      state[lastReviewAction.word.id] = lastReviewAction.previousRecord;
    } else {
      delete state[lastReviewAction.word.id];
    }
    writeReviewState(state);

    currentIndex = lastReviewAction.previousIndex;
    doneCount = lastReviewAction.previousDoneCount;
    const restoredWord = lastReviewAction.word;
    lastReviewAction = null;
    renderCard();
    setStatus(`${restoredWord.word} 的上一張評分已復原。`);
  }

  function isTypingTarget(target) {
    return target instanceof HTMLElement
      && (target.matches("input, textarea, select") || target.isContentEditable);
  }

  function handleKeyboard(event) {
    if (event.altKey || event.ctrlKey || event.metaKey) return;

    const key = event.key.toLowerCase();
    const onFront = !elements.front.classList.contains("is-hidden");
    const onBack = !elements.back.classList.contains("is-hidden");

    if (isTypingTarget(event.target)) {
      if (event.target === elements.recallInput && event.key === "Enter" && currentWord && onFront) {
        event.preventDefault();
        showBack();
      }
      return;
    }

    if (currentWord && onFront && (event.key === " " || event.key === "Enter")) {
      event.preventDefault();
      showBack();
      return;
    }

    if (!onBack) return;

    if (["1", "2", "3", "4"].includes(event.key)) {
      event.preventDefault();
      const ratings = ["again", "hard", "good", "easy"];
      rateCurrentWord(ratings[Number(event.key) - 1]);
      return;
    }

    if (key === "s" && currentWord) {
      event.preventDefault();
      speakWord(currentWord);
      return;
    }

    if (key === "o" && currentWord) {
      event.preventDefault();
      elements.openWordPage.click();
      return;
    }

    if (key === "z") {
      event.preventDefault();
      undoLastRating();
    }
  }

  elements.reveal.addEventListener("click", showBack);
  elements.speakAnswer.addEventListener("click", () => speakWord(currentWord));
  elements.undoRating.addEventListener("click", undoLastRating);
  elements.resetSession.addEventListener("click", () => {
    deck = buildDeck();
    currentIndex = 0;
    doneCount = 0;
    lastReviewAction = null;
    renderCard();
  });
  document.querySelectorAll("[data-rating]").forEach((button) => {
    button.addEventListener("click", () => rateCurrentWord(button.dataset.rating));
  });
  document.addEventListener("keydown", handleKeyboard);

  primeVoices();
  deck = buildDeck();
  renderCard();
})();
