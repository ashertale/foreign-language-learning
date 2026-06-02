let selectedEnglishVoice = null;
let speechRetryTimer = 0;
let speechStartTimer = 0;
const speechUtterancesInFlight = new Set();
const SPEECH_IDLE_POLL_MS = 40;
const SPEECH_IDLE_MAX_POLLS = 25;
const SPEECH_POST_CANCEL_DELAY_MS = 160;
const SPEECH_REPEAT_SEPARATOR = ". ";
let speechSequenceId = 0;

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

function retainUtterance(utterance) {
  speechUtterancesInFlight.add(utterance);
}

function releaseUtterance(utterance) {
  speechUtterancesInFlight.delete(utterance);
}

function createEnglishUtterance(text, options = {}) {
  const utteranceText = options.repeatForClipping ? `${text}${SPEECH_REPEAT_SEPARATOR}${text}` : text;
  const utterance = new SpeechSynthesisUtterance(utteranceText);
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

function startSpeechWithRepeat(text, sequenceId, onStart) {
  if (sequenceId !== speechSequenceId) return;
  // Some Windows/Chrome Web Speech voices clip the first phoneme after a cold
  // start. Keep playback to one normal-volume utterance, but repeat the word so
  // the second copy stays complete even if the first copy is clipped.
  onStart(createEnglishUtterance(text, { repeatForClipping: true }));
}

function speakEnglishText(text, onReset) {
  if (!("speechSynthesis" in window)) return;
  window.clearTimeout(speechRetryTimer);
  window.clearTimeout(speechStartTimer);

  const synth = window.speechSynthesis;
  const sequenceId = ++speechSequenceId;
  const beginSpeaking = () => {
    if (sequenceId !== speechSequenceId) return;
    startSpeechWithRepeat(text, sequenceId, (utterance) => {
      let didReset = false;
      function resetOnce() {
        if (didReset) return;
        didReset = true;
        onReset();
      }

      const resetTimer = window.setTimeout(resetOnce, 4000);
      utterance.onend = utterance.onerror = () => {
        releaseUtterance(utterance);
        window.clearTimeout(resetTimer);
        resetOnce();
      };

      retainUtterance(utterance);
      synth.resume();
      synth.speak(utterance);
    });
  };

  if (synth.speaking || synth.pending) {
    synth.cancel();
    speechUtterancesInFlight.clear();
    waitForSpeechIdle(SPEECH_IDLE_MAX_POLLS, () => {
      speechStartTimer = window.setTimeout(beginSpeaking, SPEECH_POST_CANCEL_DELAY_MS);
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
