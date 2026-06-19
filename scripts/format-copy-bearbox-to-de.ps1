param(
    [string]$Root = "C:\Users\rxcam\news-rapper\dvd5-refresh-disc"
)

$ErrorActionPreference = "Stop"

$log = Join-Path $Root "out\format-copy-bearbox-to-de.log"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $log) | Out-Null
Start-Transcript -Path $log -Force | Out-Null

try {
    $targets = @(
        @{
            Letter = "D"
            Disk = 1
            Partition = 1
            Label = "BEARBOX_D1"
            Iso = Join-Path $Root "out\bearbox-disc1-install-refresh.iso"
        },
        @{
            Letter = "E"
            Disk = 1
            Partition = 2
            Label = "BEARBOX_D2"
            Iso = Join-Path $Root "out\bearbox-disc2-live-runtime-key.iso"
        }
    )

    foreach ($target in $targets) {
        $part = Get-Partition -DriveLetter $target.Letter
        if ($part.DiskNumber -ne $target.Disk -or $part.PartitionNumber -ne $target.Partition) {
            throw "Refusing to format $($target.Letter): expected Disk $($target.Disk) Partition $($target.Partition), got Disk $($part.DiskNumber) Partition $($part.PartitionNumber)."
        }
        if ($target.Letter -in @("C", "F", "G")) {
            throw "Refusing unsafe drive letter $($target.Letter)."
        }
        if (-not (Test-Path -LiteralPath $target.Iso)) {
            throw "Missing ISO: $($target.Iso)"
        }
    }

    foreach ($target in $targets) {
        Write-Host "Formatting $($target.Letter): as $($target.Label) FAT32"
        Format-Volume -DriveLetter $target.Letter -FileSystem FAT32 -NewFileSystemLabel $target.Label -Confirm:$false -Force | Out-Null
    }

    function Copy-IsoToDrive {
        param(
            [Parameter(Mandatory = $true)][string]$Iso,
            [Parameter(Mandatory = $true)][string]$Destination
        )

        Write-Host "Mounting $Iso"
        $image = Mount-DiskImage -ImagePath $Iso -PassThru
        try {
            Start-Sleep -Seconds 2
            $volume = $image | Get-Volume
            if (-not $volume.DriveLetter) {
                throw "Mounted ISO has no drive letter: $Iso"
            }
            $source = "$($volume.DriveLetter):\"
            Write-Host "Copying $source to $Destination"
            robocopy $source $Destination /E /COPY:DAT /R:2 /W:2
            $code = $LASTEXITCODE
            if ($code -gt 7) {
                throw "robocopy failed from $source to $Destination with exit code $code"
            }
        }
        finally {
            Dismount-DiskImage -ImagePath $Iso | Out-Null
        }
    }

    Copy-IsoToDrive -Iso $targets[0].Iso -Destination "D:\"
    Copy-IsoToDrive -Iso $targets[1].Iso -Destination "E:\"

    Copy-Item -LiteralPath (Join-Path $Root "scripts\verbose-disc1-grub.cfg") -Destination "D:\BOOT\GRUB\GRUB.CFG" -Force
    Copy-Item -LiteralPath (Join-Path $Root "disc1\README-BEARBOX-DISC1.txt") -Destination "D:\README-BEARBOX-DISC1.TXT" -Force
    Set-Content -LiteralPath "D:\BEARBOX_PARTITION_SOURCE.txt" -Encoding ascii -Value "BEARBOX_D1 copied to fixed partition D: with verbose fallback GRUB menu."
    Set-Content -LiteralPath "E:\BEARBOX_PARTITION_SOURCE.txt" -Encoding ascii -Value "BEARBOX_D2 copied to fixed partition E:."

    Write-Host "Verification:"
    Get-Volume -DriveLetter D,E | Select-Object DriveLetter,FileSystemLabel,FileSystem,SizeRemaining,Size | Format-Table -AutoSize
    Get-ChildItem D:\ | Select-Object Mode,Length,Name | Format-Table -AutoSize
    Get-ChildItem E:\ | Select-Object Mode,Length,Name | Format-Table -AutoSize
    Get-Content D:\BOOT\GRUB\GRUB.CFG | Select-Object -First 60

    Write-Host "BearBox D:/E: partition copy complete."
}
finally {
    Stop-Transcript | Out-Null
}
