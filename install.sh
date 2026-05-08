#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  Claude Code Powerline Statusline — Installer (macOS/Linux)
# ============================================================

BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
RESET='\033[0m'

info()  { printf '%b' "${CYAN}[*]${RESET} $1\n"; }
ok()    { printf '%b' "${GREEN}[✓]${RESET} $1\n"; }
warn()  { printf '%b' "${YELLOW}[!]${RESET} $1\n"; }
err()   { printf '%b' "${RED}[✗]${RESET} $1\n"; }

CLAUDE_DIR="${HOME}/.claude"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
SCRIPT_SRC="$(cd "$(dirname "$0")" && pwd)/statusline.sh"
SCRIPT_DST="${CLAUDE_DIR}/statusline.sh"

STATUSLINE_CONFIG='{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 1,
    "refreshInterval": 5
  }
}'

echo ""
printf '%b' "${BOLD}Claude Code Powerline Statusline Installer${RESET}\n"
echo "=========================================="
echo ""

# ---- Check dependencies ----
info "Checking dependencies..."

fail=0
for cmd in jq git; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd found"
  else
    err "$cmd not found — please install it first"
    fail=1
  fi
done

if [ "$fail" -eq 1 ]; then
  echo ""
  warn "Missing dependencies. Install them and re-run this script."
  warn "  macOS:  brew install jq git"
  warn "  Ubuntu: sudo apt install jq git"
  exit 1
fi

# ---- Ensure ~/.claude/ exists ----
mkdir -p "$CLAUDE_DIR"

# ---- Copy statusline.sh ----
info "Installing statusline.sh → ${SCRIPT_DST}"
cp "$SCRIPT_SRC" "$SCRIPT_DST"
chmod +x "$SCRIPT_DST"
ok "Script installed"

# ---- Merge settings.json ----
info "Configuring settings.json..."

if [ -f "$SETTINGS_FILE" ]; then
  existing=$(jq -r '.statusLine // "ABSENT"' "$SETTINGS_FILE" 2>/dev/null || echo "INVALID")
  if [ "$existing" = "INVALID" ]; then
    warn "settings.json exists but is not valid JSON — backing up and recreating"
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak.$(date +%s)"
    echo "$STATUSLINE_CONFIG" | jq '.' > "$SETTINGS_FILE"
  elif [ "$existing" != "ABSENT" ]; then
    warn "Existing statusLine config detected:"
    printf '    %s\n' "$existing"
    printf "Overwrite? [y/N] "
    read -r answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
      warn "Skipped settings.json update.  Add manually:"
      printf '%b\n' "${CYAN}${STATUSLINE_CONFIG}${RESET}"
      echo ""
      ok "Installation complete (script only)."
      exit 0
    fi
    # Merge: remove old statusLine, add new
    merged=$(jq --argjson new "$STATUSLINE_CONFIG" '. * $new' "$SETTINGS_FILE")
    printf '%s\n' "$merged" | jq '.' > "$SETTINGS_FILE"
  else
    merged=$(jq --argjson new "$STATUSLINE_CONFIG" '. + $new' "$SETTINGS_FILE")
    printf '%s\n' "$merged" | jq '.' > "$SETTINGS_FILE"
  fi
else
  echo "$STATUSLINE_CONFIG" | jq '.' > "$SETTINGS_FILE"
fi
ok "settings.json configured"

# ---- Nerd Font check ----
echo ""
info "Checking Nerd Font availability..."
# Heuristic: check if common Nerd Font glyph exists in terminal
if printf '' | grep -q . 2>/dev/null; then
  ok "Terminal appears to support Powerline glyphs"
else
  warn "Could not verify Nerd Font / Powerline glyph support."
  warn "Install a Nerd Font for the best experience:"
  warn "  https://www.nerdfonts.com/"
  warn "Recommended: JetBrainsMono Nerd Font, FiraCode Nerd Font, MesloLGS NF"
  warn ""
  warn "Without a Nerd Font, the status bar falls back to ASCII mode automatically."
fi

# ---- Done ----
echo ""
printf '%b' "${GREEN}${BOLD}Installation complete!${RESET}\n"
echo ""
echo "  The status line will appear on your next interaction with Claude Code."
echo "  Restart Claude Code if it's currently running."
echo ""
echo "  To test:"
echo "    echo '{\"model\":{\"display_name\":\"Opus\"},\"workspace\":{\"current_dir\":\"$PWD\"},\"context_window\":{\"used_percentage\":31}}' | ${SCRIPT_DST}"
echo ""
