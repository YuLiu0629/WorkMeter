(() => {
  window.addEventListener("message", (event) => {
    if (event.source !== window) return;
    const message = event.data;
    if (!message || message.source !== "workmeter-chatgpt-companion") return;
    if (message.type !== "usage-metadata" || !message.payload) return;

    try {
      chrome.runtime.sendMessage({
        type: "workmeter-usage-metadata",
        payload: message.payload
      });
    } catch (_) {
      // Best-effort only.
    }
  });
})();
