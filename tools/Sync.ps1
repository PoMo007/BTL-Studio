<#
  BTL Sync - applies an AI "patch" (plain text, see docs/PATCH-FORMAT.md) to this repo, commits and pushes.
  The patch is DATA only: files to write/delete/move. Nothing from it is ever executed.

  Usage (normally via Sync.bat):
    Sync.bat                 read the patch from the clipboard
    Sync.bat -File x.txt     read the patch from a text file
    Sync.bat -Yes            do not ask for confirmation
    Sync.bat -Undo           revert the last commit made by Sync (new revert commit, pushed)
#>
[CmdletBinding()]
param([string]$File, [switch]$Yes, [switch]$Undo)

$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Repo

function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Fail($m) { Say "ERROR: $m" Red; exit 1 }
function RunGit { & git @args; if ($LASTEXITCODE -ne 0) { Fail "git $($args -join ' ') failed (exit $LASTEXITCODE)" } }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Fail "Git is not installed. Open a terminal and run:  winget install --id Git.Git -e   then run this again."
}
if (-not (Test-Path (Join-Path $Repo '.git'))) { Fail "This folder is not a git clone of BTL-Studio." }

if ($Undo) {
    Say 'Reverting the last commit (creates a new revert commit)...' Yellow
    RunGit pull --rebase
    RunGit log -1 --oneline
    if (-not $Yes) { if ((Read-Host 'Revert this commit? (y/n)') -ne 'y') { Say 'Cancelled.'; exit 0 } }
    RunGit revert HEAD --no-edit
    RunGit push
    Say 'Done: last commit reverted and pushed.' Green
    exit 0
}

# ---- 1. get the patch text ----
if ($File) { $text = Get-Content -LiteralPath $File -Raw -Encoding UTF8 }
else       { $text = Get-Clipboard -Raw }
if ([string]::IsNullOrWhiteSpace($text)) { Fail 'The patch is empty (clipboard/file has no text).' }
$text = $text -replace "`r`n", "`n"
$lines = $text.Split("`n")

# strip one wrapping code fence if the chat copy included it
$first = 0; $last = $lines.Length - 1
while ($first -le $last -and $lines[$first].Trim() -eq '') { $first++ }
while ($last -ge $first -and $lines[$last].Trim() -eq '') { $last-- }
if ($first -le $last -and $lines[$first].TrimStart().StartsWith('```') -and $lines[$last].Trim().StartsWith('```')) { $first++; $last-- }

# ---- 2. parse ----
$marker = '^=== (FILE|DELETE|MOVE|MESSAGE|END)(?::\s*(.*?))?\s*(===)?\s*$'
$ops = New-Object System.Collections.ArrayList
$message = ''
$cur = $null
$buf = $null
function Close-Current {
    if ($script:cur -ne $null) {
        if ($script:cur.Kind -eq 'FILE') {
            $c = ($script:buf -join "`n")
            $c = $c.TrimEnd("`n") + "`n"
            $script:cur.Content = $c
        } elseif ($script:cur.Kind -eq 'MESSAGE') {
            $script:message = (($script:buf -join "`n").Trim())
            $script:cur = $null; return
        }
        [void]$script:ops.Add($script:cur)
    }
    $script:cur = $null; $script:buf = $null
}
$ended = $false
for ($i = $first; $i -le $last; $i++) {
    $ln = $lines[$i]
    if ($ln -match $marker) {
        $kind = $Matches[1]; $arg = $Matches[2]
        Close-Current
        switch ($kind) {
            'FILE'    { if (-not $arg) { Fail "Line $($i+1): FILE needs a path." }; $cur = @{ Kind='FILE'; Path=$arg.Trim(); Content='' }; $buf = @() }
            'DELETE'  { if (-not $arg) { Fail "Line $($i+1): DELETE needs a path." }; [void]$ops.Add(@{ Kind='DELETE'; Path=$arg.Trim() }) }
            'MOVE'    { if ($arg -notmatch '^(.+?)\s*->\s*(.+)$') { Fail "Line $($i+1): MOVE needs 'old -> new'." }; [void]$ops.Add(@{ Kind='MOVE'; From=$Matches[1].Trim(); To=$Matches[2].Trim() }) }
            'MESSAGE' { $cur = @{ Kind='MESSAGE' }; $buf = @(); if ($arg) { $buf += $arg } }
            'END'     { $ended = $true }
        }
        if ($ended) { break }
    } elseif ($cur -ne $null) {
        $buf += $ln
    } elseif ($ln.Trim() -ne '') {
        Fail "Line $($i+1): text outside any block: '$ln'. The patch must start with '=== FILE: ...' (see docs/PATCH-FORMAT.md)."
    }
}
Close-Current
if (-not $ended) { Fail "The patch has no '=== END ===' line. It was probably cut off while copying. Nothing was changed." }
if ($ops.Count -eq 0) { Fail 'The patch has no operations.' }

