#!/bin/bash
set -euo pipefail

PLIST="$HOME/Library/LaunchAgents/app.workmeter.menubar.plist"
LEGACY_PLIST="$HOME/Library/LaunchAgents/com.yu.workmeter.plist"
APP="$HOME/Applications/WorkMeter.app"
SUPPORT="$HOME/Library/Application Support/WorkMeter"
LOG="$HOME/Library/Logs/WorkMeter.log"

say() { printf '%s\n' "$*"; }

clear || true
say "⚡ WorkMeter Uninstaller"
say "────────────────────────"
say ""

pkill -x WorkMeter 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true
launchctl unload "$LEGACY_PLIST" 2>/dev/null || true

rm -f "$PLIST" "$LEGACY_PLIST"
rm -rf "$APP" "$SUPPORT"
rm -f "$LOG"

say "✓ WorkMeter and its local cache/logs were removed."
say "✓ WorkMeter 及其本地缓存和日志已删除。"
say ""
say "Your Codex installation and ChatGPT login were not changed."
say "Codex 安装和 ChatGPT 登录状态没有被修改。"
say ""
read -r -p "Press Enter to close / 按回车关闭…" _ || true
