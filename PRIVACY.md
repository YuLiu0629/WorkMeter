# WorkMeter Privacy / 隐私说明

**中文 | English**

WorkMeter is intentionally local-first. / WorkMeter 采用 local-first 设计。

---

## 中文

### WorkMeter 会读取什么？

WorkMeter 会向你本机已经安装的 Codex App Server 请求 `account/rateLimits/read` 返回的账号 rate-limit snapshot。

根据账号类型和 Codex 版本，其中可能包括：

- allowance windows；
- reset timestamps；
- credit state；
- 可用 reset-credit 数量；
- plan type。

### WorkMeter 会在磁盘上保存什么？

WorkMeter 只保存：

- 本机 `codex` 可执行文件的路径；
- 本地诊断日志，包括启动、刷新成功或刷新错误信息。

WorkMeter 不会主动把返回的 allowance snapshot 持久化保存到磁盘。

### 网络行为

WorkMeter 本身没有独立的远程 WorkMeter 服务，也不会把你的 usage 数据发送到作者运营的服务器。

为了读取账号 allowance，本机 Codex 进程可能会按照 Codex 自己的正常认证和运行机制与 OpenAI 通信。

### 身份认证

身份认证由 Codex 自己负责。

WorkMeter 不会：

- 请求或保存你的 ChatGPT 密码；
- 读取或解析 ChatGPT 浏览器 cookie；
- 复制或解析你的 Codex authentication file；
- 要求 OpenAI API key。

### 日志

诊断日志位于：

```text
~/Library/Logs/WorkMeter.log
```

如果你要把日志发到 GitHub Issue，请先检查内容并确认没有你不希望公开的信息。

### 删除本地数据

运行 `uninstall.sh` 或双击 `Uninstall WorkMeter.command` 可以移除 WorkMeter 应用及其启动配置。

---

## English

### What WorkMeter reads

WorkMeter asks the locally installed Codex App Server for the account rate-limit snapshot exposed by `account/rateLimits/read`.

Depending on the account and installed Codex version, this may include:

- allowance windows;
- reset timestamps;
- credit state;
- available reset-credit count;
- plan type.

### What WorkMeter stores

WorkMeter stores only:

- the filesystem path to the local `codex` executable;
- a local diagnostic log containing startup, refresh-success, or refresh-error messages.

WorkMeter does not intentionally persist the returned allowance snapshot to disk.

### Network behavior

WorkMeter does not operate a separate remote WorkMeter service and does not send your usage data to a server operated by the author.

The local Codex process may communicate with OpenAI as part of its normal authenticated operation when retrieving account allowance information.

### Authentication

Authentication is owned by Codex.

WorkMeter does not:

- request or store your ChatGPT password;
- read or parse ChatGPT browser cookies;
- copy or parse your Codex authentication file;
- require an OpenAI API key.

### Logs

The diagnostic log is stored at:

```text
~/Library/Logs/WorkMeter.log
```

Before posting logs in a GitHub Issue, review them and remove anything you do not want to share publicly.

### Removing local data

Run `uninstall.sh` or double-click `Uninstall WorkMeter.command` to remove the WorkMeter app and launch configuration.
