# -----------------------------------------------------------------------------
# Indubot - one-line installer for Windows. From PowerShell:
#   irm https://raw.githubusercontent.com/JustJans/indubot/master/install.ps1 | iex
# Downloads the latest code into ~\indubot and hands over to the guided setup.
# Re-running it UPDATES the code and never touches your profile, CV or data.
# (Why this shape: a ZIP dragged through the browser arrives with the internet
# mark and a warning on every double-click; files written here do not. And the
# install folder stays fixed, so the scheduled tasks never point at a dead copy.)
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Stop'
$dest = if ($env:INDUBOT_DEST) { $env:INDUBOT_DEST } else { Join-Path $HOME 'indubot' }
# ➤ Indubot was called Argus until October 2026, and lived in ~\argus. An install
# ➤ found there is updated where it is, with its profile, CV, data and token,
# ➤ instead of starting a second, empty one next to it that would answer the same bot.
$legacy = Join-Path $HOME 'argus'
if (-not $env:INDUBOT_DEST -and -not (Test-Path $dest) -and (Test-Path (Join-Path $legacy 'server-bot\telegram-listener.mjs'))) {
    $dest = $legacy
}
Write-Host ""
Write-Host "Installing Indubot into $dest"
$ProgressPreference = 'SilentlyContinue'
$tmp = Join-Path $env:TEMP ('indubot-install-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $zip = Join-Path $tmp 'indubot.zip'
    # ➤ Install the LATEST RELEASE, not whatever master holds this minute: a
    # ➤ half-landed push must never reach a user. The GitHub API names the
    # ➤ tag; if it cannot be reached, master beats no install at all.
    # ➤ INDUBOT_REF overrides both (tests pin "refs/heads/master").
    $ref = if ($env:INDUBOT_REF) { $env:INDUBOT_REF } else {
        try {
            $tag = (Invoke-RestMethod 'https://api.github.com/repos/JustJans/indubot/releases/latest' -TimeoutSec 10).tag_name
            Write-Host "  version: $tag (latest release)"
            "refs/tags/$tag"
        } catch { Write-Host "  release lookup failed - installing master"; 'refs/heads/master' }
    }
    Invoke-WebRequest "https://github.com/JustJans/indubot/archive/$ref.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $tmp
    # ➤ The extracted folder is named after the ref (indubot-master, indubot-1.9.0):
    # ➤ take the one folder that is there instead of guessing the suffix.
    $src = (Get-ChildItem -Path $tmp -Directory | Select-Object -First 1).FullName
    # ➤ An UPDATE must never clobber what the user built: the profile, the CV
    # ➤ and the letter example are theirs once they exist (telegram.json and
    # ➤ data/ are not in the download at all, so they survive on their own).
    # ➤ countries.yml and portals.yml joined the list 2026-08-08: both are
    # ➤ documented as hand-editable — the country toggles and any boards the
    # ➤ user added — and the update was silently reverting those edits while
    # ➤ the README promised it touched nothing of theirs.
    foreach ($rel in 'config\profile.yml', 'cv.md', 'config\cover-example.md', 'server-bot\countries.yml', 'portals.yml') {
        if ((Test-Path (Join-Path $dest $rel)) -and (Test-Path (Join-Path $src $rel))) {
            Remove-Item (Join-Path $src $rel)
        }
    }
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Copy-Item -Path (Join-Path $src '*') -Destination $dest -Recurse -Force
    Write-Host "  OK  latest code in place (your profile, CV and data untouched)"
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
if ($env:INDUBOT_NO_SETUP) {
    Write-Host "INDUBOT_NO_SETUP is set - skipping the setup."
} else {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dest 'setup\setup-windows.ps1')
}
