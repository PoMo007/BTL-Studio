<#
  Lemon Studio (BTL fork) - installer / updater, Windows 10/11, PowerShell 5.1+
  Downloads the prebuilt program and plugins that GitHub builds from the fork
  (https://github.com/PoMo007/Lemon-Studio, release "latest"). No compiler needed.
  First run = install, every later run = smart update. Safe to run any time.

  Switches:
    -Root <path>   install location (default C:\DAW\Image-Line)
    -NoPlugins     do not install/update the VST3 + CLAP plugins
    -Force         reinstall everything even if already current
    -CheckOnly     only report what would change, change nothing
  Slow fallback that compiles locally: Build-From-Source.bat
#>
[CmdletBinding()]
param(
    [string]$Root = 'C:\DAW\Image-Line',
    [switch]$NoPlugins,
    [switch]$Force,
    [switch]$CheckOnly
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$Owner      = 'PoMo007'
$LemonRepo  = 'Lemon-Studio'
$AgentRepo  = 'BTL-Studio'
$App        = Join-Path $Root 'Lemon-Studio'
$Bin        = Join-Path $App 'bin'
$Backups    = Join-Path $App 'backups'
$Logs       = Join-Path $App 'logs'
$AgentDir   = Join-Path $App 'agent'
$StateFile  = Join-Path $App 'state.json'
$ExePath    = Join-Path $Bin 'lemonstudio.exe'
$SettingsDir = Join-Path $env:APPDATA 'Lemon Studio'
$VstDir     = Join-Path $env:LOCALAPPDATA 'Programs\Common\VST3'
$ClapDir    = Join-Path $env:LOCALAPPDATA 'Programs\Common\CLAP'
$Tmp        = Join-Path $env:TEMP 'btl-installer'

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }
function Step($msg) { Write-Host ''; Write-Host "== $msg" -ForegroundColor Cyan }

function Get-Json($url) {
    return Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent' = 'BTL-Installer'; 'Accept' = 'application/vnd.github+json' }
}
function Get-File($url, $dest) {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -Headers @{ 'User-Agent' = 'BTL-Installer' }
}
function Get-Sha($path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() }

function Read-State {
    if (Test-Path $StateFile) { try { return (Get-Content $StateFile -Raw | ConvertFrom-Json) } catch { return $null } }
    return $null
}
function Get-Prop($obj, $name) {
    if ($obj -and ($obj.PSObject.Properties.Name -contains $name)) { return $obj.$name }
    return ''
}
function Remove-Old($pattern, $keep) {
    Get-ChildItem -Path $Backups -Filter $pattern -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip $keep |
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
}

function Ensure-VcRuntime {
    $sys = Join-Path $env:SystemRoot 'System32'
    if ((Test-Path (Join-Path $sys 'vcruntime140.dll')) -and (Test-Path (Join-Path $sys 'vcruntime140_1.dll'))) { return }
    Step 'Installing the Microsoft Visual C++ runtime (needed to run the program)'
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        & winget install --id Microsoft.VCRedist.2015+.x64 -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
    } else {
        Say 'winget not found. Install "Microsoft Visual C++ Redistributable x64" from microsoft.com, then run this again.' Yellow
    }
}

function Write-Launchers {
    $agentBat = Join-Path $App 'Start-Lemon-Agent-Mode.bat'
    $bat = "@echo off`r`ncd /d `"%~dp0`"`r`necho Agent mode: control port 7777, level = propose (you approve each change).`r`necho The access token is shown in the app's hint bar.`r`nstart `"`" `"%~dp0bin\lemonstudio.exe`" --control 7777 --control-level propose %*`r`n"
    Set-Content -Path $agentBat -Value $bat -Encoding ASCII
    try {
        $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Lemon Studio.lnk'
        if (-not (Test-Path $lnk)) {
            $s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
            $s.TargetPath = $ExePath
            $s.WorkingDirectory = $App
            $s.Save()
        }
    } catch { Say "  (desktop shortcut skipped: $($_.Exception.Message))" DarkGray }
}

