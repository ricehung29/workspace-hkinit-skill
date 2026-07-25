#!/usr/bin/env bash
# workspace-init auto-updater
# Usage: curl -sL https://raw.githubusercontent.com/ricehung29/workspace-hkinit-skill/main/scripts/update.sh | bash
set -euo pipefail

REPO="https://github.com/ricehung29/workspace-hkinit-skill"
TMP="/tmp/hkinit-update"
SKILL_DIR="$HOME/.claude/skills/workspace-init"

echo "📦 workspace-init updater"
echo "   Source: $REPO"
echo "   Target: $SKILL_DIR"
echo ""

# 1. 如果冇 skill，問係咪第一次裝
if [[ ! -d "$SKILL_DIR" ]]; then
  echo "❌ workspace-init 未安裝。請先用 README 嘅安裝方法："
  echo "   curl -L -o /tmp/hkinit.zip $REPO/archive/refs/heads/main.zip"
  echo "   unzip /tmp/hkinit.zip -d /tmp/hkinit"
  echo "   cp -r /tmp/hkinit/workspace-hkinit-skill-main/skills/workspace-init ~/.claude/skills/"
  exit 1
fi

# 2. 記錄當前版本（如果有的話）
if [[ -f "$SKILL_DIR/version.txt" ]]; then
  OLD_VER=$(cat "$SKILL_DIR/version.txt")
  echo "   Current version: $OLD_VER"
else
  echo "   Current version: unknown (pre-v2.1)"
fi

# 3. Clone 最新版本
echo ""
echo "⬇️  Downloading latest..."
rm -rf "$TMP"
git clone --depth 1 "$REPO" "$TMP" 2>/dev/null || {
  # fallback: curl 如果 git 唔 work
  rm -rf "$TMP"
  curl -sL -o /tmp/hkinit-update.zip "$REPO/archive/refs/heads/main.zip"
  unzip -q /tmp/hkinit-update.zip -d "$TMP" 2>/dev/null
  TMP_SRC=$(find "$TMP" -maxdepth 1 -type d -name "workspace-hkinit-skill-*" | head -1)
  cp -r "$TMP_SRC/skills/workspace-init" "$TMP/"
  rm -rf "$TMP_SRC"
}

# 4. 更新
cp -r "$TMP/skills/workspace-init"/* "$SKILL_DIR/"
chmod +x "$SKILL_DIR/scripts/init-profile.sh" 2>/dev/null || true

# 5. 記錄版本
if [[ -f "$TMP/skills/workspace-init/version.txt" ]]; then
  NEW_VER=$(cat "$TMP/skills/workspace-init/version.txt")
  echo "$NEW_VER" > "$SKILL_DIR/version.txt"
  echo "   New version: $NEW_VER"
fi

# 6. Cleanup
rm -rf "$TMP"

echo ""
echo "✅ workspace-init updated!"
echo "   Run /init in a new conversation to load the latest."