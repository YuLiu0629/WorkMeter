chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (!message || message.type !== "workmeter-usage-metadata" || !message.payload) {
    return;
  }

  fetch("http://127.0.0.1:17891/chatgpt-usage", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(message.payload),
    cache: "no-store",
    credentials: "omit"
  })
    .then((response) => sendResponse({ ok: response.ok }))
    .catch(() => sendResponse({ ok: false }));

  return true;
});
