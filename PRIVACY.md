# WorkMeter Privacy / 隐私说明

**中文 | English**

WorkMeter 采用 local-first 设计。它没有自己的云端服务，也不会把你的 Work/Codex usage 数据发送给项目作者。

## 中文

### WorkMeter 会读取什么？

WorkMeter 通过你本机已登录的 Codex App Server 请求 `account/rateLimits/read`。根据账号类型和 Codex 版本，返回内容可能包括：

- allowance windows；
- reset timestamps；
- credit state；
- 可用 reset-credit 数量；
- plan type。

### WorkMeter 会在本机保存什么？

WorkMeter 只保存运行所需的最少数据：

- 本机 `codex` 可执行文件路径：`~/Library/Application Support/WorkMeter/codex-path.txt`
- 最后一次成功读取的 usage snapshot：`~/Library/Application Support/WorkMeter/last-usage.json`
- 本地诊断日志：`~/Library/Logs/WorkMeter.log`

`last-usage.json` 用于断网或 OpenAI 暂时不可达时显示 **last known usage**。其中只包含类似 allowance 百分比、reset 时间、credits/reset 数量、plan type 和最后更新时间的数据，不包含 ChatGPT 密码、浏览器 cookie、API key 或 Codex authentication token。

### 网络行为

WorkMeter 没有独立的 WorkMeter 服务器。为了读取最新 allowance，本机 Codex 进程会按照 Codex 自己的正常认证机制与 OpenAI 通信。

### 身份认证

身份认证由 Codex 自己负责。WorkMeter 不会：

- 请求或保存你的 ChatGPT 密码；
- 读取或解析 ChatGPT 浏览器 cookie；
- 复制或解析 Codex authentication file；
- 要求 OpenAI API key。

### 删除本地数据

运行 Release 包中的 `Uninstall WorkMeter.command` 会删除 WorkMeter app、LaunchAgent、上述 support/cache 文件和 WorkMeter 日志。它不会卸载 Codex，也不会退出你的 ChatGPT/Codex 登录。

---

## English

WorkMeter is local-first. It has no WorkMeter-operated cloud service and does not send your Work/Codex usage data to the project author.

### What WorkMeter reads

WorkMeter asks the locally authenticated Codex App Server for `account/rateLimits/read`. Depending on the account and Codex version, the response may include:

- allowance windows;
- reset timestamps;
- credit state;
- available reset-credit count;
- plan type.

### What WorkMeter stores locally

WorkMeter stores only the minimum data needed to operate:

- the local `codex` executable path at `~/Library/Application Support/WorkMeter/codex-path.txt`;
- the last successful usage snapshot at `~/Library/Application Support/WorkMeter/last-usage.json`;
- a diagnostic log at `~/Library/Logs/WorkMeter.log`.

`last-usage.json` is used to show **last known usage** when the Mac is offline or OpenAI is temporarily unreachable. It contains only fields such as allowance percentages, reset times, credits/reset counts, plan type, and the last-confirmed timestamp. It does not contain your ChatGPT password, browser cookies, API key, or Codex authentication token.

### Network behavior

WorkMeter does not operate a separate WorkMeter server. The local Codex process may communicate with OpenAI through Codex's normal authenticated mechanism when fresh allowance data is requested.

### Authentication

Authentication is owned by Codex. WorkMeter does not:

- request or store your ChatGPT password;
- read or parse ChatGPT browser cookies;
- copy or parse the Codex authentication file;
- require an OpenAI API key.

### Removing local data

Running `Uninstall WorkMeter.command` from the Release bundle removes the WorkMeter app, LaunchAgent, support/cache files above, and WorkMeter logs. It does not uninstall Codex or sign you out of ChatGPT/Codex.
