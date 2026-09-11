#!/bin/bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/app.workmeter.menubar.plist"
APP="$HOME/Applications/WorkMeter.app"

say() { printf '%s\n' "$*"; }

say "⚡ WorkMeter Uninstaller"
say ""

pkill -x WorkMeter 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true
rm -f "$PLIST"
rm -rf "$APP"

say "✓ WorkMeter removed. / WorkMeter 已删除。"
say ""
say "Your Codex installation and ChatGPT login were not changed."
say "Codex 安装和 ChatGPT 登录状态没有被修改。"
say ""
read -r -p "Press Enter to close / 按回车关闭…" _ || true
