# ChatGPT advanced usage import

WorkMeter v0.3 adds an **experimental, privacy-preserving manual import** for ChatGPT advanced-feature usage.

It can display usage fields that ChatGPT Web exposes in `conversation_detail_metadata`, including:

- Pro / Reasoning allowance and reset time;
- Deep Research remaining count and reset time;
- Image Generation remaining count and reset time;
- blocked Pro-model count.

## Why is this manual?

ChatGPT Web currently exposes these counters through its authenticated web session. WorkMeter deliberately **does not read browser cookies, session tokens, passwords, or private browser storage**.

Until OpenAI exposes the same information through a supported local/API interface, WorkMeter keeps this feature manual rather than scraping your browser session.

## Import in about 30 seconds

1. Open ChatGPT Web in your browser.
2. Open Developer Tools → **Network**.
3. Reload ChatGPT.
4. Find the request named `init` whose URL contains:

   ```text
   /backend-api/conversation/init
   ```

5. Open **Response** and locate the object whose type is:

   ```json
   "type": "conversation_detail_metadata"
   ```

6. Copy that whole JSON object.
7. Click the WorkMeter menu-bar item → **Import ChatGPT usage from clipboard…**

WorkMeter parses only supported counters and reset timestamps, then stores the parsed snapshot locally at:

```text
~/Library/Application Support/WorkMeter/chatgpt-usage.json
```

You can remove it at any time with **Clear imported ChatGPT usage** or by running the WorkMeter uninstaller.

## Example

ChatGPT may return metadata similar to:

```json
{
  "type": "conversation_detail_metadata",
  "blocked_features": [
    {
      "name": "reason",
      "resets_after": "2026-10-12T08:06:17.773095+00:00",
      "limit": 15.0
    }
  ],
  "model_limits": [
    {"model_slug": "gpt-5-6-pro"}
  ],
  "limits_progress": [
    {
      "feature_name": "deep_research",
      "remaining": 25,
      "reset_after": "2026-10-13T14:57:36.748648+00:00"
    },
    {
      "feature_name": "image_gen",
      "remaining": 118,
      "reset_after": "2026-09-14T13:21:35.748675+00:00"
    }
  ]
}
```

WorkMeter will then show values such as:

```text
Pro / Reasoning: 0 / 15 remaining · resets in 28d 7h
Deep Research: 25 remaining · resets in 29d 13h
Image generation: 118 remaining · resets in 15h 22m
```

## Important limitations

- This is **not live automatic tracking**. Re-import when you want fresh ChatGPT advanced-feature data.
- A feature may be absent from `limits_progress` until ChatGPT chooses to expose it.
- WorkMeter never invents a percentage or remaining count that is not present in the imported metadata.
- The ChatGPT web response format is internal and may change. If import stops working, please open a GitHub issue with a redacted sample response.

## Privacy

Do **not** copy or share Request Headers, cookies, Authorization headers, or session tokens.

WorkMeter only needs the `conversation_detail_metadata` response object. It does not need your ChatGPT password or browser authentication data.
