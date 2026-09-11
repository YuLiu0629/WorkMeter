#!/bin/bash
set -euo pipefail

APP_NAME="WorkMeter"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SCRIPT_DIR/WorkMeter.app"
DEST_DIR="$HOME/Applications"
DEST_APP="$DEST_DIR/WorkMeter.app"
SUPPORT_DIR="$HOME/Library/Application Support/WorkMeter"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_DIR/app.workmeter.menubar.plist"
LEGACY_PLIST="$LAUNCH_DIR/com.yu.workmeter.plist"

say() { printf '%s\n' "$*"; }
fail() { say ""; say "✗ $*"; say ""; read -r -p "Press Enter to close / 按回车关闭…" _ || true; exit 1; }

clear || true
say "⚡ WorkMeter Installer"
say "────────────────────────"
say ""

[[ "$(uname -s)" == "Darwin" ]] || fail "WorkMeter only supports macOS. / WorkMeter 仅支持 macOS。"
[[ -d "$SOURCE_APP" ]] || fail "WorkMeter.app is missing. Please keep the installer and app in the same folder. / 找不到 WorkMeter.app，请不要把安装器单独移出文件夹。"

CODEX=""
if command -v codex >/dev/null 2>&1; then
  CODEX="$(command -v codex)"
else
  for candidate in /opt/homebrew/bin/codex /usr/local/bin/codex "$HOME/.local/bin/codex" "$HOME/.npm-global/bin/codex"; do
    if [[ -x "$candidate" ]]; then CODEX="$candidate"; break; fi
  done
fi

if [[ -z "$CODEX" ]]; then
  say "Codex CLI is required before WorkMeter can read your allowance."
  say "WorkMeter 需要先安装 Codex CLI 才能读取额度。"
  say ""
  say "Install Codex, run 'codex', and choose Sign in with ChatGPT."
  say "安装后运行 codex，并选择 Sign in with ChatGPT。"
  say ""
  say "Homebrew:  brew install --cask codex"
  say "npm:       npm install -g @openai/codex"
  fail "Codex CLI was not found. / 没找到 Codex CLI。"
fi

say "✓ Codex found / 已找到 Codex"
if "$CODEX" login status >/dev/null 2>&1; then
  say "✓ ChatGPT sign-in detected / 已检测到登录"
else
  say "! Could not verify sign-in. If WorkMeter cannot refresh, run 'codex' and sign in."
  say "! 暂时无法确认登录状态；如果稍后无法刷新，请运行 codex 并登录。"
fi

say "✓ Installing WorkMeter… / 正在安装…"

pkill -x WorkMeter 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true
launchctl unload "$LEGACY_PLIST" 2>/dev/null || true
rm -f "$LEGACY_PLIST"

mkdir -p "$DEST_DIR" "$SUPPORT_DIR" "$LAUNCH_DIR"
rm -rf "$DEST_APP"
ditto "$SOURCE_APP" "$DEST_APP"
printf '%s\n' "$CODEX" > "$SUPPORT_DIR/codex-path.txt"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>app.workmeter.menubar</string>
  <key>ProgramArguments</key>
  <array><string>$DEST_APP/Contents/MacOS/WorkMeter</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PLIST

launchctl load "$PLIST" 2>/dev/null || true
open "$DEST_APP" || true
sleep 1

say ""
if pgrep -x WorkMeter >/dev/null 2>&1; then
  say "✓ WorkMeter installed and running! / 安装完成并已启动！"
else
  say "✓ WorkMeter installed. / 安装完成。"
  say ""
  say "If macOS blocks the app, open ~/Applications, Control-click WorkMeter, then choose Open once."
  say "如果 macOS 拦截应用，请打开 ~/Applications，右键 WorkMeter → 打开，一次即可。"
fi
say ""
say "Look for ⚡ in your Mac menu bar. / 请在 Mac 顶部菜单栏寻找 ⚡。"
say ""
read -r -p "Press Enter to close / 按回车关闭…" _ || true
