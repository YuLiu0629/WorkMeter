#!/bin/bash
set -euo pipefail

APP_NAME="WorkMeter"
APP_DIR="$HOME/Applications/WorkMeter.app"
SUPPORT_DIR="$HOME/Library/Application Support/WorkMeter"
LAUNCH_DIR="$HOME/Library/LaunchAgents"
PLIST="$LAUNCH_DIR/app.workmeter.menubar.plist"
LEGACY_PLIST="$LAUNCH_DIR/com.yu.workmeter.plist"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/WorkMeter.swift"
BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/workmeter-build.XXXXXX")"

cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

say() { printf '%s\n' "$*"; }
fail() { say ""; say "✗ $*"; say ""; exit 1; }

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "WorkMeter only runs on macOS. / WorkMeter 仅支持 macOS。"
fi

MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
if [[ "$MAJOR" -lt 11 ]]; then
  fail "macOS 11 or newer is required. / 需要 macOS 11 或更新版本。"
fi

say "⚡ WorkMeter Installer"
say "────────────────────────"
say "This will install or update WorkMeter."
say "将安装或更新 WorkMeter；旧版本无需先卸载。"
say ""

CODEX=""
if command -v codex >/dev/null 2>&1; then
  CODEX="$(command -v codex)"
else
  for candidate in /opt/homebrew/bin/codex /usr/local/bin/codex "$HOME/.local/bin/codex" "$HOME/.npm-global/bin/codex"; do
    if [[ -x "$candidate" ]]; then
      CODEX="$candidate"
      break
    fi
  done
fi

if [[ -z "$CODEX" ]]; then
  say "✗ Codex CLI was not found. / 没找到 Codex CLI。"
  say ""
  say "Install Codex first, then run this installer again."
  say "请先安装 Codex，然后重新双击安装器。"
  say ""
  say "Homebrew:  brew install --cask codex"
  say "npm:       npm install -g @openai/codex"
  say "Then run:  codex"
  exit 1
fi

say "✓ Codex: $CODEX"

if "$CODEX" login status >/dev/null 2>&1; then
  say "✓ Codex sign-in detected"
else
  say "! Could not verify Codex sign-in. / 暂时无法确认 Codex 登录状态。"
  say "  If WorkMeter cannot refresh later, run 'codex' and sign in with ChatGPT."
  say "  如果稍后无法刷新，请运行 codex 并登录 ChatGPT。"
fi

if [[ ! -f "$SOURCE" ]]; then
  fail "WorkMeter.swift is missing from this folder. / 当前文件夹缺少 WorkMeter.swift。"
fi

if ! xcrun --find swiftc >/dev/null 2>&1; then
  say ""
  say "Apple Command Line Tools are needed for this source-build installer."
  say "源码安装需要 Apple Command Line Tools。"
  say ""
  say "A macOS install window will open now. When it finishes, run this installer again."
  say "现在会打开系统安装窗口。安装完成后，请重新双击 WorkMeter 安装器。"
  xcode-select --install 2>/dev/null || true
  exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|arm64) ;;
  *) fail "Unsupported Mac architecture: $ARCH" ;;
esac

SDK="$(xcrun --sdk macosx --show-sdk-path)"
TARGET="${ARCH}-apple-macosx11.0"
BINARY="$BUILD_DIR/WorkMeter"

say "✓ Building for $ARCH…"
env -u SDKROOT -u MACOSX_DEPLOYMENT_TARGET \
  xcrun --sdk macosx swiftc \
  -sdk "$SDK" \
  -target "$TARGET" \
  -O \
  -framework AppKit \
  -framework Foundation \
  "$SOURCE" \
  -o "$BINARY"

pkill -x WorkMeter 2>/dev/null || true
launchctl unload "$PLIST" 2>/dev/null || true
launchctl unload "$LEGACY_PLIST" 2>/dev/null || true
rm -f "$LEGACY_PLIST"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$SUPPORT_DIR" "$LAUNCH_DIR"
cp "$BINARY" "$APP_DIR/Contents/MacOS/WorkMeter"
chmod +x "$APP_DIR/Contents/MacOS/WorkMeter"
printf '%s\n' "$CODEX" > "$SUPPORT_DIR/codex-path.txt"

cat > "$APP_DIR/Contents/Info.plist" <<'PLISTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>WorkMeter</string>
  <key>CFBundleIdentifier</key><string>app.workmeter.menubar</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>WorkMeter</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.2.1</string>
  <key>CFBundleVersion</key><string>6</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLISTEOF

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>app.workmeter.menubar</string>
  <key>ProgramArguments</key>
  <array><string>$APP_DIR/Contents/MacOS/WorkMeter</string></array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PLISTEOF

launchctl load "$PLIST" 2>/dev/null || true
open "$APP_DIR"

say ""
say "✓ WorkMeter 0.2.1 installed!"
say "✓ 安装完成！"
say ""
say "Look for ⚡ in your Mac menu bar."
say "请在 Mac 顶部菜单栏寻找 ⚡。"
say ""
say "You can close this window now. / 现在可以关闭这个窗口。"
