[简体中文](README.zh-CN.md)
# Claude Code Powerline Statusline

A custom Powerline-style status bar for [Claude Code](https://claude.ai/code). Displays the current model, working directory, git branch and status, output style, thinking mode, context window usage, and a live clock — all in a warm retro-terminal color scheme.

![screenshot](screenshots/statusline.png)

## Layout

```text
┌─ Line 1 (Powerline) ──────────────────────────────────────────┐
│  Opus 4.7    .claude    master ✓    style: default    think: high  │
│  #C25B1E      #C7902D    #507274      #7A6233           #6CAD73    │
└────────────────────────────────────────────────────────────────┘
│  ▸ Context  ●●●○○○○○○○ 31%  ↻ 14:25:30                           │
└─ Line 2 (context bar + timestamp) ─────────────────────────────┘
```

**Segments (Line 1):** Model → Directory → Git (auto-hidden outside repos) → Output Style → Thinking

**Context bar (Line 2):** 10-cell progress bar (●/○) with color thresholds — olive below 60%, amber at 60–84%, rust-red at 85%+. Includes a live clock.

**Without a Nerd Font** installed, the bar automatically degrades to plain ASCII: `[ Opus 4.7 ] [ .claude ] ...`

## Dependencies

| Dependency | Required | Install |
|-----------|----------|---------|
| **bash** | Yes | Pre-installed on macOS/Linux; [Git for Windows](https://git-scm.com/download/win) on Windows |
| **jq** | Yes | `brew install jq` / `apt install jq` / `winget install jqlang.jq` |
| **git** | Yes | Pre-installed on most dev machines |
| **Nerd Font** | Recommended | [nerdfonts.com](https://www.nerdfonts.com/) — JetBrainsMono, FiraCode, or MesloLGS NF |

## Quick Install

### macOS / Linux

```bash
curl -fsSL https://raw.githubusercontent.com/RiverOfLogic/claude-code-statusline.git
```

Or download and run manually:

```bash
git clone https://github.com/RiverOfLogic/claude-code-statusline.git
cd claude-code-statusline
bash install.sh
```

### Windows

Download and run in **PowerShell**:

```powershell
git clone https://github.com/RiverOfLogic/claude-code-statusline.git
cd claude-code-statusline
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

> **Note:** On Windows, the status line script runs inside Git Bash. Install [Git for Windows](https://git-scm.com/download/win) first.

## What the installer does

1. Checks for `jq` and `git`
2. Copies `statusline.sh` to `~/.claude/`
3. Makes it executable
4. Adds the `statusLine` config block to `~/.claude/settings.json`
5. Warns if Nerd Font is not detected

## Manual Configuration

If you prefer to configure by hand:

1. Copy `statusline.sh` to `~/.claude/` and `chmod +x` it.
2. Add this to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 1,
    "refreshInterval": 5
  }
}
```

## Testing

```bash
echo '{
  "model": {"display_name": "Opus 4.7 (1M)"},
  "workspace": {"current_dir": "/home/me/project"},
  "context_window": {"used_percentage": 31},
  "output_style": {"name": "default"},
  "thinking": {"enabled": true},
  "effort": {"level": "high"}
}' | bash ~/.claude/statusline.sh
```

## Customization

Edit `~/.claude/statusline.sh` to change:

- **Colors** — modify the `BG_*` and `C_*` variables (TrueColor `R;G;B` values)
- **Context thresholds** — adjust the `-ge 85` / `-ge 60` limits
- **Segment order** — rearrange the `printf` lines in `build_powerline()` / `build_ascii()`
- **Add segments** — parse additional JSON fields and insert into the chain

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No status line appears | Verify script is executable (`chmod +x`), restart Claude Code |
| Shows `--` or empty values | Normal before first API response — fields populate after first message |
| Powerline glyphs show as boxes | Install a Nerd Font and configure your terminal to use it |
| `jq: command not found` | Install jq (see Dependencies above) |
| `git: command not found` | Install git (see Dependencies above) |

## Files

| File | Purpose |
|------|---------|
| `statusline.sh` | The status line script (Bash + jq) |
| `install.sh` | macOS / Linux installer |
| `install.ps1` | Windows PowerShell installer |
| `README.md` | This file |

## License

MIT
#
