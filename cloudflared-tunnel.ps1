param(
  [int]$Port = 3000,
  [switch]$Stop
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$bin = Join-Path $root 'tools\cloudflared.exe'
$log = Join-Path $root 'tools\tunnel.log'
$urlFile = Join-Path $root 'tools\tunnel-url.txt'

if ($Stop) {
  Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
  Remove-Item $urlFile -ErrorAction SilentlyContinue
  Write-Host 'Túnel detenido.'
  return
}

if (-not (Test-Path $bin)) {
  New-Item -ItemType Directory -Path (Split-Path $bin) -Force | Out-Null
  Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile $bin -UseBasicParsing
}

Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-Item $log, "$log.err", $urlFile -ErrorAction SilentlyContinue

$process = Start-Process -FilePath $bin `
  -ArgumentList @('tunnel', '--url', "http://localhost:$Port") `
  -RedirectStandardOutput $log `
  -RedirectStandardError "$log.err" `
  -PassThru `
  -WindowStyle Hidden

for ($i = 0; $i -lt 80; $i++) {
  Start-Sleep -Milliseconds 500
  $text = ''
  foreach ($file in @($log, "$log.err")) {
    if (Test-Path $file) { $text += (Get-Content $file -Raw -ErrorAction SilentlyContinue) }
  }
  $match = [regex]::Match($text, 'https://[a-zA-Z0-9-]+\.trycloudflare\.com')
  if ($match.Success) {
    Set-Content -Path $urlFile -Value $match.Value
    Write-Host "URL pública: $($match.Value)"
    Write-Host "PID del túnel: $($process.Id)"
    Write-Host "Para cerrarlo: .\cloudflared-tunnel.ps1 -Stop"
    return
  }
}

Write-Warning "No se obtuvo la URL. Revisá $log y $log.err"
