# WorkMeter

**把 ChatGPT Work / Codex 额度放到 Mac 菜单栏，一眼就能看到。**  
**See your ChatGPT Work / Codex allowance at a glance from the macOS menu bar.**

```text
⚡ 5h 72% · W 84%
```

点击后还能看到：5 小时额度、weekly allowance、reset 倒计时、credits，以及可用的 banked/full reset（如果你的账号有返回这些数据）。

## 下载 & 安装

### 1. 先安装并登录 Codex CLI（只需要一次）

```bash
brew install --cask codex
codex
```

然后选择 **Sign in with ChatGPT**，登录你要查看额度的账号。

### 2. 下载 WorkMeter

👉 **[下载最新版 / Download latest release](https://github.com/YuLiu0629/WorkMeter/releases/latest)**

下载 `WorkMeter-...-mac.zip`，解压后双击：

```text
Install WorkMeter.command
```

装好以后，Mac 顶部菜单栏就会出现 `⚡ Work`。

> 如果 macOS 第一次阻止打开安装器：Control-click / 右键 `Install WorkMeter.command` → **Open / 打开**。

## 它会显示什么？

```text
⚡ 5h 72% · W 84%

5-hour: 72% left · resets in 3h 18m
Weekly: 84% left · resets in 6d 20h
Credits: 0
Free resets: 1
```

- 自动刷新额度
- 显示 5-hour / weekly reset 倒计时
- 断网时保留最后一次成功读取的数据，并显示 `⚠`
- 恢复联网后自动更新
- 不需要 ChatGPT 网页或 Desktop App 保持打开
- 支持 Intel Mac 和 Apple Silicon

## 隐私

WorkMeter 不读取你的 ChatGPT 密码、浏览器 cookie 或 API key，也不会把 usage 数据发送到 WorkMeter 自己的服务器。

它通过你本机已经登录的 Codex 获取额度信息，并在本机保存一份最小的 last-known usage cache，用于断网时显示旧数据。

详细说明见 [`PRIVACY.md`](PRIVACY.md)。

## 要求

- macOS 11 Big Sur 或更新版本
- Intel 或 Apple Silicon Mac
- Codex CLI 已安装并登录
- 获取最新额度时需要能连接 OpenAI

> WorkMeter 是独立开源项目，不是 OpenAI 官方产品，也不隶属于或代表 OpenAI。

---

<details>
<summary><strong>English</strong></summary>

## What is WorkMeter?

WorkMeter puts your ChatGPT Work / Codex allowance directly in the macOS menu bar:

```text
⚡ 5h 72% · W 84%
```

Click it to see the 5-hour allowance, weekly allowance, reset countdowns, credits, and banked/full resets when those fields are exposed for your account.

## Install

### 1. Install and sign in to Codex CLI once

```bash
brew install --cask codex
codex
```

Choose **Sign in with ChatGPT** and use the account whose allowance you want to monitor.

### 2. Download WorkMeter

👉 **[Download the latest release](https://github.com/YuLiu0629/WorkMeter/releases/latest)**

Download `WorkMeter-...-mac.zip`, unzip it, then double-click:

```text
Install WorkMeter.command
```

After installation, look for `⚡ Work` in the macOS menu bar.

If macOS blocks the installer the first time, Control-click `Install WorkMeter.command` and choose **Open**.

## Features

- 5-hour and weekly allowance at a glance
- reset countdowns
- credits and banked reset count when exposed
- automatic refresh
- offline cache with a clear `⚠` stale-data indicator
- no need to keep ChatGPT Web/Desktop open
- Intel + Apple Silicon support

## Privacy

WorkMeter does not read your ChatGPT password, browser cookies, or API key, and it does not send your usage data to a WorkMeter-operated server.

It reads allowance data through the locally authenticated Codex process and stores a minimal last-known usage cache on your Mac for offline display.

See [`PRIVACY.md`](PRIVACY.md) for details.

## Requirements

- macOS 11 Big Sur or newer
- Intel or Apple Silicon Mac
- Codex CLI installed and signed in
- network access to OpenAI for fresh usage data

WorkMeter is an independent open-source project and is not affiliated with or endorsed by OpenAI.

</details>

---

<details>
<summary><strong>Technical details / 技术细节</strong></summary>

WorkMeter briefly starts the local Codex App Server and reads:

```text
account/rateLimits/read
```

It does not scrape the ChatGPT Settings page.

If a cached allowance window has already passed its original reset time while offline, WorkMeter shows `—` instead of assuming the allowance has reset to 100%.

Developers can build from source with `install.sh`. The downloadable release is built as a Universal macOS app so normal users do not need Apple Command Line Tools just to install WorkMeter.

</details>

MIT License · [`CHANGELOG.md`](CHANGELOG.md) · [`PRIVACY.md`](PRIVACY.md)
