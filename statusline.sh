#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"

# ===== ANSI color definitions (TrueColor, from spec §4) =====
RESET='\033[0m'
FG_LIGHT='\033[38;2;255;243;222m'   # #FFF3DE – main text on colored BG
FG_GRAY='\033[38;2;122;122;122m'     # #7A7A7A – secondary text

BG_MODEL='\033[48;2;194;91;30m'      # #C25B1E – warm orange
BG_CTX='\033[48;2;143;138;41m'       # #8F8A29 – olive
BG_CTX_WARN='\033[48;2;199;144;45m'  # #C7902D – amber (60-84%)
BG_CTX_DANGER='\033[48;2;182;90;58m' # #B65A3A – rust (>=85%)
BG_DIR='\033[48;2;199;144;45m'       # #C7902D – ochre
BG_GIT='\033[48;2;80;114;116m'       # #507274 – teal
BG_STYLE='\033[48;2;122;98;51m'      # #7A6233 – dark brown
BG_THINK='\033[48;2;108;173;115m'    # #6CAD73 – soft green

# Foreground colors for Powerline separator transitions
C_MODEL='\033[38;2;194;91;30m'
C_CTX='\033[38;2;143;138;41m'
C_CTX_WARN='\033[38;2;199;144;45m'
C_CTX_DANGER='\033[38;2;182;90;58m'
C_DIR='\033[38;2;199;144;45m'
C_GIT='\033[38;2;80;114;116m'
C_STYLE='\033[38;2;122;98;51m'
C_THINK='\033[38;2;108;173;115m'

# ===== Terminal detection (§3) =====
cols="${COLUMNS:-$(tput cols 2>/dev/null || echo 120)}"

# Detect Powerline / Nerd Font support
use_powerline=true
if command -v locale >/dev/null 2>&1; then
  charset=$(locale charmap 2>/dev/null || echo "")
  if [ "$charset" != "UTF-8" ] && [ -n "$charset" ]; then
    use_powerline=false
  fi
fi

# Powerline glyphs
PL_LEFT=''
PL_RIGHT=''
PL_SEP=''
FILL_DOT='●'
EMPTY_DOT='○'

# ASCII fallback
if ! $use_powerline; then
  PL_LEFT='['
  PL_RIGHT=']'
  PL_SEP='|'
  FILL_DOT='#'
  EMPTY_DOT='-'
fi