# ---- 3. safety checks ----
$blockedName = '(^|/)(config\.json|\.env|state\.json)$'
$blockedExt  = '\.(flp|lemon|wav|mp3|flac|ogg|key|pem|pfx|exe|dll|zip)$'
function Test-SafePath($p) {
    if ($p -match '^[A-Za-z]:' -or $p.StartsWith('/') -or $p.StartsWith('\')) { return "absolute path not allowed: $p" }
    $n = $p -replace '\\', '/'
    if ($n -match '(^|/)\.\.(/|$)') { return "'..' not allowed: $p" }
    if ($n -match '(^|/)\.git(/|$)') { return ".git is off limits: $p" }
    if ($n -match $blockedName -or $n -match $blockedExt) { return "blocked file type (secrets/projects/audio/binaries): $p" }
    return $null
}
foreach ($o in $ops) {
    foreach ($p in @($o.Path, $o.From, $o.To)) {
        if ($p) { $err = Test-SafePath $p; if ($err) { Fail $err } }
    }
    if ($o.Kind -eq 'FILE' -and $o.Content.Length -gt 1500000) { Fail "File too large: $($o.Path)" }
}

# ---- 4. sync, summary, confirm ----
$dirty = (& git status --porcelain)
if ($dirty) { Fail "You have uncommitted local changes. Commit or discard them first:`n$dirty" }
Say 'Getting the latest version from GitHub...' DarkGray
RunGit pull --rebase

Say ''
Say 'Patch summary:' Cyan
foreach ($o in $ops) {
    switch ($o.Kind) {
        'FILE'   { $t = if (Test-Path -LiteralPath (Join-Path $Repo $o.Path)) { 'CHANGE' } else { 'NEW   ' }; Say ("  {0}  {1}  ({2} lines)" -f $t, $o.Path, ($o.Content.Split("`n").Length - 1)) }
        'DELETE' { Say "  DELETE  $($o.Path)" Yellow }
        'MOVE'   { Say "  MOVE    $($o.From) -> $($o.To)" Yellow }
    }
}
if (-not $message) { $message = 'Update from AI patch' }
Say "Commit message: $message" DarkGray
if (-not $Yes) { if ((Read-Host 'Apply, commit and push? (y/n)') -ne 'y') { Say 'Cancelled. Nothing was changed.'; exit 0 } }

# ---- 5. apply ----
function Get-Style($path) {
    $e = [IO.Path]::GetExtension($path).ToLower()
    switch ($e) {
        '.ps1' { return @{ Bom = $true;  Crlf = $true } }
        '.txt' { return @{ Bom = $true;  Crlf = $true } }
        '.bat' { return @{ Bom = $false; Crlf = $true } }
        '.cmd' { return @{ Bom = $false; Crlf = $true } }
        default { return @{ Bom = $false; Crlf = $false } }
    }
}
foreach ($o in $ops) {
    switch ($o.Kind) {
        'FILE' {
            $full = Join-Path $Repo $o.Path
            $dir = Split-Path $full -Parent
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            $st = Get-Style $o.Path
            $c = $o.Content
            if ($st.Crlf) { $c = $c -replace "`n", "`r`n" }
            $enc = New-Object System.Text.UTF8Encoding($st.Bom)
            [IO.File]::WriteAllText($full, $c, $enc)
        }
        'DELETE' { $full = Join-Path $Repo $o.Path; if (Test-Path -LiteralPath $full) { Remove-Item -LiteralPath $full -Force } }
        'MOVE' {
            $from = Join-Path $Repo $o.From; $to = Join-Path $Repo $o.To
            if (-not (Test-Path -LiteralPath $from)) { Fail "MOVE source not found: $($o.From)" }
            $td = Split-Path $to -Parent
            if (-not (Test-Path $td)) { New-Item -ItemType Directory -Path $td -Force | Out-Null }
            Move-Item -LiteralPath $from -Destination $to -Force
        }
    }
}

RunGit add -A
$staged = (& git diff --cached --name-only)
if (-not $staged) { Say 'No actual changes (files were already identical).' Yellow; exit 0 }
RunGit -c user.name='BTL AI' -c user.email='noreply@anthropic.com' commit -q -m $message
try { RunGit push } catch { Say 'Push failed. The commit is saved locally. Run Sync.bat -Undo to drop it, or fix the login and run: git push' Red; exit 1 }
Say ''
Say 'Done: committed and pushed.' Green
RunGit log -1 --oneline
Say 'To undo it: Sync-Undo.bat' DarkGray
