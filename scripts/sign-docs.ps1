#requires -version 5.1
<#
.SYNOPSIS
  Ký tác giả vào tất cả tài liệu Markdown trong docs/.
.DESCRIPTION
  Chèn dòng "**Tác giả:** <Author>" ngay dưới tiêu đề (# ...) của mỗi file .md.
  Idempotent: file đã có tên tác giả thì bỏ qua. Bỏ qua docs/site (sinh tự động).
.EXAMPLE
  powershell -File scripts/sign-docs.ps1
  powershell -File scripts/sign-docs.ps1 -Author "Thành Lê Phước"
.NOTES
  Lưu file .ps1 này dạng UTF-8 CÓ BOM để PowerShell 5.1 đọc đúng tiếng Việt.
#>
[CmdletBinding()]
param(
  [string]$Author = 'Thành Lê Phước',
  [string]$DocsDir
)
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path -Parent $scriptDir
if (-not $DocsDir) { $DocsDir = Join-Path $repoRoot 'docs' }
$DocsDir = (Resolve-Path $DocsDir).Path
$outFull = [System.IO.Path]::GetFullPath((Join-Path $DocsDir 'site'))

$utf8     = New-Object System.Text.UTF8Encoding($false)   # file .md giữ UTF-8 không BOM
$signLine = "**Tác giả:** $Author"

$files = Get-ChildItem -Path $DocsDir -Recurse -Filter *.md -File |
  Where-Object { -not $_.FullName.StartsWith($outFull, [StringComparison]::OrdinalIgnoreCase) }

$signed = 0; $skipped = 0
foreach ($f in $files) {
  $raw = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)

  if ($raw.Contains($Author)) { $skipped++; continue }          # đã ký

  $nl = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
  $lines = ($raw -replace "`r`n", "`n") -split "`n"

  $idx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^#\s+') { $idx = $i; break }
  }
  if ($idx -lt 0) { $skipped++; continue }                       # không có tiêu đề

  $before = @($lines[0..$idx])
  $after  = if ($idx -lt ($lines.Count - 1)) { @($lines[($idx + 1)..($lines.Count - 1)]) } else { @() }

  $new = @()
  $new += $before
  $new += ''
  $new += $signLine
  $new += $after

  [System.IO.File]::WriteAllText($f.FullName, ($new -join $nl), $utf8)
  $signed++
}

Write-Host ""
Write-Host ("  ✓ Đã ký '{0}' vào {1} tài liệu (bỏ qua {2} đã ký/không tiêu đề)" -f $Author, $signed, $skipped) -ForegroundColor Green
Write-Host ""
