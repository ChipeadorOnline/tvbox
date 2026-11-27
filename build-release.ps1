param(
  [Parameter(Mandatory = $true)]
  [string]$ApiUrl,
  [string]$CatalogUrl = 'https://raw.githubusercontent.com/ChipeadorOnline/tvbox/main/catalog.json',
  [string]$BuildName = '1.0.16',
  [int]$BuildNumber = 16
)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot

Push-Location (Join-Path $root 'tvbox_app')
try {
  flutter build apk --release `
    --build-name=$BuildName `
    --build-number=$BuildNumber `
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
