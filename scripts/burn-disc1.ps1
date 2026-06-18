param(
    [string]$IsoPath = "C:\Users\rxcam\news-rapper\dvd5-refresh-disc\out\bearbox-disc1-install-refresh.iso",
    [string]$Drive = "G:"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $IsoPath)) {
    throw "ISO not found: $IsoPath"
}

$iso = Resolve-Path -LiteralPath $IsoPath
$burner = Join-Path $env:SystemRoot "System32\isoburn.exe"

if (-not (Test-Path -LiteralPath $burner)) {
    throw "isoburn.exe not found at $burner"
}

$cdrom = Get-CimInstance Win32_CDROMDrive | Where-Object { $_.Drive -eq $Drive }
if (-not $cdrom) {
    throw "No optical writer found at $Drive"
}

if (-not $cdrom.MediaLoaded) {
    throw "No writable media appears to be loaded in $Drive"
}

Write-Host "Burning Disc 1 ISO to $Drive"
Write-Host "ISO: $iso"
Start-Process -FilePath $burner -ArgumentList @("/Q", $Drive, $iso) -Wait
Write-Host "isoburn.exe returned. Check the drive tray/status for burn completion."
