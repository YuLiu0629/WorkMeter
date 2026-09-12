#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_APP="$SCRIPT_DIR/WorkMeter.app"
DEST_DIR="$HOME/Applications"
DEST_APP="$DEST_DIR/WorkMeter.app"
DEST_BIN="$DEST_APP/Contents/MacOS/WorkMeter"
SUPPORT_DIR="$HOME/Library/Application Support/WorkMeter"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_DIR/app.workmeter.menubar.plist"
LEGACY_PLIST="$LAUNCH_DIR/com.yu.workmeter.plist"
LABEL="app.workmeter.menubar"
DOMAIN="gui/$(id -u)"
LOG="$HOME/Library/Logs/WorkMeter.log"

say() { printf '%s\n' "$*"; }
fail() {
  say ""
  say "✗ $*"
  say ""
  say "Tip / 提示: run 'Diagnose WorkMeter.command' if the problem continues."
  say "如果问题仍然存在，请运行 Diagnose WorkMeter.command。"
  say ""
  read -r -p "Press Enter to close / 按回车关闭…" _ || true
  exit 1
}

is_installed_workmeter_running() {
  ps -axo command= | grep -F -x "$DEST_BIN" >/dev/null 2>&1
}

wait_for_workmeter() {
  local attempts=0
  while (( attempts < 20 )); do
    if is_installed_workmeter_running; then
      return 0
    fi
    sleep 0.25
    attempts=$((attempts + 1))
  done
  return 1
}

clear || true
say "⚡ WorkMeter Installer"
say "────────────────────────"
say ""

[[ "$(uname -s)" == "Darwin" ]] || fail "WorkMeter only supports macOS. / WorkMeter 仅支持 macOS。"
[[ -d "$SOURCE_APP" ]] || fail "WorkMeter.app is missing. Keep the installer and app in the same folder. / 找不到 WorkMeter.app，请不要把安装器单独移出文件夹。"
[[ -x "$SOURCE_APP/Contents/MacOS/WorkMeter" ]] || fail "WorkMeter executable is missing. Please download the release again. / WorkMeter 可执行文件缺失，请重新下载。"

if ! /usr/bin/plutil -lint "$SOURCE_APP/Contents/Info.plist" >/dev/null 2>&1; then
  fail "WorkMeter.app has an invalid Info.plist. Please download the release again. / WorkMeter.app 的 Info.plist 无效，请重新下载。"
fi

if ! /usr/bin/codesign --verify --deep --strict "$SOURCE_APP" >/dev/null 2>&1; then
  fail "WorkMeter.app failed its local integrity check. Please download the release again. / WorkMeter.app 完整性检查失败，请重新下载。"
fi

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
  say "Homebrew:  brew install --cask codex"
  say "npm:       npm install -g @openai/codex"
  say "Then run:  codex"
  fail "Codex CLI was not found. / 没找到 Codex CLI。"
fi

say "✓ WorkMeter integrity check passed / 完整性检查通过"
say "✓ Codex found: $CODEX"
if "$CODEX" login status >/dev/null 2>&1; then
  say "✓ ChatGPT sign-in detected / 已检测到登录"
else
  say "! Could not verify sign-in. If usage cannot refresh later, run 'codex' and sign in."
  say "! 暂时无法确认登录状态；如果稍后无法刷新，请运行 codex 并登录。"
fi

say "✓ Installing WorkMeter… / 正在安装…"

pkill -x WorkMeter 2>/dev/null || true
launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true
launchctl unload "$LEGACY_PLIST" 2>/dev/null || true
rm -f "$LEGACY_PLIST"

mkdir -p "$DEST_DIR" "$SUPPORT_DIR" "$LAUNCH_DIR" "$(dirname "$LOG")"
rm -rf "$DEST_APP"
/usr/bin/ditto "$SOURCE_APP" "$DEST_APP"
xattr -dr com.apple.quarantine "$DEST_APP" 2>/dev/null || true
printf '%s\n' "$CODEX" > "$SUPPORT_DIR/codex-path.txt"

cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array><string>$DEST_BIN</string></array>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Interactive</string>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$PLIST" >/dev/null

# launchd is the single normal startup path. Do not also call `open`, because
# LaunchServices can race with launchd and briefly create a second menu-bar app.
if ! launchctl bootstrap "$DOMAIN" "$PLIST" 2>/dev/null; then
  launchctl load "$PLIST" 2>/dev/null || true
fi
launchctl kickstart -k "$DOMAIN/$LABEL" 2>/dev/null || true

# Give launchd up to five seconds to create the process before using one direct
# executable fallback. This removes the transient duplicate seen on slower Macs.
if ! wait_for_workmeter; then
  say "! LaunchAgent did not start WorkMeter; trying the app binary directly…"
  say "! 启动项未成功启动，正在直接启动 WorkMeter…"
  nohup "$DEST_BIN" >>"$LOG" 2>&1 </dev/null &
  wait_for_workmeter || true
fi

say ""
if is_installed_workmeter_running; then
  VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST_APP/Contents/Info.plist" 2>/dev/null || echo unknown)"
  say "✓ WorkMeter $VERSION installed and running! / 安装完成并已启动！"
  say "✓ Look for ⚡ in your Mac menu bar. / 请在 Mac 顶部菜单栏寻找 ⚡。"
else
  say "✗ WorkMeter was installed but could not start. / WorkMeter 已安装，但未能启动。"
  if [[ -f "$LOG" ]]; then
    say ""
    say "Last log lines / 最近日志："
    tail -n 10 "$LOG" || true
  fi
  fail "Please run Diagnose WorkMeter.command and share the output. / 请运行 Diagnose WorkMeter.command 并提供输出。"
fi

say ""
read -r -p "Press Enter to close / 按回车关闭…" _ || true
