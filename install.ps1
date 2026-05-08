<#
.SYNOPSIS
  Claude Code Powerline Statusline — Windows Installer
.DESCRIPTION
  Installs the Powerline status line script and configures Claude Code settings.
  Requires Git Bash (Git for Windows) to run the status line script.
#>

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Claude Code Powerline Statusline Installer (Windows)" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

$ClaudeDir = "$env:USERPROFILE\.claude"
$SettingsFile = Join-Path $ClaudeDir "settings.json"
$ScriptSrc = Join-Path $PSScriptRoot "statusline.sh"
$ScriptDst = Join-Path $ClaudeDir "statusline.sh"

# ---- Check prerequisites ----
Write-Host "[*] Checking prerequisites..." -ForegroundColor Cyan

$gitBash = Get-Command bash -ErrorAction SilentlyContinue
if (-not $gitBash) {
    Write-Host "[!] Git Bash not found on PATH." -ForegroundColor Yellow
    Write-Host "    The status line script requires Git Bash to run." -ForegroundColor Yellow
    Write-Host "    Install Git for Windows: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host "    Or use WSL and run install.sh instead." -ForegroundColor Yellow
    exit 1
}
Write-Host "[✓] Git Bash found at: $($gitBash.Source)" -ForegroundColor Green

$jq = Get-Command jq -ErrorAction SilentlyContinue
if (-not $jq) {
    Write-Host "[!] jq not found." -ForegroundColor Red
    Write-Host "    Install via: winget install jqlang.jq" -ForegroundColor Yellow
    Write-Host "    Or: scoop install jq" -ForegroundColor Yellow
    Write-Host "    Or: choco install jq" -ForegroundColor Yellow
    exit 1
}
Write-Host "[✓] jq found" -ForegroundColor Green

# ---- Create ~/.claude/ if needed ----
if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
    Write-Host "[✓] Created $ClaudeDir" -ForegroundColor Green
}

# ---- Copy script ----
Write-Host "[*] Installing statusline.sh -> $ScriptDst" -ForegroundColor Cyan
Copy-Item -Path $ScriptSrc -Destination $ScriptDst -Force
Write-Host "[✓] Script installed" -ForegroundColor Green

# ---- Update settings.json ----
Write-Host "[*] Configuring settings.json..." -ForegroundColor Cyan

$statusLineConfig = @{
    statusLine = @{
        type = "command"
        command = "~/.claude/statusline.sh"
        padding = 1
        refreshInterval = 5
    }
}

if (Test-Path $SettingsFile) {
    try {
        $settings = Get-Content $SettingsFile -Raw | ConvertFrom-Json -ErrorAction Stop
        if ($settings.statusLine) {
            Write-Host "[!] Existing statusLine config detected:" -ForegroundColor Yellow
            Write-Host "    $($settings.statusLine | ConvertTo-Json -Compress)" -ForegroundColor Yellow
            $answer = Read-Host "    Overwrite? [y/N]"
            if ($answer -ne "y" -and $answer -ne "Y") {
                Write-Host "[!] Skipped settings.json update. Add the config below manually:" -ForegroundColor Yellow
                Write-Host ($statusLineConfig | ConvertTo-Json -Depth 3) -ForegroundColor Cyan
                Write-Host ""
                Write-Host "[✓] Installation complete (script only)." -ForegroundColor Green
                exit 0
            }
        }
        # PowerShell merges: add/overwrite the statusLine property
        $settings | Add-Member -MemberType NoteProperty -Name "statusLine" -Value $statusLineConfig.statusLine -Force
        $settings | ConvertTo-Json -Depth 4 | Set-Content $SettingsFile -Encoding UTF8
    } catch {
        Write-Host "[!] Could not parse settings.json — backing up and recreating" -ForegroundColor Yellow
        $backup = "$SettingsFile.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $SettingsFile $backup
        $statusLineConfig | ConvertTo-Json -Depth 3 | Set-Content $SettingsFile -Encoding UTF8
    }
} else {
    $statusLineConfig | ConvertTo-Json -Depth 3 | Set-Content $SettingsFile -Encoding UTF8
}
Write-Host "[✓] settings.json configured" -ForegroundColor Green

# ---- Nerd Font note ----
Write-Host ""
Write-Host "[*] Nerd Font check" -ForegroundColor Cyan
Write-Host "    For Powerline glyphs (  ) to display correctly, install a Nerd Font:" -ForegroundColor Yellow
Write-Host "      https://www.nerdfonts.com/" -ForegroundColor Yellow
Write-Host "    Recommended: JetBrainsMono Nerd Font, FiraCode Nerd Font, MesloLGS NF" -ForegroundColor Yellow
Write-Host "    Set the font in your terminal emulator after installation." -ForegroundColor Yellow
Write-Host "    Without Nerd Font, the status bar falls back to ASCII mode automatically." -ForegroundColor Yellow

# ---- Done ----
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Restart Claude Code for the status line to appear."
Write-Host ""
Write-Host "  To test in Git Bash:"
Write-Host "    echo '{\"model\":{\"display_name\":\"Opus\"},\"workspace\":{\"current_dir\":\"$PWD\"},\"context_window\":{\"used_percentage\":31}}' | bash ~/.claude/statusline.sh"
Write-Host ""
