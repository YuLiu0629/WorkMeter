#!/bin/bash
set -u

APP="$HOME/Applications/WorkMeter.app"
PLIST="$HOME/Library/LaunchAgents/app.workmeter.menubar.plist"
LOG="$HOME/Library/Logs/WorkMeter.log"

clear || true
printf '%s\n' "⚡ WorkMeter Diagnostics"
printf '%s\n' "────────────────────────"
printf '%s\n' "Date: $(date)"
printf '%s\n' "macOS: $(sw_vers -productVersion 2>/dev/null || echo unknown)"
printf '%s\n' "Architecture: $(uname -m)"
printf '%s\n' ""

if command -v codex >/dev/null 2>&1; then
  CODEX="$(command -v codex)"
  printf '%s\n' "Codex path: $CODEX"
  printf '%s\n' "Codex version: $($CODEX --version 2>&1 | head -n 1)"
  printf '%s\n' "Codex login: $($CODEX login status 2>&1 | head -n 1)"
else
  printf '%s\n' "Codex: not found in shell PATH"
fi

printf '%s\n' ""
if [[ -d "$APP" ]]; then
  printf '%s\n' "WorkMeter app: installed"
  if [[ -f "$APP/Contents/Info.plist" ]]; then
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo unknown)"
    printf '%s\n' "WorkMeter version: $VERSION"
  fi
else
  printf '%s\n' "WorkMeter app: not installed"
fi

if pgrep -x WorkMeter >/dev/null 2>&1; then
  printf '%s\n' "WorkMeter process: running"
else
  printf '%s\n' "WorkMeter process: not running"
fi

if [[ -f "$PLIST" ]]; then
  printf '%s\n' "LaunchAgent: installed"
else
  printf '%s\n' "LaunchAgent: missing"
fi

printf '%s\n' ""
printf '%s\n' "Last 30 log lines:"
printf '%s\n' "────────────────────────"
if [[ -f "$LOG" ]]; then
  tail -n 30 "$LOG"
else
  printf '%s\n' "No WorkMeter log found."
fi

printf '%s\n' ""
printf '%s\n' "Before posting this output publicly, review it for anything you do not want to share."
printf '%s\n' "公开诊断信息前，请先检查是否包含你不希望公开的内容。"
printf '%s\n' ""
read -r -p "Press Enter to close / 按回车关闭…" _ || true
