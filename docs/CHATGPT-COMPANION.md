# WorkMeter ChatGPT Browser Companion (beta)

This beta helper lets WorkMeter update ChatGPT advanced-feature usage automatically while ChatGPT Web is open.

## Privacy model

The companion does **not** read or export browser cookies, Authorization headers, passwords, API keys, or your ChatGPT session token.

It observes the `conversation/init` response already delivered to the ChatGPT page, extracts only these usage fields, and sends that sanitized object to WorkMeter on your own Mac through `127.0.0.1:17891`:

- `blocked_features`
- `model_limits`
- `limits_progress`

The local WorkMeter app accepts only this usage payload and stores the parsed counters/reset times in `~/Library/Application Support/WorkMeter/chatgpt-usage.json`.

## Install the beta companion in Chrome

1. Download or clone the `experimental/chatgpt-usage-v0.3` branch.
2. Open `chrome://extensions`.
3. Enable **Developer mode**.
4. Click **Load unpacked**.
5. Select the `browser-companion` folder.
6. Keep WorkMeter beta running, then reload `https://chatgpt.com`.

When ChatGPT sends `conversation_detail_metadata`, WorkMeter should update automatically.

## What you should see

The WorkMeter menu should show:

```text
ChatGPT advanced features (beta)
Pro / Reasoning: 0 / 15 remaining • resets in ...
Deep Research: 25 remaining • resets in ...
Image generation: 118 remaining • resets in ...
Source: browser companion • automatic
Browser bridge: ready • localhost only
```

The menu bar can also include the Pro counter, for example:

```text
⚡ 5h 100% · W 77% · P 0/15
```

## Fallback

If automatic capture does not fire, manual clipboard import is still available in the WorkMeter menu.

## Beta limitations

- Chrome-family browsers only for this prototype.
- ChatGPT Web must be open/reloaded for fresh ChatGPT advanced-feature data.
- OpenAI may change the private web response shape at any time.
- This is experimental and is not part of the public stable release yet.
