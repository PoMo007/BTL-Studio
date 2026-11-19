<#
  Lemon Studio - installer / updater (Windows 10/11, PowerShell 5.1+)
  Run it again at any time: first run = install, later runs = smart update.

  Switches:
    -Root <path>   install location (default C:\DAW\Image-Line)
    -NoPlugins     skip building / installing the VST3+CLAP plugins
    -Force         rebuild even if already up to date / discard local source edits
    -CheckOnly     only report prerequisites and update status, change nothing
    -Branch <name> git branch to follow (default main)
#>
[CmdletBinding()]
param(
    [string]$Root = 'C:\DAW\Image-Line',
    [string]$Branch = 'main',
    [switch]$NoPlugins,
    [switch]$Force,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$RepoUrl   = 'https://github.com/PoMo007/Lemon-Studio.git'
$MinRust   = [version]'1.85.0'
$App       = Join-Path $Root 'Lemon-Studio'
$Src       = Join-Path $App 'src'
$Bin       = Join-Path $App 'bin'
$Backups   = Join-Path $App 'backups'
$Logs      = Join-Path $App 'logs'
$AgentDir  = Join-Path $App 'agent'
$StateFile = Join-Path $App 'state.json'
$ExePath   = Join-Path $Bin 'lemonstudio.exe'
$BuiltExe  = Join-Path $Src 'target\release\lemonstudio.exe'
$SettingsDir = Join-Path $env:APPDATA 'Lemon Studio'

# ---------- helpers ----------
function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }
function Step($msg) { Write-Host ''; Write-Host "== $msg" -ForegroundColor Cyan }

function Update-SessionPath {
    $m = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $u = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$m;$u;$env:USERPROFILE\.cargo\bin"
}

function Test-Cmd($name) { return [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# Runs a native command, shows its output, returns the exit code (never throws on non-zero).
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments, [string]$Dir = $null)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if ($Dir) { Push-Location $Dir }
    try {
        & $Exe @Arguments | Out-Host
        $code = $LASTEXITCODE
    } finally {
        if ($Dir) { Pop-Location }
        $ErrorActionPreference = $old
    }
    return $code
}

# Runs git inside the source folder and returns its trimmed stdout ('' on failure).
function Git-Out {
    param([string[]]$Arguments)
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $o = & git -C $Src @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) { return '' }
        return (($o | Out-String).Trim())
    } finally { $ErrorActionPreference = $old }
}

function Winget-Install($id, $extra = @()) {
    if (-not (Test-Cmd 'winget')) {
        throw "winget is not available. Install '$id' manually, then run this script again."
    }
    $a = @('install', '--id', $id, '-e', '--accept-package-agreements', '--accept-source-agreements') + $extra
    $code = Invoke-Native 'winget' $a
    Say "  winget exit code: $code (checked again below)" DarkGray
    Update-SessionPath
}

# ---------- prerequisite checks ----------
function Test-Git   { return (Test-Cmd 'git') }
function Test-Rust {
    if (-not ((Test-Cmd 'cargo') -and (Test-Cmd 'rustc'))) { return $false }
    $v = (& rustc --version) 2>$null
    if ($v -match 'rustc (\d+\.\d+\.\d+)') { return ([version]$Matches[1] -ge $MinRust) }
    return $false
}
function Test-Msvc {
    $pf86 = ${env:ProgramFiles(x86)}
    $vw = Join-Path $pf86 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path $vw)) { return $false }
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $p = & $vw -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
    } finally { $ErrorActionPreference = $old }
    if (-not $p) { return $false }
    return (Test-Path (Join-Path $pf86 'Windows Kits\10\Lib'))
}
function Find-LibClang {
    $c = @()
    if ($env:LIBCLANG_PATH) { $c += $env:LIBCLANG_PATH }
    $c += (Join-Path $env:ProgramFiles 'LLVM\bin')
    $c += (Join-Path ${env:ProgramFiles(x86)} 'LLVM\bin')
    foreach ($d in $c) { if ($d -and (Test-Path (Join-Path $d 'libclang.dll'))) { return $d } }
    return $null
}

