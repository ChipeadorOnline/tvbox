param(
  [Parameter(Mandatory = $true)]
  [string]$ApiUrl,
  [string]$CatalogUrl = 'https://raw.githubusercontent.com/ChipeadorOnline/tvbox/main/catalog.json'
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

Push-Location (Join-Path $root 'tvbox_app')
try {
  flutter build apk --release `
    --dart-define="API_URL=$ApiUrl" `
    --dart-define="CATALOG_URL=$CatalogUrl"
} finally {
  Pop-Location
}

$source = Join-Path $root 'tvbox_app\build\app\outputs\flutter-apk\app-release.apk'
$destinationDir = Join-Path $root 'apk'
New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
$destination = Join-Path $destinationDir 'tvbox-updater-release.apk'
Copy-Item -Path $source -Destination $destination -Force

Write-Host "APK listo: $destination"
