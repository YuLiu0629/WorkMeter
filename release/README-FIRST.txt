⚡ WorkMeter

ChatGPT / Codex usage in your Mac menu bar.

安装 / Install

1. Make sure Codex CLI is installed and signed in:

   codex

   Choose: Sign in with ChatGPT

2. First launch only: right-click / Control-click

   Install WorkMeter.command

   then choose Open / 打开.

3. Look for ⚡ in the macOS menu bar.

If macOS says “unidentified developer”, do not disable Gatekeeper. Use right-click → Open once.
如果 macOS 提示“无法验证开发者”，不需要关闭 Gatekeeper；第一次右键安装器 → 打开即可。

更新 / Update

Download the new version and run the installer again. It replaces the old version automatically.
下载新版后重新运行安装器即可覆盖更新，不需要先卸载。

ChatGPT Advanced Usage (experimental) / ChatGPT 高级额度（实验）

Work/Codex limits refresh automatically through your local Codex login.
ChatGPT Pro / Reasoning, Deep Research and Image Generation counters currently use a manual, local-only import so WorkMeter does not need browser cookies or session tokens.

Open the WorkMeter menu and choose:

   Import ChatGPT usage from clipboard…

For the step-by-step guide, open:

   Open ChatGPT usage import guide

卸载 / Uninstall

Run:

   Uninstall WorkMeter.command

This removes WorkMeter, its LaunchAgent, local caches and WorkMeter logs. It does not uninstall Codex or sign you out of ChatGPT.
这会删除 WorkMeter、启动项、本地缓存和日志，但不会删除 Codex 或退出 ChatGPT。

隐私 / Privacy

WorkMeter does not need your ChatGPT password, browser cookies, browser session token, API key, or Codex auth token.
It reads Work/Codex allowance through your locally authenticated Codex. ChatGPT advanced usage is imported manually as JSON and only the parsed counters/reset times are cached locally.

WorkMeter 不需要你的 ChatGPT 密码、浏览器 cookie、session token、API key 或 Codex token。
Work/Codex 额度通过本机 Codex 获取；ChatGPT advanced usage 通过手动 JSON 导入，只在本地保存解析后的额度和 reset 时间。

Not an OpenAI product. Independent open-source project.
不是 OpenAI 官方产品。