function Show-Prereqs {
    $r = [ordered]@{
        'Git'                          = (Test-Git)
        "Rust (>= $MinRust) + cargo"   = (Test-Rust)
        'Visual C++ Build Tools + SDK' = (Test-Msvc)
        'LLVM (libclang)'              = [bool](Find-LibClang)
    }
    foreach ($k in $r.Keys) {
        if ($r[$k]) { Say ("  [ok]      " + $k) Green } else { Say ("  [missing] " + $k) Yellow }
    }
    return $r
}

function Ensure-Prereqs {
    Step 'Checking prerequisites (only missing ones are installed)'
    Update-SessionPath
    $s = Show-Prereqs

    if (-not $s['Git']) {
        Step 'Installing Git'
        Winget-Install 'Git.Git'
    }
    if (-not $s['Visual C++ Build Tools + SDK']) {
        Step 'Installing Visual C++ Build Tools (a Windows permission prompt will appear; this is the big one, 5-15 min)'
        Winget-Install 'Microsoft.VisualStudio.2022.BuildTools' @('--override', '--passive --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
    }
    if (-not $s["Rust (>= $MinRust) + cargo"]) {
        Step 'Installing / updating Rust'
        if (-not (Test-Cmd 'rustup')) { Winget-Install 'Rustlang.Rustup' }
        if (Test-Cmd 'rustup') {
            [void](Invoke-Native 'rustup' @('default', 'stable-x86_64-pc-windows-msvc'))
            [void](Invoke-Native 'rustup' @('update', 'stable'))
        }
        Update-SessionPath
    }
    if (-not $s['LLVM (libclang)']) {
        Step 'Installing LLVM'
        Winget-Install 'LLVM.LLVM'
    }

    $lc = Find-LibClang
    if ($lc) {
        $env:LIBCLANG_PATH = $lc
        if ([Environment]::GetEnvironmentVariable('LIBCLANG_PATH', 'User') -ne $lc) {
            [Environment]::SetEnvironmentVariable('LIBCLANG_PATH', $lc, 'User')
        }
    }

    Step 'Re-checking prerequisites'
    $s = Show-Prereqs
    $bad = @($s.Keys | Where-Object { -not $s[$_] })
    if ($bad.Count -gt 0) {
        throw ("Still missing: " + ($bad -join ', ') + ". If something was just installed, close this window, open the script again (the PATH needs a refresh). If it keeps failing, send me the log in $Logs")
    }
}

# ---------- state ----------
function Read-State {
    if (Test-Path $StateFile) { try { return (Get-Content $StateFile -Raw | ConvertFrom-Json) } catch { return $null } }
    return $null
}
function Write-State($commit) {
    $o = [ordered]@{ commit = $commit; branch = $Branch; updated = (Get-Date).ToString('s'); root = $App }
    $o | ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8
}

function Remove-Old($pattern, $keep) {
    Get-ChildItem -Path $Backups -Filter $pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip $keep |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
}

function Test-AppRunning {
    $p = Get-Process -Name 'lemonstudio' -ErrorAction SilentlyContinue
    return [bool]$p
}

function Build-App {
    Step 'Building Lemon Studio (first build takes a while; later ones are incremental)'
    $a = @('build', '--release', '--locked', '-p', 'os-app')
    $code = Invoke-Native 'cargo' $a $Src
    if ($code -ne 0) {
        Say 'Build failed. Updating the Rust toolchain and retrying once...' Yellow
        if (Test-Cmd 'rustup') { [void](Invoke-Native 'rustup' @('update', 'stable')) }
        $code = Invoke-Native 'cargo' $a $Src
    }
    return ($code -eq 0)
}

function Publish-Exe {
    if (-not (Test-Path $BuiltExe)) { throw "Build finished but $BuiltExe was not found." }
    if (Test-AppRunning) { throw 'Lemon Studio is running. Close it and run the script again (your current version is untouched).' }
    New-Item -ItemType Directory -Force -Path $Bin | Out-Null
    $tmp = "$ExePath.new"
    Copy-Item -LiteralPath $BuiltExe -Destination $tmp -Force
    Move-Item -LiteralPath $tmp -Destination $ExePath -Force
}

function Install-Plugins {
    if ($NoPlugins) { Say 'Skipping plugins (-NoPlugins).' DarkGray; return }
    Step 'Building / installing the VST3 + CLAP plugins (unchanged ones are skipped)'
    $code = Invoke-Native 'cargo' @('run', '--locked', '-p', 'bundle-plugins', '--', '--install') $Src
    if ($code -ne 0) { Say 'Plugin build failed. The app itself is fine; run the script again later or send me the log.' Yellow }
}

function Write-Launchers {
    New-Item -ItemType Directory -Force -Path $AgentDir | Out-Null
    $agentBat = Join-Path $App 'Start-Lemon-Agent-Mode.bat'
    $bat = "@echo off`r`ncd /d `"%~dp0`"`r`necho Agent mode: control port 7777, level = propose (you approve each change).`r`necho The access token is shown in the app's hint bar.`r`nstart `"`" `"%~dp0bin\lemonstudio.exe`" --control 7777 --control-level propose %*`r`n"
    Set-Content -Path $agentBat -Value $bat -Encoding ASCII

    # keep a copy of this installer next to the app so "update" is always one double-click away
    foreach ($f in @('Lemon-Studio-Setup.ps1', 'Install-or-Update.bat')) {
        $from = Join-Path $PSScriptRoot $f
        $to = Join-Path $App $f
        if ((Test-Path $from) -and ($from -ne $to)) { Copy-Item -LiteralPath $from -Destination $to -Force }
    }

    try {
        $desk = [Environment]::GetFolderPath('Desktop')
        $lnk = Join-Path $desk 'Lemon Studio.lnk'
        if (-not (Test-Path $lnk)) {
            $sh = New-Object -ComObject WScript.Shell
            $s = $sh.CreateShortcut($lnk)
            $s.TargetPath = $ExePath
            $s.WorkingDirectory = $App
            $s.Save()
        }
    } catch { Say "  (desktop shortcut skipped: $($_.Exception.Message))" DarkGray }
}

# ---------- main ----------
New-Item -ItemType Directory -Force -Path $App, $Logs | Out-Null
$logFile = Join-Path $Logs ("setup-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
try { Start-Transcript -Path $logFile | Out-Null } catch {}

$exitCode = 0
try {
    Say "Lemon Studio installer  ->  $App" Cyan

    if ($CheckOnly) {
        Step 'Prerequisites'
        Update-SessionPath
        [void](Show-Prereqs)
    } else {
        Ensure-Prereqs
    }

    Step 'Source code'
    $fresh = -not (Test-Path (Join-Path $Src '.git'))
    $oldCommit = $null
    $stashed = $false

    if ($fresh) {
        if ($CheckOnly) { Say '  Not installed yet.' Yellow; throw 'CHECKONLY_DONE' }
        Say '  Cloning (full history, so you can roll back later)...'
        $code = Invoke-Native 'git' @('-c', 'core.longpaths=true', 'clone', '--branch', $Branch, $RepoUrl, $Src)
        if ($code -ne 0) { throw 'git clone failed (check your internet / VPN).' }
        $new = Git-Out @('rev-parse', 'HEAD')
        Git-Out @('config', 'core.longpaths', 'true') | Out-Null
        if (-not (Build-App)) { throw "Build failed. Full log: $logFile" }
        Publish-Exe
        Install-Plugins
        Write-State $new
        Write-Launchers
        Say ''
        Say "Installed Lemon Studio at commit $($new.Substring(0,8))." Green
    } else {
        $oldCommit = Git-Out @('rev-parse', 'HEAD')
        Say '  Checking for updates...'
        $code = Invoke-Native 'git' @('-C', $Src, 'fetch', 'origin', $Branch)
        if ($code -ne 0) { throw 'git fetch failed (check your internet / VPN). Nothing was changed.' }
        $remote = Git-Out @('rev-parse', "origin/$Branch")
        $state = Read-State
        $exeOk = (Test-Path $ExePath) -and $state -and ($state.commit -eq $oldCommit)

        if ($oldCommit -eq $remote -and $exeOk -and -not $Force) {
            Say "Already up to date (commit $($oldCommit.Substring(0,8))). Nothing to do." Green
            if (-not $CheckOnly) { Install-Plugins; Write-Launchers }
        } else {
            $behind = Git-Out @('rev-list', '--count', "HEAD..origin/$Branch")
            if ($oldCommit -ne $remote) {
                Say "  $behind new change(s) available:" Yellow
                Say (Git-Out @('log', '--oneline', '-n', '15', "HEAD..origin/$Branch"))
                $changed = Git-Out @('diff', '--name-only', 'HEAD', "origin/$Branch")
                if ($changed -match 'Cargo\.lock') { Say '  Dependencies changed: the rebuild will be longer than usual.' DarkGray }
            } else {
                Say '  Source is current, but the installed program is missing or does not match. Rebuilding.' Yellow
            }
            if ($CheckOnly) { throw 'CHECKONLY_DONE' }

            # --- safety net before touching anything ---
            New-Item -ItemType Directory -Force -Path $Backups | Out-Null
            if (Test-Path $ExePath) {
                Copy-Item -LiteralPath $ExePath -Destination (Join-Path $Backups ("lemonstudio-" + $oldCommit.Substring(0, 8) + '.exe')) -Force
                Remove-Old 'lemonstudio-*.exe' 3
            }
            if (Test-Path $SettingsDir) {
                $sb = Join-Path $Backups ("settings-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
                Copy-Item -LiteralPath $SettingsDir -Destination $sb -Recurse -Force
                Remove-Old 'settings-*' 3
                Say "  Settings backed up to $sb" DarkGray
            }

            # local edits in the source folder are stashed, never silently lost
            $dirty = Git-Out @('status', '--porcelain', '--untracked-files=no')
            if ($dirty) {
                Say '  Local changes found in the source folder; saving them with git stash.' Yellow
                [void](Invoke-Native 'git' @('-C', $Src, 'stash', 'push', '-m', 'lemon-setup-autostash'))
                $stashed = $true
            }

            if ($oldCommit -ne $remote) {
                $isAncestor = (Invoke-Native 'git' @('-C', $Src, 'merge-base', '--is-ancestor', 'HEAD', "origin/$Branch")) -eq 0
                if ($isAncestor) {
                    $code = Invoke-Native 'git' @('-C', $Src, 'merge', '--ff-only', "origin/$Branch")
                    if ($code -ne 0) { throw 'Fast-forward failed; nothing was changed.' }
                } elseif ($Force) {
                    Say '  Your source diverged from upstream; -Force given, resetting to upstream.' Yellow
                    [void](Invoke-Native 'git' @('-C', $Src, 'reset', '--hard', "origin/$Branch"))
                } else {
                    throw 'Your local source has commits that upstream does not (or history was rewritten). Run again with -Force to reset to upstream, or fix it by hand.'
                }
            }

            $ok = Build-App
            if (-not $ok) {
                Say 'Update build FAILED. Rolling the source back; your working version is untouched.' Red
                [void](Invoke-Native 'git' @('-C', $Src, 'reset', '--hard', $oldCommit))
                if ($stashed) { [void](Invoke-Native 'git' @('-C', $Src, 'stash', 'pop')) }
                throw "Update failed, old version kept. Log: $logFile"
            }
            Publish-Exe
            Install-Plugins
            $new = Git-Out @('rev-parse', 'HEAD')
            Write-State $new
            Write-Launchers
            if ($stashed) {
                $code = Invoke-Native 'git' @('-C', $Src, 'stash', 'pop')
                if ($code -ne 0) { Say '  Could not re-apply your local source edits automatically; they are kept in `git stash`.' Yellow }
            }
            Say ''
            Say "Updated $($oldCommit.Substring(0,8)) -> $($new.Substring(0,8)). Previous program kept in $Backups" Green
        }
    }

    if (-not $CheckOnly) {
        Say ''
        Say "Program:      $ExePath" Green
        Say "Agent mode:   $App\Start-Lemon-Agent-Mode.bat" Green
        Say 'FL Studio: Options > Manage plugins > add this folder to the scan list to see the Lemon plugins:' Gray
        Say "   $env:LOCALAPPDATA\Programs\Common\VST3     (and ...\CLAP)" Gray
    }
}
catch {
    if ($_.Exception.Message -eq 'CHECKONLY_DONE') {
        Say 'Check finished (nothing changed).' Green
    } else {
        $exitCode = 1
        Say ''
        Say "ERROR: $($_.Exception.Message)" Red
        Say "Log file: $logFile" Yellow
    }
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
exit $exitCode