New-Item -ItemType Directory -Force -Path $App, $Logs, $Bin, $Backups, $Tmp | Out-Null
$logFile = Join-Path $Logs ("setup-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
try { Start-Transcript -Path $logFile | Out-Null } catch {}
$exitCode = 0

try {
    Say "Lemon Studio (BTL) installer  ->  $App" Cyan
    Ensure-VcRuntime

    Step 'Looking for the latest build on GitHub'
    try {
        $rel = Get-Json "https://api.github.com/repos/$Owner/$LemonRepo/releases/tags/latest"
    } catch {
        throw "No published build found yet (or no internet / VPN). The first build runs on GitHub after the fork's workflow starts and takes 30-60 minutes: https://github.com/$Owner/$LemonRepo/actions . Details: $($_.Exception.Message)"
    }
    $aInfo = $rel.assets | Where-Object { $_.name -eq 'build-info.json' } | Select-Object -First 1
    $aExe  = $rel.assets | Where-Object { $_.name -eq 'lemonstudio.exe' } | Select-Object -First 1
    $aPlug = $rel.assets | Where-Object { $_.name -eq 'LemonStudio-Plugins.zip' } | Select-Object -First 1
    if (-not ($aInfo -and $aExe -and $aPlug)) { throw 'The release exists but is incomplete (a build may still be uploading). Try again in a few minutes.' }

    $infoFile = Join-Path $Tmp 'build-info.json'
    Get-File $aInfo.browser_download_url $infoFile
    $info = Get-Content $infoFile -Raw | ConvertFrom-Json
    $state = Read-State

    $exeCurrent  = (Test-Path $ExePath) -and ((Get-Sha $ExePath) -eq $info.exe_sha256)
    $plugCurrent = ((Get-Prop $state 'plugins_sha256') -eq $info.plugins_sha256)
    $oldCommit   = Get-Prop $state 'commit'
    $newShort    = $info.commit.Substring(0, 8)

    Say "  Latest build: commit $newShort, built $($info.built_at)"
    if ($exeCurrent) { Say '  Program:  up to date' Green } else { Say '  Program:  update available' Yellow }
    if ($NoPlugins) { Say '  Plugins:  skipped (-NoPlugins)' DarkGray }
    elseif ($plugCurrent) { Say '  Plugins:  up to date' Green } else { Say '  Plugins:  update available' Yellow }

    if ((-not $exeCurrent) -and $oldCommit -and ($oldCommit -ne $info.commit)) {
        try {
            $cmp = Get-Json "https://api.github.com/repos/$Owner/$LemonRepo/compare/$oldCommit...$($info.commit)"
            Say "  $($cmp.total_commits) change(s) since your version, latest ones:" Yellow
            $cmp.commits | Select-Object -Last 12 | ForEach-Object { Say ("   - " + ($_.commit.message -split "`n")[0]) }
        } catch { }
    }

    if ($CheckOnly) {
        Say ''
        Say 'Check finished (nothing changed).' Green
    } else {
        # ---- program ----
        if ((-not $exeCurrent) -or $Force) {
            Step 'Updating the program'
            if (Get-Process -Name 'lemonstudio' -ErrorAction SilentlyContinue) {
                throw 'Lemon Studio is running. Close it and run this again (nothing was changed).'
            }
            $new = Join-Path $Tmp 'lemonstudio.exe'
            Get-File $aExe.browser_download_url $new
            if ((Get-Sha $new) -ne $info.exe_sha256) { throw 'Downloaded program failed its checksum. Nothing was changed; try again.' }

            if (Test-Path $ExePath) {
                $tag = if ($oldCommit) { $oldCommit.Substring(0, 8) } else { 'previous' }
                Copy-Item -LiteralPath $ExePath -Destination (Join-Path $Backups ("lemonstudio-$tag.exe")) -Force
                Remove-Old 'lemonstudio-*.exe' 3
            }
            if (Test-Path $SettingsDir) {
                $sb = Join-Path $Backups ("settings-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
                Copy-Item -LiteralPath $SettingsDir -Destination $sb -Recurse -Force
                Remove-Old 'settings-*' 3
                Say "  Settings backed up to $sb" DarkGray
            }
            Copy-Item -LiteralPath $new -Destination "$ExePath.new" -Force
            Move-Item -LiteralPath "$ExePath.new" -Destination $ExePath -Force
            Say "  Program is now at commit $newShort." Green
        }

        # ---- plugins ----
        if ((-not $NoPlugins) -and ((-not $plugCurrent) -or $Force)) {
            Step 'Updating the VST3 + CLAP plugins'
            $zip = Join-Path $Tmp 'plugins.zip'
            Get-File $aPlug.browser_download_url $zip
            if ((Get-Sha $zip) -ne $info.plugins_sha256) { throw 'Downloaded plugins failed their checksum. Nothing was changed; try again.' }
            $ex = Join-Path $Tmp 'plugins'
            if (Test-Path $ex) { Remove-Item $ex -Recurse -Force }
            Expand-Archive -LiteralPath $zip -DestinationPath $ex -Force
            New-Item -ItemType Directory -Force -Path $VstDir, $ClapDir | Out-Null
            $failed = 0
            foreach ($item in (Get-ChildItem $ex)) {
                $dest = if ($item.Name -like '*.vst3') { $VstDir } elseif ($item.Name -like '*.clap') { $ClapDir } else { $null }
                if (-not $dest) { continue }
                try { Copy-Item -LiteralPath $item.FullName -Destination $dest -Recurse -Force }
                catch { $failed++; Say "  Could not replace $($item.Name) (is it loaded in FL Studio? close FL and run again)." Yellow }
            }
            if ($failed -eq 0) { Say '  Plugins installed.' Green } else { $plugCurrent = $false }
            if ($failed -eq 0) { $plugCurrent = $true }
        }

        # ---- agent repo (no git needed) ----
        Step 'Updating the agent (BTL-Studio repo)'
        try {
            $ac = (Get-Json "https://api.github.com/repos/$Owner/$AgentRepo/commits/main").sha
            $haveAgent = (Test-Path $AgentDir) -and ((Get-ChildItem $AgentDir -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)
            if (($ac -ne (Get-Prop $state 'agent_commit')) -or (-not $haveAgent) -or $Force) {
                $az = Join-Path $Tmp 'agent.zip'
                Get-File "https://github.com/$Owner/$AgentRepo/archive/refs/heads/main.zip" $az
                $ax = Join-Path $Tmp 'agent'
                if (Test-Path $ax) { Remove-Item $ax -Recurse -Force }
                Expand-Archive -LiteralPath $az -DestinationPath $ax -Force
                $top = Get-ChildItem $ax | Select-Object -First 1
                if (Test-Path $AgentDir) { Remove-Item $AgentDir -Recurse -Force }
                Move-Item -LiteralPath $top.FullName -Destination $AgentDir
                Say "  Agent files updated to $($ac.Substring(0, 8))." Green
            } else {
                Say '  Agent files already current.' Green
            }
        } catch {
            Say "  Agent update skipped: $($_.Exception.Message)" Yellow
            $ac = Get-Prop $state 'agent_commit'
        }

        # ---- state, launchers ----
        $o = [ordered]@{
            commit         = $info.commit
            exe_sha256     = $info.exe_sha256
            plugins_sha256 = $(if ($plugCurrent -or $NoPlugins) { $info.plugins_sha256 } else { Get-Prop $state 'plugins_sha256' })
            agent_commit   = $ac
            updated        = (Get-Date).ToString('s')
        }
        $o | ConvertTo-Json | Set-Content -Path $StateFile -Encoding UTF8
        Write-Launchers

        # keep the newest installer scripts (shipped in the agent repo) next to the app
        $inst = Join-Path $AgentDir 'installer'
        if (Test-Path $inst) {
            foreach ($f in @('Lemon-Studio-Setup.ps1', 'Install-or-Update.bat', 'Check-Only.bat', 'Build-From-Source.ps1', 'Build-From-Source.bat')) {
                $from = Join-Path $inst $f
                if (Test-Path $from) { Copy-Item -LiteralPath $from -Destination (Join-Path $App $f) -Force }
            }
        }

        Say ''
        Say "Done. Program: $ExePath" Green
        Say "Agent mode: $App\Start-Lemon-Agent-Mode.bat" Green
        Say "FL Studio: add $VstDir to Options > Manage plugins > search paths, then Find plugins." Gray
    }
}
catch {
    $exitCode = 1
    Say ''
    Say "ERROR: $($_.Exception.Message)" Red
    Say "Log file: $logFile" Yellow
}
finally {
    try { Stop-Transcript | Out-Null } catch {}
}
exit $exitCode