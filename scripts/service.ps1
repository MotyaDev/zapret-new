#requires -Version 5.1
[CmdletBinding()]
param(
  [ValidateSet('install','remove','status','diag','menu')]
  [string]$Action = 'menu'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot

function Pause { [void](Read-Host 'Press Enter to continue...') }

function Get-BinPaths {
  @{ 
    Root = $Root
    Bin = Join-Path $Root 'bin'
    Config = Join-Path $Root 'config'
    Data = Join-Path $Root 'data'
    Hostlists = Join-Path $Root 'data\hostlists'
    Ipsets = Join-Path $Root 'data\ipsets'
    Payloads = Join-Path $Root 'data\payloads'
  }
}

function Read-PresetArgs {
  param([Parameter(Mandatory)][string]$PresetPath)
  if (-not (Test-Path $PresetPath)) { throw "Preset не найден: $PresetPath" }
  $lines = Get-Content -LiteralPath $PresetPath
  $capture = $false
  $sb = New-Object System.Text.StringBuilder
  foreach ($line in $lines) {
    if (-not $capture) {
      if ($line -match '(?i)winws\.exe') { $capture = $true } else { continue }
    }
    $t = $line.Trim()
    if ($t.EndsWith('^')) {
      $null = $sb.Append($t.Substring(0, $t.Length-1)).Append(' ')
    } else {
      $null = $sb.Append($t)
      break
    }
  }
  $cmd = $sb.ToString()
  if (-not $cmd) { throw "Не удалось найти строку запуска winws.exe" }

  $exe = $null
  if ($cmd -match '"(?<exe>[^"]*winws\.exe)"') { $exe = $matches.exe }
  elseif ($cmd -match '(?<exe>[^\s"]*winws\.exe)') { $exe = $matches.exe }
  if (-not $exe) { $exe = 'winws.exe' }

  $args = ''
  if ($cmd -match '(?i)winws\.exe"?\s*(?<args>.*)$') { $args = $matches.args.Trim() }

  $paths = Get-BinPaths
  $root = $paths.Root
  $bin = $paths.Bin

  $exe = $exe -replace '%~dp0', ($root + '\\')
  if (-not [System.IO.Path]::IsPathRooted($exe)) { $exe = Join-Path $bin $exe }
  $exe = [System.IO.Path]::GetFullPath($exe)

  # Substitute path variables
  $args = $args -replace '%~dp0', ($root + '\\')
  $args = $args -replace '%BIN%', ($bin + '\\')
  $args = $args -replace '%LISTS%', ($paths.Ipsets + '\\')
  $args = $args -replace 'list-youtube\.txt', (Join-Path $paths.Hostlists 'list-youtube.txt')
  $args = $args -replace 'ipset-all\.txt', (Join-Path $paths.Ipsets 'ipset-all.txt')
  $args = $args -replace 'ipset-discord\.txt', (Join-Path $paths.Ipsets 'ipset-discord.txt')
  $args = $args -replace 'quic_initial_www_google_com\.bin', (Join-Path $paths.Payloads 'quic_initial_www_google_com.bin')
  $args = $args -replace 'tls_clienthello_www_google_com\.bin', (Join-Path $paths.Payloads 'tls_clienthello_www_google_com.bin')

  @{ Exe=$exe; Args=$args }
}

function Install-ZapretService {
  param([string]$Preset)
  $parsed = Read-PresetArgs -PresetPath $Preset
  $exe = $parsed.Exe; $args = $parsed.Args
  if (-not (Test-Path $exe)) { throw "winws.exe не найден: $exe" }
  $svc = 'zapret'
  & sc.exe stop $svc *> $null
  & sc.exe delete $svc *> $null
  $binPath = "`"$exe`" $args"
  & sc.exe create $svc binPath= $binPath DisplayName= "zapret" start= auto | Out-Null
  & sc.exe description $svc "Zapret DPI bypass" | Out-Null
  Start-Sleep -Milliseconds 300
  & sc.exe start $svc | Out-Null
  Write-Host "Сервис '$svc' установлен и запущен" -ForegroundColor Green
}

function Remove-ZapretService {
  $svc = 'zapret'
  & sc.exe stop $svc *> $null
  & sc.exe delete $svc *> $null
  Write-Host "Сервис '$svc' удален (если существовал)" -ForegroundColor Yellow
}

function Show-Status {
  & sc.exe query zapret
  $p = Get-Process -Name 'winws' -ErrorAction SilentlyContinue
  if ($p) { Write-Host "winws.exe запущен (PID: $($p.Id))" -ForegroundColor Green } else { Write-Host "winws.exe не найден" -ForegroundColor Red }
}

function Run-Diagnostics {
  Write-Host "Диагностика..." -ForegroundColor Cyan
  $paths = Get-BinPaths
  foreach ($f in 'winws.exe','WinDivert.dll','WinDivert64.sys') {
    $path = Join-Path $paths.Root $f
    if (Test-Path $path) { Write-Host "[OK] $f" -ForegroundColor Green } else { Write-Host "[!] Нет файла $f" -ForegroundColor Yellow }
  }
  foreach ($port in 80,443) {
    $inUse = (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue) -ne $null
    if ($inUse) { Write-Host "[!] Port $port занят" -ForegroundColor Yellow }
  }
}

function Pre-Install { Run-Diagnostics }

function Choose-Preset {
  $candidates = @()
  $configDir = Join-Path $Root 'config'
  if (Test-Path $configDir) { 
    $candidates += Get-ChildItem -LiteralPath $configDir -Filter '*.cmd' -File -ErrorAction SilentlyContinue 
  }
  # Fallback: check root for old structure
  $candidates += Get-ChildItem -LiteralPath $Root -Filter '*.cmd' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '^service' }
  if (-not $candidates) { throw 'Не найдены .cmd пресеты' }
  Write-Host 'Выберите пресет:' -ForegroundColor Cyan
  for ($i=0; $i -lt $candidates.Count; $i++) { Write-Host ("{0}. {1}" -f ($i+1), $candidates[$i].FullName) }
  $sel = Read-Host 'Номер'
  if (-not ($sel -as [int])) { throw 'Неверный ввод' }
  $idx = [int]$sel - 1
  if ($idx -lt 0 -or $idx -ge $candidates.Count) { throw 'Неверный индекс' }
  $candidates[$idx].FullName
}

function Show-Menu {
  Write-Host ''
  Write-Host '===== zapret service ====='
  Write-Host '1. Install Service'
  Write-Host '2. Remove Service'
  Write-Host '3. Check Status'
  Write-Host '4. Run Diagnostics'
  Write-Host '5. Pre-Install Checks'
  Write-Host '0. Exit'
  $c = Read-Host 'Select'
  switch ($c) {
    '1' { try { $preset = Choose-Preset; Install-ZapretService -Preset $preset } catch { Write-Host $_.Exception.Message -ForegroundColor Red } }
    '2' { Remove-ZapretService }
    '3' { Show-Status }
    '4' { Run-Diagnostics }
    '5' { Pre-Install }
    '0' { return }
    default { }
  }
  Pause
  Show-Menu
}

switch ($Action) {
  'install' { $p = Choose-Preset; Install-ZapretService -Preset $p }
  'remove'  { Remove-ZapretService }
  'status'  { Show-Status }
  'diag'    { Run-Diagnostics }
  default   { Show-Menu }
}
