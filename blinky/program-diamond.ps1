[CmdletBinding()]
param(
    [string]$DiamondRoot = "",
    [ValidateRange(1, 5)]
    [int]$Attempts = 3
)

$ErrorActionPreference = "Stop"

$projectDir = $PSScriptRoot
$bitstream = [IO.Path]::GetFullPath((Join-Path $projectDir "build\Top.bit"))
$xcfTemplate = Join-Path $projectDir "Top.diamond.xcf"
$logFile = Join-Path $projectDir "build\diamond-program.log"

if (-not (Test-Path -LiteralPath $bitstream)) {
    throw "Bitstream is missing: $bitstream"
}
if (-not (Test-Path -LiteralPath $xcfTemplate)) {
    throw "Diamond Programmer project is missing: $xcfTemplate"
}

if ([string]::IsNullOrWhiteSpace($DiamondRoot)) {
    $registryRoots = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $installedRoot = Get-ItemProperty $registryRoots -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "Lattice Diamond*" } |
        Select-Object -ExpandProperty InstallLocation -First 1
    $candidates = @($installedRoot, "E:\lattice", "C:\lattice") |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    $DiamondRoot = $candidates |
        Where-Object { Test-Path -LiteralPath (Join-Path $_ "bin\nt64\pgrcmd.exe") } |
        Select-Object -First 1
}

if ([string]::IsNullOrWhiteSpace($DiamondRoot)) {
    throw "Lattice Diamond Programmer was not found. Pass -DiamondRoot explicitly."
}

$pgrcmd = Join-Path $DiamondRoot "bin\nt64\pgrcmd.exe"
$env:LSC_INI_PATH = Join-Path $DiamondRoot "data"
$runtimeXcf = Join-Path ([IO.Path]::GetTempPath()) "struo-blinky-$PID.xcf"

$escapedBitstream = [Security.SecurityElement]::Escape($bitstream)
$xcf = (Get-Content -LiteralPath $xcfTemplate -Raw).Replace(
    "<File>build/Top.bit</File>",
    "<File>$escapedBitstream</File>"
)
[IO.File]::WriteAllText($runtimeXcf, $xcf, [Text.UTF8Encoding]::new($false))

try {
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        Write-Host "Diamond Programmer attempt $attempt/$Attempts"
        & $pgrcmd `
            -infile $runtimeXcf `
            -logfile $logFile `
            -processtype sequential `
            -cabletype usb2 `
            -portaddress FTUSB-0 `
            -TCK 10

        if ($LASTEXITCODE -eq 0) {
            Write-Host "SRAM programming completed successfully."
            exit 0
        }
        if ($attempt -lt $Attempts) {
            Start-Sleep -Seconds 2
        }
    }

    if ((Test-Path -LiteralPath $logFile) -and
        (Get-Content -LiteralPath $logFile -Raw) -match "Read: 0x7FFFFFFF") {
        Write-Warning "JTAG is not responding. Press board button SW3 (PROGRAMN), or power-cycle the board, then retry."
    }
    throw "Diamond Programmer failed after $Attempts attempts. See $logFile"
}
finally {
    Remove-Item -LiteralPath $runtimeXcf -Force -ErrorAction SilentlyContinue
}
