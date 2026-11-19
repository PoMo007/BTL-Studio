<#
  BTL Pack - builds one text block (rules + status + file list + any files you name) and copies it to the clipboard,
  so you can paste it into any AI chat. Usage:  Pack.bat [extra files...]   (paths relative to the repo root)
#>
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Extra)
$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Repo
if (Get-Command git -ErrorAction SilentlyContinue) { try { & git pull --rebase 2>&1 | Out-Null } catch {} }

$sb = New-Object System.Text.StringBuilder
function Add($s) { [void]$sb.AppendLine($s) }
function Add-File($rel) {
    $p = Join-Path $Repo $rel
    if (-not (Test-Path -LiteralPath $p)) { Add "(missing: $rel)"; return }
    $t = Get-Content -LiteralPath $p -Raw -Encoding UTF8
    if ($t.Length -gt 200000) { $t = $t.Substring(0, 200000) + "`n...(cut at 200 KB)" }
    Add "=== CONTEXT FILE: $rel ==="
    Add $t.TrimEnd()
    Add ''
}

Add 'You are continuing the BTL-Studio project. You have NO GitHub access in this chat. Read everything below first.'
Add 'Follow CLAUDE.md (Rule 0 first). Work normally; when you finish, reply with ONE patch in the format of docs/PATCH-FORMAT.md,'
Add 'containing every changed file in full (including updated TASKS.md and the Status section of HANDOFF.md). The owner copies it and runs Sync.bat.'
Add 'Reply to the owner in Persian.'
Add ''
foreach ($f in @('CLAUDE.md', 'HANDOFF.md', 'TASKS.md', 'docs/PATCH-FORMAT.md')) { Add-File $f }
if (Get-Command git -ErrorAction SilentlyContinue) {
    Add '=== CONTEXT: repository file list ==='
    Add ((& git ls-files) -join "`n")
    Add ''
}
foreach ($e in $Extra) { if ($e) { Add-File ($e -replace '\\', '/') } }
Add '=== END OF CONTEXT ==='

Set-Clipboard -Value $sb.ToString()
Write-Host ("Copied {0:N0} characters to the clipboard. Paste it into the AI chat, then write your task." -f $sb.Length) -ForegroundColor Green
