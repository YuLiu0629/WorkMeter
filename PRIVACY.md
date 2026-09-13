# WorkMeter Privacy / 隐私说明

**中文 | English**

WorkMeter 采用 local-first 设计。它没有自己的云端服务，也不会把你的 Work/Codex 或导入的 ChatGPT usage 数据发送给项目作者。

## 中文

### WorkMeter 会读取什么？

WorkMeter 通过你本机已登录的 Codex App Server 请求 `account/rateLimits/read`。根据账号类型和 Codex 版本，返回内容可能包括：

- allowance windows；
- reset timestamps；
- credit state；
- 可用 reset-credit 数量；
- plan type。

从 v0.3.0 起，WorkMeter 还支持**手动导入** ChatGPT Web 中 `conversation_detail_metadata` 的 JSON。WorkMeter 只解析其中支持的 usage 字段，例如：

- Pro / Reasoning limit、remaining/block state、reset time；
- Deep Research remaining、reset time；
- Image Generation remaining、reset time；
- 被限制的 Pro model 名称。

### WorkMeter 会在本机保存什么？

WorkMeter 只保存运行所需的最少数据：

- 本机 `codex` 可执行文件路径：`~/Library/Application Support/WorkMeter/codex-path.txt`
- 最后一次成功读取的 Codex usage snapshot：`~/Library/Application Support/WorkMeter/last-usage.json`
- 最后一次手动导入并解析后的 ChatGPT usage snapshot：`~/Library/Application Support/WorkMeter/chatgpt-usage.json`
- 本地诊断日志：`~/Library/Logs/WorkMeter.log`

这些 cache 只用于显示 last-known usage，不包含 ChatGPT 密码、浏览器 cookie、session token、Authorization header、API key 或 Codex authentication token。

### 网络行为

WorkMeter 没有独立的 WorkMeter 服务器。为了读取最新 Work/Codex allowance，本机 Codex 进程会按照 Codex 自己的正常认证机制与 OpenAI 通信。

ChatGPT advanced-feature usage 的 v0.3.0 实验功能是**手动导入**；WorkMeter 不会自行调用 ChatGPT Web 的私有 endpoint，也不会读取浏览器认证数据。

### 身份认证

身份认证由 Codex 自己负责。WorkMeter 不会：

- 请求或保存你的 ChatGPT 密码；
- 读取或解析 ChatGPT 浏览器 cookie；
- 读取浏览器 session token / Authorization header；
- 复制或解析 Codex authentication file；
- 要求 OpenAI API key。

### 删除本地数据

运行 Release 包中的 `Uninstall WorkMeter.command` 会删除 WorkMeter app、LaunchAgent、上述 support/cache 文件和 WorkMeter 日志。它不会卸载 Codex，也不会退出你的 ChatGPT/Codex 登录。

---

## English

WorkMeter is local-first. It has no WorkMeter-operated cloud service and does not send your Work/Codex usage or imported ChatGPT usage data to the project author.

### What WorkMeter reads

WorkMeter asks the locally authenticated Codex App Server for `account/rateLimits/read`. Depending on the account and Codex version, the response may include:

- allowance windows;
- reset timestamps;
- credit state;
- available reset-credit count;
- plan type.

Starting in v0.3.0, WorkMeter also supports **manual import** of the `conversation_detail_metadata` JSON exposed by ChatGPT Web. It parses only supported usage fields such as:

- Pro / Reasoning limit, remaining/block state, and reset time;
- Deep Research remaining count and reset time;
- Image Generation remaining count and reset time;
- names of blocked Pro models.

### What WorkMeter stores locally

WorkMeter stores only the minimum data needed to operate:

- the local `codex` executable path at `~/Library/Application Support/WorkMeter/codex-path.txt`;
- the last successful Codex usage snapshot at `~/Library/Application Support/WorkMeter/last-usage.json`;
- the last manually imported and parsed ChatGPT usage snapshot at `~/Library/Application Support/WorkMeter/chatgpt-usage.json`;
- a diagnostic log at `~/Library/Logs/WorkMeter.log`.

These caches are used only for last-known usage display. They do not contain your ChatGPT password, browser cookies, session token, Authorization header, API key, or Codex authentication token.

### Network behavior

WorkMeter does not operate a separate WorkMeter server. The local Codex process may communicate with OpenAI through Codex's normal authenticated mechanism when fresh Work/Codex allowance data is requested.

The v0.3.0 experimental ChatGPT advanced-feature feature is **manual import**. WorkMeter does not independently call ChatGPT Web private endpoints or read browser authentication data.

### Authentication

Authentication is owned by Codex. WorkMeter does not:

- request or store your ChatGPT password;
- read or parse ChatGPT browser cookies;
- read browser session tokens or Authorization headers;
- copy or parse the Codex authentication file;
- require an OpenAI API key.

### Removing local data

Running `Uninstall WorkMeter.command` from the Release bundle removes the WorkMeter app, LaunchAgent, support/cache files above, and WorkMeter logs. It does not uninstall Codex or sign you out of ChatGPT/Codex.