# ===== JSON parsing (§2, §8) — single jq call =====
{
  read -r model
  read -r dir
  read -r ctx_raw
  read -r style
  read -r effort
  read -r thinking_raw
  read -r session_id
} < <(printf '%s' "$input" | jq -r '
  (.model.display_name // "model?"),
  (.workspace.current_dir // .cwd // "."),
  (.context_window.used_percentage // 0),
  (.output_style.name // "default"),
  (.effort.level // "n/a"),
  (.thinking.enabled // false),
  (.session_id // "unknown")
' 2>/dev/null | tr -d '\r')

# ===== Field normalization (§2 fallback rules) =====
[ -z "$model" ] || [ "$model" = "null" ] && model="model?"
[ -z "$dir" ]   || [ "$dir" = "null" ]   && dir="$PWD"
[ -z "$style" ] || [ "$style" = "null" ] && style="default"
[ -z "$effort" ] || [ "$effort" = "null" ] && effort="n/a"

# Context percentage → integer
ctx=$(printf '%s' "$ctx_raw" | awk '{printf "%d", $1}' 2>/dev/null || echo 0)
[ "$ctx" -lt 0 ] 2>/dev/null && ctx=0
[ "$ctx" -gt 100 ] 2>/dev/null && ctx=100

base_dir="$(basename "$dir")"

# Thinking label
if [ "$thinking_raw" = "true" ] || [ "$thinking_raw" = "enabled" ]; then
  think_label="think: $effort"
else
  think_label="think: off"
fi

# ===== Context progress bar (§2, §3) =====
filled=$((ctx / 10))
[ "$filled" -gt 10 ] && filled=10
bar=""
for i in $(seq 1 10); do
  if [ "$i" -le "$filled" ]; then bar="${bar}${FILL_DOT}"; else bar="${bar}${EMPTY_DOT}"; fi
done

# ===== Context color by threshold (§4) =====
BG_CTX_ACTIVE="$BG_CTX"
C_CTX_ACTIVE="$C_CTX"
if [ "$ctx" -ge 85 ]; then
  BG_CTX_ACTIVE="$BG_CTX_DANGER"
  C_CTX_ACTIVE="$C_CTX_DANGER"
elif [ "$ctx" -ge 60 ]; then
  BG_CTX_ACTIVE="$BG_CTX_WARN"
  C_CTX_ACTIVE="$C_CTX_WARN"
fi

# ===== Git segment with session-keyed cache (§2) =====
CACHE_FILE="/tmp/statusline-git-${session_id}"
CACHE_MAX_AGE=5

cache_is_stale() {
  [ ! -f "$CACHE_FILE" ] && return 0
  local now mtime
  now=$(date +%s)
  mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  [ $((now - mtime)) -gt "$CACHE_MAX_AGE" ]
}

if cache_is_stale; then
  branch=""
  git_mark=""
  if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    branch=$(git -C "$dir" branch --show-current 2>/dev/null || echo "")
    [ -z "$branch" ] && branch="detached"
    if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
      git_mark="±"
    else
      git_mark="✓"
    fi
  fi
  printf '%s\n%s\n' "${branch:- }" "${git_mark:- }" > "$CACHE_FILE"
else
  branch=$(sed -n '1p' "$CACHE_FILE" 2>/dev/null || echo "")
  git_mark=$(sed -n '2p' "$CACHE_FILE" 2>/dev/null || echo "")
  [ "$branch" = " " ] && branch=""
  [ "$git_mark" = " " ] && git_mark=""
fi

# ===== Render: two-line Powerline (§1, §5) =====
# Line 1: Model → Dir → (Git) → Style → Think
# Line 2: Context% + progress bar

build_powerline() {
  if [ -n "$branch" ]; then
    printf '%b' \
      "${C_MODEL}${PL_LEFT}${BG_MODEL}${FG_LIGHT} ${model} " \
      "${C_MODEL}${BG_DIR}${PL_SEP}${FG_LIGHT}${BG_DIR} ${base_dir} " \
      "${C_DIR}${BG_GIT}${PL_SEP}${FG_LIGHT}${BG_GIT} ${branch} ${git_mark} " \
      "${C_GIT}${BG_STYLE}${PL_SEP}${FG_LIGHT}${BG_STYLE} style: ${style} " \
      "${C_STYLE}${BG_THINK}${PL_SEP}${FG_LIGHT}${BG_THINK} ${think_label} " \
      "${C_THINK}${RESET}${C_THINK}${PL_RIGHT}${RESET}\n"
  else
    printf '%b' \
      "${C_MODEL}${PL_LEFT}${BG_MODEL}${FG_LIGHT} ${model} " \
      "${C_MODEL}${BG_DIR}${PL_SEP}${FG_LIGHT}${BG_DIR} ${base_dir} " \
      "${C_DIR}${BG_STYLE}${PL_SEP}${FG_LIGHT}${BG_STYLE} style: ${style} " \
      "${C_STYLE}${BG_THINK}${PL_SEP}${FG_LIGHT}${BG_THINK} ${think_label} " \
      "${C_THINK}${RESET}${C_THINK}${PL_RIGHT}${RESET}\n"
  fi
  printf '%b' \
    "${FG_GRAY}  ▸ Context  ${C_CTX_ACTIVE}${bar} ${ctx}%${FG_GRAY}  ↻ $(date +%H:%M:%S)${RESET}\n"
}

build_ascii() {
  if [ -n "$branch" ]; then
    printf '%b' \
      "${BG_MODEL}${FG_LIGHT} ${model} ${RESET} " \
      "${BG_DIR}${FG_LIGHT} ${base_dir} ${RESET} " \
      "${BG_GIT}${FG_LIGHT} ${branch} ${git_mark} ${RESET} " \
      "${BG_STYLE}${FG_LIGHT} style: ${style} ${RESET} " \
      "${BG_THINK}${FG_LIGHT} ${think_label} ${RESET}\n"
  else
    printf '%b' \
      "${BG_MODEL}${FG_LIGHT} ${model} ${RESET} " \
      "${BG_DIR}${FG_LIGHT} ${base_dir} ${RESET} " \
      "${BG_STYLE}${FG_LIGHT} style: ${style} ${RESET} " \
      "${BG_THINK}${FG_LIGHT} ${think_label} ${RESET}\n"
  fi
  printf '%b' \
    "${FG_GRAY}  ▸ Context  ${C_CTX_ACTIVE}${bar} ${ctx}%${FG_GRAY}  ↻ $(date +%H:%M:%S)${RESET}\n"
}

if $use_powerline; then
  build_powerline
else
  build_ascii
fi
