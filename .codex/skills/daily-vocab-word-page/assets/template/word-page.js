document.querySelectorAll("[data-speak]").forEach((button) => {
  const label = button.querySelector("[data-audio-label]");
  const defaultText = label ? label.textContent : button.textContent;

  button.addEventListener("click", () => {
    if (!("speechSynthesis" in window)) {
      if (label) label.textContent = "Unsupported";
      return;
    }

    window.speechSynthesis.cancel();
    const utterance = new SpeechSynthesisUtterance(button.dataset.speak);
    utterance.lang = "en-US";
    utterance.rate = 0.86;
    utterance.pitch = 1;

    if (label) label.textContent = "Playing";
    utterance.onend = () => {
      if (label) label.textContent = defaultText;
    };
    utterance.onerror = () => {
      if (label) label.textContent = defaultText;
    };

    window.speechSynthesis.speak(utterance);
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
