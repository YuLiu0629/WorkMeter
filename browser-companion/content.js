(() => {
  const BRIDGE = "http://127.0.0.1:17891/chatgpt-usage";

  function findMetadata(value) {
    if (!value) return null;
    if (Array.isArray(value)) {
      for (const item of value) {
        const found = findMetadata(item);
        if (found) return found;
      }
      return null;
    }
    if (typeof value === "object") {
      if (value.type === "conversation_detail_metadata") return value;
      for (const key of Object.keys(value)) {
        const found = findMetadata(value[key]);
        if (found) return found;
      }
    }
    return null;
  }

  function sanitize(metadata) {
    if (!metadata || metadata.type !== "conversation_detail_metadata") return null;
    return {
      type: "conversation_detail_metadata",
      blocked_features: Array.isArray(metadata.blocked_features)
        ? metadata.blocked_features.map((item) => ({
            name: item?.name ?? null,
            resets_after: item?.resets_after ?? null,
            resets_after_text: item?.resets_after_text ?? null,
            limit: typeof item?.limit === "number" ? item.limit : null,
            description: item?.description ?? null
          }))
        : [],
      model_limits: Array.isArray(metadata.model_limits)
        ? metadata.model_limits.map((item) => ({
            model_slug: item?.model_slug ?? null,
            using_default_model_slug: item?.using_default_model_slug ?? null,
            resets_after: item?.resets_after ?? null
          }))
        : [],
      limits_progress: Array.isArray(metadata.limits_progress)
        ? metadata.limits_progress.map((item) => ({
            feature_name: item?.feature_name ?? null,
            remaining: typeof item?.remaining === "number" ? item.remaining : null,
            reset_after: item?.reset_after ?? null
          }))
        : []
    };
  }

  async function forward(value) {
    try {
      const metadata = sanitize(findMetadata(value));
      if (!metadata) return;
      await fetch(BRIDGE, {
        method: "POST",
        mode: "cors",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(metadata),
        cache: "no-store",
        credentials: "omit"
      });
    } catch (_) {
      // Companion is best-effort. WorkMeter may be closed or the beta bridge may be unavailable.
    }
  }

  const originalFetch = window.fetch;
  window.fetch = async function (...args) {
    const response = await originalFetch.apply(this, args);
    try {
      const url = typeof args[0] === "string" ? args[0] : args[0]?.url;
      if (typeof url === "string" && url.includes("/backend-api/conversation/init")) {
        const clone = response.clone();
        clone.json().then(forward).catch(() => {});
      }
    } catch (_) {}
    return response;
  };

  const OriginalXHR = window.XMLHttpRequest;
  if (OriginalXHR) {
    const open = OriginalXHR.prototype.open;
    const send = OriginalXHR.prototype.send;
    OriginalXHR.prototype.open = function (method, url, ...rest) {
      this.__workmeterUrl = String(url || "");
      return open.call(this, method, url, ...rest);
    };
    OriginalXHR.prototype.send = function (...args) {
      if (this.__workmeterUrl?.includes("/backend-api/conversation/init")) {
        this.addEventListener("load", () => {
          try {
            const text = this.responseText;
            if (text) forward(JSON.parse(text));
          } catch (_) {}
        });
      }
      return send.apply(this, args);
    };
  }
})();
