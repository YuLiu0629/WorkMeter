# WorkMeter

**中文 | English**

一个轻量、开源、local-first 的 macOS 菜单栏工具，用来查看 **ChatGPT Work / Codex** 的用量窗口和重置时间。

A lightweight, open-source, local-first macOS menu-bar utility for viewing **ChatGPT Work / Codex** usage windows and reset times.

> **非官方项目 / Independent project**  
> WorkMeter 不是 OpenAI 产品，也不代表或隶属于 OpenAI。  
> WorkMeter is not an OpenAI product and is not affiliated with or endorsed by OpenAI.

---

## 中文

### 干啥的


WorkMeter 把ChatGPT Work / Codex 的额度信息放到 Mac 顶部菜单栏里，让你不用反复打开 ChatGPT Settings。

菜单栏会显示类似：

```text
⚡ 5h 72% · W 84%
```

点击后可以查看更详细的信息，例如：

```text
Work / Codex allowance

5-hour: 72% left · resets in 3h 18m
Weekly: 84% left · resets in 6d 20h
Credits: 0
Free resets: 1
Plan: business

Last updated: 20:31
```

> 实际显示内容取决于你的账号和本机 Codex 版本能暴露哪些字段。

### 具体功能

- 直接在 macOS 菜单栏显示 5-hour allowance
- 显示 weekly allowance
- 显示两个额度窗口的 reset 倒计时
- 在 Codex 返回数据时显示 credits 状态
- 在 Codex 返回数据时显示可用 banked/full reset 数量
- 每 3 分钟自动刷新一次额度数据
- 每分钟本地更新 reset 倒计时
- 登录 Mac 后自动启动
- Intel Mac 和 Apple Silicon Mac 共用同一套源码安装包
- 不需要 OpenAI API key
- 不读取 ChatGPT 浏览器 cookie 或密码

### 系统要求

WorkMeter 当前设计支持：

- **macOS 11 Big Sur 或更新版本**
- **Intel Mac (`x86_64`)**
- **Apple Silicon (`arm64`)**

第一台确认运行的测试设备是 Intel Mac + macOS 14.6.1。其他系统组合按设计应可运行，但目前并没有逐一实机测试。如果你在其他 Mac 上成功运行或遇到问题，欢迎提交 Issue。

### 安装前准备

#### 1. 安装 Codex CLI

WorkMeter 通过你电脑上已经登录的 Codex 读取 Work/Codex allowance。

Homebrew：

```bash
brew install --cask codex
```

或者 npm：

```bash
npm install -g @openai/codex
```

然后运行：

```bash
codex
```

选择 **Sign in with ChatGPT**，并登录你希望查看额度的 ChatGPT 账号。

确认安装成功：

```bash
codex --version
```

#### 2. Apple Command Line Tools

WorkMeter 会在你的 Mac 上本地编译，因此需要 Apple 的 Swift compiler。

如果还没安装：

```bash
xcode-select --install
```

### 安装 WorkMeter

#### 方法 A：下载 ZIP

1. 在 GitHub 点击 **Code → Download ZIP**。
2. 解压文件夹。
3. 双击 **`Install WorkMeter.command`**。
4. 安装完成后，在 Mac 顶部菜单栏寻找 **`⚡ Work`**。

如果 macOS 阻止打开下载的 `.command` 文件，可以在 Finder 中按住 Control 点击文件，然后选择 **Open / 打开**。

#### 方法 B：Terminal

```bash
git clone https://github.com/YuLiu0629/WorkMeter.git
cd WorkMeter
chmod +x install.sh uninstall.sh diagnose.sh *.command
./install.sh
```

安装位置：

```text
~/Applications/WorkMeter.app
```

### 它是怎么工作的？


每次刷新时，它会短暂启动你本机已经安装并登录的：

```text
codex app-server --stdio
```

然后请求本地 Codex App Server 的：

```text
account/rateLimits/read
```

读取返回的 allowance snapshot 后关闭该本地进程。

大致流程：

```text
你的 ChatGPT / Codex 账号
          ↓
本机 Codex CLI / App Server
          ↓
account/rateLimits/read
          ↓
       WorkMeter
          ↓
     macOS menu bar
```

### 隐私

WorkMeter **不会**：

- 要求你的 ChatGPT 密码；
- 读取 ChatGPT 浏览器 cookie；
- 复制你的 Codex authentication file；
- 要求 OpenAI API key；
- 把你的 usage 数据发送到 WorkMeter 自己的服务器。

WorkMeter 只在本地保存：

- 本机 `codex` 可执行文件路径；
- 用于排查问题的本地日志。

完整说明见 [`PRIVACY.md`](PRIVACY.md)。

### 已知限制

不同账号类型和不同 Codex 版本返回的数据可能不同。例如部分 Business / Enterprise workspace credit 信息可能不会通过同一个本地接口返回。

如果某个字段没有暴露，WorkMeter 会显示 `Not exposed`，而不是推测一个数值。

由于 WorkMeter 依赖 Codex 本地 App Server，如果 OpenAI 后续调整该接口，WorkMeter 也可能需要更新。

### 排查问题

如果安装成功但菜单栏没有显示：

