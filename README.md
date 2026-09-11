# ⚡ WorkMeter

**ChatGPT Work / Codex 额度，直接显示在 Mac 菜单栏。**  
**See your ChatGPT Work / Codex allowance directly from the macOS menu bar.**

```text
⚡ 5h 72% · W 84%
```

不用反复打开 Settings。点一下还能看 reset 倒计时、credits 和可用 resets（如果你的账号返回这些信息）。

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

2. 从上面的 **Download** 下载 `WorkMeter-v0.2.1-mac.zip` 并解压。

3. 双击 **`Install WorkMeter.command`**。完成后顶部菜单栏会出现 `⚡`。

> macOS 第一次如果拦截安装器：右键 / Control-click `Install WorkMeter.command` → **打开 / Open**。

以后更新也一样：**下载新版 → 再双击 Installer**，会直接覆盖更新，不用先卸载。

## 就这些

WorkMeter 会自动刷新：

```text
5-hour: 72% left · resets in 3h 18m
Weekly: 84% left · resets in 6d 20h
Credits: 0
Free resets: 1
```

断网时会继续显示最后一次确认的数据并加 `⚠`；恢复联网后自动刷新。ChatGPT 网页和 Desktop App 都不需要保持打开。

**隐私：**不读取 ChatGPT 密码、浏览器 cookie 或 API key；usage cache 只保存在你的 Mac。详见 [`PRIVACY.md`](PRIVACY.md)。

> WorkMeter 是独立开源项目，不是 OpenAI 官方产品，也不隶属于或代表 OpenAI。

---

<details>
<summary><strong>English instructions</strong></summary>

## Install in 3 steps

**Already have Codex CLI? Start at step 2.**

1. Install Codex CLI, run `codex`, and choose **Sign in with ChatGPT**.

   ```bash
   brew install --cask codex
   codex
   ```

2. **[Download the latest release](https://github.com/YuLiu0629/WorkMeter/releases/latest)**, get `WorkMeter-v0.2.1-mac.zip`, and unzip it.

3. Double-click **`Install WorkMeter.command`**. Look for `⚡` in the macOS menu bar.

If macOS blocks the installer the first time, Control-click `Install WorkMeter.command` and choose **Open**.

Updating is the same: download the new version and run the installer again. It replaces the existing version automatically.

WorkMeter refreshes automatically, keeps the last confirmed usage visible when offline with a `⚠` indicator, and refreshes again when connectivity returns. ChatGPT Web/Desktop does not need to stay open.

**Privacy:** no ChatGPT password, browser-cookie, or API-key access. The minimal usage cache stays on your Mac. See [`PRIVACY.md`](PRIVACY.md).

WorkMeter is an independent open-source project and is not affiliated with or endorsed by OpenAI.

</details>

<details>
<summary><strong>FAQ / 常见问题</strong></summary>

**没网还能用吗？ / Does it work offline?**  
可以显示最后一次确认的数据，并用 `⚠` 标记为旧数据。没有网络时无法获取新的额度变化。

**要一直开着 ChatGPT 或 Codex 吗？ / Must ChatGPT or Codex stay open?**  
不用。Codex CLI 只需要已经安装并登录。WorkMeter 刷新时会自己调用本机 Codex。

**怎么卸载？ / How do I uninstall?**  
运行仓库里的 `Uninstall WorkMeter.command`，或删除应用后清理 LaunchAgent。Release 包也包含卸载器。

**支持什么 Mac？ / Which Macs are supported?**  
macOS 11+，Intel (`x86_64`) 和 Apple Silicon (`arm64`)。第一台确认测试机是 Intel Mac + macOS 14.6.1；欢迎其他机型反馈。

</details>

<details>
<summary><strong>Technical details / 技术细节</strong></summary>

WorkMeter 是原生 AppKit 菜单栏应用。刷新时会短暂启动本机：

```text
codex app-server --stdio
```

并读取：

```text
account/rateLimits/read
```

它不会抓取 ChatGPT Settings 网页。

v0.2.1 会把最后一次成功读取的 allowance snapshot 缓存到本机。如果缓存中的额度窗口已经超过原 reset 时间但当前仍离线，WorkMeter 会显示 `—`，不会自己假设额度已经恢复到 100%。

仓库中的 `install.sh` 是源码安装方式；GitHub Release 的 `WorkMeter-v0.2.1-mac.zip` 则包含预编译 Universal macOS app，普通用户不需要本地 Swift compiler。

</details>

[`CHANGELOG.md`](CHANGELOG.md) · [`PRIVACY.md`](PRIVACY.md) · MIT License
