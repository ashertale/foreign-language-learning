let selectedEnglishVoice = null;
let speechRetryTimer = 0;
const SPEECH_IDLE_POLL_MS = 40;
const SPEECH_IDLE_MAX_POLLS = 25;

function chooseEnglishVoice() {
  if (!("speechSynthesis" in window)) return null;
  const voices = window.speechSynthesis.getVoices();
  selectedEnglishVoice = voices.find((voice) => /^en[-_]/i.test(voice.lang) && /us|english/i.test(voice.name))
    || voices.find((voice) => /^en[-_]/i.test(voice.lang))
    || null;
  return selectedEnglishVoice;
}

if ("speechSynthesis" in window) {
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
  }, SPEECH_IDLE_POLL_MS);
}

function speakEnglishText(text, onReset) {
  if (!("speechSynthesis" in window)) return;
  window.clearTimeout(speechRetryTimer);

  const synth = window.speechSynthesis;
  const beginSpeaking = () => {
    const utterance = new SpeechSynthesisUtterance(text);
    const voice = selectedEnglishVoice || chooseEnglishVoice();
    utterance.lang = selectedEnglishVoice?.lang || "en-US";
    if (voice) {
      utterance.voice = voice;
      utterance.lang = voice.lang || utterance.lang;
    }
    utterance.rate = 0.82;
    utterance.pitch = 1;
    utterance.volume = 1;

    let didReset = false;
    function resetOnce() {
      if (didReset) return;
      didReset = true;
      onReset();
    }

    const resetTimer = window.setTimeout(resetOnce, 4000);
    utterance.onend = utterance.onerror = () => {
      window.clearTimeout(resetTimer);
      resetOnce();
    };

    synth.speak(utterance);
  };

  if (synth.speaking || synth.pending) {
    synth.cancel();
    waitForSpeechIdle(SPEECH_IDLE_MAX_POLLS, beginSpeaking);
    return;
  }

  beginSpeaking();
}

document.querySelectorAll("[data-speak]").forEach((button) => {
  const label = button.querySelector("[data-audio-label]");
  const defaultText = label ? label.textContent : button.textContent;

  button.addEventListener("click", () => {
    if (!("speechSynthesis" in window)) {
      if (label) label.textContent = "Unsupported";
      return;
    }

    button.disabled = true;
    if (label) label.textContent = "Playing";

    speakEnglishText(button.dataset.speak, () => {
      button.disabled = false;
      if (label) label.textContent = defaultText;
    });
  });
});

const pageKey = `word-page-checks:${location.pathname.split("/").pop()}`;
const checks = Array.from(document.querySelectorAll("[data-check]"));

function readChecks() {
  try {
    return JSON.parse(localStorage.getItem(pageKey)) || {};
  } catch {
    return {};
  }
}

function writeChecks(state) {
  localStorage.setItem(pageKey, JSON.stringify(state));
}

if (checks.length) {
  const saved = readChecks();

  checks.forEach((input) => {
    input.checked = Boolean(saved[input.dataset.check]);
    input.addEventListener("change", () => {
      const next = readChecks();
      next[input.dataset.check] = input.checked;
      writeChecks(next);
    });
  });
}