```bash
pgrep -fl WorkMeter
```

然后查看日志：

```bash
tail -n 30 ~/Library/Logs/WorkMeter.log
```

也可以双击：

```text
Diagnose WorkMeter.command
```

或者运行：

```bash
./diagnose.sh
```

如果仍然有问题，欢迎在 GitHub Issues 中贴出诊断结果。请先检查输出中是否包含你不希望公开的信息。

### 卸载

双击：

```text
Uninstall WorkMeter.command
```

或者运行：

```bash
./uninstall.sh
```

### 当前版本

**v0.2.0** — early public version

WorkMeter 目前仍是一个很小的个人开源项目。欢迎测试、反馈 bug 和提出功能建议。

---

## English

### Do what?

WorkMeter puts ChatGPT Work / Codex usage information in the macOS menu bar.

Typical menu-bar display:

```text
⚡ 5h 72% · W 84%
```

Clicking it can show details such as:

```text
Work / Codex allowance

5-hour: 72% left · resets in 3h 18m
Weekly: 84% left · resets in 6d 20h
Credits: 0
Free resets: 1
Plan: business

Last updated: 20:31
```

> The exact fields depend on what your account and installed Codex version expose. WorkMeter does not invent values that are not returned.

### Features

- 5-hour allowance directly in the macOS menu bar
- weekly allowance
- reset countdowns for both windows
- credits state when exposed by Codex
- banked/full reset count when exposed by Codex
- usage refresh every 3 minutes
- local countdown refresh every minute
- starts automatically at login
- supports the same source package on Intel and Apple Silicon Macs
- no OpenAI API key required
- no ChatGPT browser-cookie or password scraping

### Compatibility

Designed for:

- **macOS 11 Big Sur or newer**
- **Intel Macs (`x86_64`)**
- **Apple Silicon Macs (`arm64`)**

The first confirmed test machine was an Intel Mac running macOS 14.6.1. Other supported combinations are designed to work but have not all been individually tested. Reports from other Macs are welcome through GitHub Issues.

### Prerequisites

#### 1. Codex CLI

WorkMeter reads the Work/Codex allowance through the locally installed Codex process using the account already authenticated there.

Homebrew:

```bash
brew install --cask codex
```

or npm:

```bash
npm install -g @openai/codex
```

Then run:

```bash
codex
```

Choose **Sign in with ChatGPT** and use the ChatGPT account whose allowance you want to display.

Verify:

```bash
codex --version
```

#### 2. Apple Command Line Tools

The shareable package compiles the small native app locally, so Apple's Swift compiler is required.

If needed:

```bash
xcode-select --install
```

### Install WorkMeter

#### Option A: Download ZIP

1. On GitHub, choose **Code → Download ZIP**.
2. Unzip the folder.
3. Double-click **`Install WorkMeter.command`**.
4. After installation, look for **`⚡ Work`** on the right side of the macOS menu bar.

If macOS refuses to open the downloaded `.command` file, Control-click it in Finder and choose **Open**.

#### Option B: Terminal

```bash
git clone https://github.com/YuLiu0629/WorkMeter.git
cd WorkMeter
chmod +x install.sh uninstall.sh diagnose.sh *.command
./install.sh
```

WorkMeter installs to:

```text
~/Applications/WorkMeter.app
```

### How it works


For each usage refresh, it briefly starts the locally installed and authenticated:

```text
codex app-server --stdio
```

and requests:

```text
account/rateLimits/read
```

It reads the returned allowance snapshot and closes that local process.

Conceptually:

```text
Your ChatGPT / Codex account
            ↓
Local Codex CLI / App Server
            ↓
 account/rateLimits/read
            ↓
         WorkMeter
            ↓
       macOS menu bar
```

### Privacy

WorkMeter does **not**:

- ask for your ChatGPT password;
- read ChatGPT browser cookies;
- copy your Codex authentication file;
- require an OpenAI API key;
- send your usage data to a WorkMeter-operated server.

It stores only:

- the filesystem path to the local `codex` executable;
- a local diagnostic log for startup and refresh errors.

See [`PRIVACY.md`](PRIVACY.md) for the full summary.

### Known limitations

Different account types and Codex versions may expose different fields. Some Business / Enterprise workspace-credit information may not be available through the same local response.

When a field is unavailable, WorkMeter reports `Not exposed` rather than guessing.

Because WorkMeter depends on the local Codex App Server, future changes to that interface may require a WorkMeter update.

### Troubleshooting

If WorkMeter is installed but not visible:

```bash
pgrep -fl WorkMeter
```

Check the log:

```bash
tail -n 30 ~/Library/Logs/WorkMeter.log
```

Or double-click:

```text
Diagnose WorkMeter.command
```

or run:

```bash
./diagnose.sh
```

If the problem remains, open a GitHub Issue with the diagnostic output after checking that it does not contain anything you do not want to post publicly.

### Uninstall

Double-click:

```text
Uninstall WorkMeter.command
```

or run:

```bash
./uninstall.sh
```

### Current version

**v0.2.0** — early public version

WorkMeter is currently a small personal open-source project. Testing, bug reports, and feature suggestions are welcome.

## License

MIT License. See [`LICENSE`](LICENSE).
