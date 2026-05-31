let selectedEnglishVoice = null;
let speechRetryTimer = 0;
const SPEECH_IDLE_POLL_MS = 40;
const SPEECH_IDLE_MAX_POLLS = 25;
const SPEECH_POST_CANCEL_DELAY_MS = 160;
const SPEECH_PRIME_DELAY_MS = 80;
const SPEECH_PRIME_STALE_MS = 45000;
const SPEECH_PRIME_TEXT = ".";
let speechPrimedAt = 0;

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

function createEnglishUtterance(text, options = {}) {
  const utterance = new SpeechSynthesisUtterance(text);
  const voice = selectedEnglishVoice || chooseEnglishVoice();
  utterance.lang = voice?.lang || "en-US";
  if (voice) {
    utterance.voice = voice;
  }
  utterance.rate = options.rate || 0.82;
  utterance.pitch = 1;
  utterance.volume = options.volume ?? 1;
  return utterance;
}

function startSpeechWithPrimer(synth, text, onStart) {
  const now = Date.now();
  const needsPrimer = !speechPrimedAt || now - speechPrimedAt > SPEECH_PRIME_STALE_MS;

  const speakActual = () => {
    speechPrimedAt = Date.now();
    onStart(createEnglishUtterance(text));
  };

  if (!needsPrimer) {
    speakActual();
    return;
  }

  const primer = createEnglishUtterance(SPEECH_PRIME_TEXT, {
    rate: 1,
    volume: 0,
  });

  let didFinishPrimer = false;
  const finishPrimer = () => {
    if (didFinishPrimer) return;
    didFinishPrimer = true;
    window.setTimeout(speakActual, SPEECH_PRIME_DELAY_MS);
  };

  const primerTimer = window.setTimeout(finishPrimer, 320);
  primer.onend = primer.onerror = () => {
    window.clearTimeout(primerTimer);
    finishPrimer();
  };

  synth.speak(primer);
}

function speakEnglishText(text, onReset) {
  if (!("speechSynthesis" in window)) return;
  window.clearTimeout(speechRetryTimer);

  const synth = window.speechSynthesis;
  const beginSpeaking = () => {
    startSpeechWithPrimer(synth, text, (utterance) => {
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

      synth.resume();
      synth.speak(utterance);
    });
  };

  if (synth.speaking || synth.pending) {
    synth.cancel();
    speechPrimedAt = 0;
    waitForSpeechIdle(SPEECH_IDLE_MAX_POLLS, () => {
      window.setTimeout(beginSpeaking, SPEECH_POST_CANCEL_DELAY_MS);
    });
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
