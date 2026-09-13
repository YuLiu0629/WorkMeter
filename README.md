# ⚡ WorkMeter

**ChatGPT / Codex 额度，直接显示在 Mac 菜单栏。**  
**See ChatGPT / Codex usage directly from the macOS menu bar.**

```text
⚡ 5h 72% · W 84% · P 9/15
```

不用反复打开 Settings。点一下可以看 Codex 5-hour / weekly、reset countdown、credits、free resets，以及实验性的 ChatGPT Pro / Reasoning、Deep Research、Image Generation usage。

## 下载 / Download

👉 **[下载最新版 WorkMeter for Mac](https://github.com/YuLiu0629/WorkMeter/releases/latest)**

macOS 11+ · Intel & Apple Silicon · 免费开源 / Free & open source

## 安装：3 步

**已经装好 Codex CLI？直接从第 2 步开始。**

1. 安装 Codex CLI 并运行 `codex`，选择 **Sign in with ChatGPT**。

   ```bash
   brew install --cask codex
   codex
   ```

2. 下载 `WorkMeter-mac.zip` 并解压。

3. **第一次右键 / Control-click `Install WorkMeter.command` → Open。** 完成后顶部菜单栏会出现 `⚡`。

> WorkMeter 当前没有 Apple Developer ID notarization，所以第一次从网络下载后 macOS 可能提示 unidentified developer。不要关闭 Gatekeeper；右键 → Open 一次即可。

以后更新：**下载新版 → 再运行 Installer**，会直接覆盖旧版本。

## 自动显示：Work / Codex

WorkMeter 会通过本机已经登录的 Codex 自动刷新：

```text
5-hour: 72% left · resets in 3h 18m
Weekly: 84% left · resets in 6d 20h
Credits: 0
Free resets: 1
```

断网时继续显示最后一次确认的数据，并加 `⚠`；恢复联网后自动刷新。

## v0.3 实验功能：ChatGPT advanced usage

ChatGPT Web 还会暴露一些独立额度，例如：

```text
Pro / Reasoning: 0 / 15 remaining · resets in 28d
Deep Research: 25 remaining · resets in 29d
Image generation: 118 remaining · resets in 15h
```

OpenAI 目前没有通过 WorkMeter 使用的 Codex App Server 暴露这些 ChatGPT Web counters。为了不读取你的 browser cookies / session token，**v0.3 使用手动、local-only import**：

1. ChatGPT Web → DevTools → Network。
2. Reload 页面，找到 `/backend-api/conversation/init`。
3. 在 Response 中复制完整的 `conversation_detail_metadata` JSON object。
4. 点击 WorkMeter → **Import ChatGPT usage from clipboard…**。

详细步骤：[`docs/CHATGPT-USAGE.md`](docs/CHATGPT-USAGE.md)

> 这部分目前不是自动 live tracking。重新 import 才会更新 ChatGPT advanced-feature counters。WorkMeter 不会伪造没有暴露出来的 remaining percentage/count。

## Privacy / 隐私

WorkMeter 采用 local-first 设计：

- 不需要 ChatGPT 密码；
- 不读取 browser cookies 或 session token；
- 不需要 API key；
- 不读取/复制 Codex authentication file；
- usage cache 只保存在你的 Mac；
- 没有 WorkMeter 自己的云服务器。

详见 [`PRIVACY.md`](PRIVACY.md)。

> WorkMeter 是独立开源项目，不是 OpenAI 官方产品，也不隶属于或代表 OpenAI。

---

<details>
<summary><strong>FAQ / 常见问题</strong></summary>

**为什么 macOS 说 unidentified developer？**  
当前 release 没有 Developer ID signing + notarization。第一次右键 Installer → Open 即可，不需要关闭 Gatekeeper，也不需要上架 App Store。

**没网还能用吗？**  
Codex 会显示 last-known usage。ChatGPT advanced usage 本身就是手动 imported snapshot。

**要一直开着 ChatGPT 或 Codex 吗？**  
Codex 自动额度不需要。ChatGPT advanced usage import 时需要你在网页里复制一次 metadata，之后网页可以关掉。

**为什么 ChatGPT advanced usage 不是自动的？**  
因为当前数据来自 ChatGPT Web authenticated session。WorkMeter 不读取浏览器 cookie/session。等 OpenAI 提供受支持的 API/local interface 后，可以把 provider 换成自动刷新，而不需要重写 UI。

**怎么卸载？**  
运行 `Uninstall WorkMeter.command`。它会删除 WorkMeter、LaunchAgent、local caches 和日志，但不会删除 Codex 或退出 ChatGPT。

**支持什么 Mac？**  
macOS 11+，Intel (`x86_64`) 和 Apple Silicon (`arm64`)。

</details>

<details>
<summary><strong>Technical details / 技术细节</strong></summary>

Work/Codex 自动刷新使用：

```text
codex app-server --stdio
account/rateLimits/read
```

ChatGPT advanced-feature v0.3 provider 只解析用户手动复制的 `conversation_detail_metadata`，支持 `blocked_features`、`model_limits` 和 `limits_progress` 中已知字段。

本地文件：

```text
~/Library/Application Support/WorkMeter/codex-path.txt
~/Library/Application Support/WorkMeter/last-usage.json
~/Library/Application Support/WorkMeter/chatgpt-usage.json
~/Library/Logs/WorkMeter.log
```

GitHub Release 包含预编译 Universal macOS app，普通用户不需要 Swift compiler。

</details>

[`PRIVACY.md`](PRIVACY.md) · [`CHANGELOG.md`](CHANGELOG.md) · MIT License
