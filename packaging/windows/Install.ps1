#Requires -Version 5.1
<#
.SYNOPSIS
  Inventory Management — Windows tek komutluk kurulum.

.DESCRIPTION
  `flutter build windows --release` ciktisini kullanicinin AppData klasorune
  kurar ve Baslat menusune "Inventory Management" kisayolu ekler. Boylece
  Baslat aramasinda (Win tusu + yazma) uygulama bulunur.

.KULLANIM (Windows makinede, depo kokunden, yonetici gerekmez):
  1. flutter build windows --release
  2. powershell -ExecutionPolicy Bypass -File packaging\windows\Install.ps1

  Kaldirma: "$env:LocalAppData\InventoryManagement" klasorunu silin ve
  Baslat menusundeki "Inventory Management" kisayolunu silin.
#>
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$releaseDir = Join-Path $repoRoot 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $releaseDir 'inventory_management.exe'))) {
  throw "Release bulunamadi: $releaseDir. Once 'flutter build windows --release' calistirin."
}

$dest = Join-Path $env:LocalAppData 'InventoryManagement'
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -Recurse -Force (Join-Path $releaseDir '*') $dest

$exe = Join-Path $dest 'inventory_management.exe'

$startMenu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Inventory Management.lnk'
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut($startMenu)
$lnk.TargetPath = $exe
$lnk.WorkingDirectory = $dest
$lnk.IconLocation = "$exe,0"
$lnk.Description = 'Inventory Management — offline-first envanter uygulamasi'
$lnk.Save()

Write-Host "Kuruldu: $dest"
Write-Host "Baslat menusunde ara: Inventory Management"
