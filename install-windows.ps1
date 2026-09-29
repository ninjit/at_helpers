param(
    [string]$InstallDirectory = (Join-Path $env:USERPROFILE 'AcousticsToolbox'),
    [string]$Msys2Root = 'C:\msys64'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$toolboxUrl = 'http://oalib.hlsresearch.com/AcousticsToolbox/at_2026_8_29.zip'
$msys2InstallerUrl = 'https://github.com/msys2/msys2-installer/releases/latest/download/msys2-x86_64-latest.exe'
$workingDirectory = Join-Path $env:TEMP ('at-setup-' + [guid]::NewGuid().ToString('N'))
$archivePath = Join-Path $workingDirectory 'acoustics-toolbox.zip'
$extractionDirectory = Join-Path $workingDirectory 'extracted'

function Wait-ForAcknowledgement {
    param([string]$Message)
    [void](Read-Host $Message)
}

function Invoke-Msys2 {
    param([string]$Command)

    & $script:msys2Shell -ucrt64 -defterm -no-start -c $Command
    if ($LASTEXITCODE -ne 0) {
        throw "MSYS2 command failed with exit code ${LASTEXITCODE}: $Command"
    }
}

try {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'Makefile.win'))) {
        throw 'Makefile.win must be in the same folder as this script.'
    }

    if (Test-Path -LiteralPath $InstallDirectory) {
        $existingContent = Get-ChildItem -LiteralPath $InstallDirectory -Force | Select-Object -First 1
        if ($null -ne $existingContent) {
            throw "Install directory is not empty: $InstallDirectory"
        }
    }
    else {
        New-Item -ItemType Directory -Path $InstallDirectory | Out-Null
    }

    New-Item -ItemType Directory -Path $workingDirectory, $extractionDirectory | Out-Null

    Write-Host "Downloading Acoustic Toolbox from $toolboxUrl"
    Wait-ForAcknowledgement 'Press Enter to download and extract the Acoustic Toolbox.'
    Invoke-WebRequest -Uri $toolboxUrl -OutFile $archivePath
    Expand-Archive -LiteralPath $archivePath -DestinationPath $extractionDirectory

    $candidateRoots = @((Get-Item -LiteralPath $extractionDirectory)) + @(
        Get-ChildItem -LiteralPath $extractionDirectory -Directory -Recurse
    )
    $toolboxRoot = $candidateRoots | Where-Object {
        (Test-Path -LiteralPath (Join-Path $_.FullName 'misc')) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'tslib')) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'Bellhop')) -and
        (Test-Path -LiteralPath (Join-Path $_.FullName 'Kraken'))
    } | Select-Object -First 1

    if ($null -eq $toolboxRoot) {
        throw 'Could not locate the expected Acoustic Toolbox folders in the downloaded archive.'
    }

    Get-ChildItem -LiteralPath $toolboxRoot.FullName -Force |
        Copy-Item -Destination $InstallDirectory -Recurse -Force

    $makefilePath = Join-Path $InstallDirectory 'Makefile'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Makefile.win') -Destination $makefilePath -Force

    $msys2Bash = Join-Path $Msys2Root 'usr\bin\bash.exe'
    $script:msys2Shell = Join-Path $Msys2Root 'msys2_shell.cmd'
    if (-not (Test-Path -LiteralPath $msys2Bash)) {
        $installerPath = Join-Path $workingDirectory 'msys2-installer.exe'
        Write-Host "MSYS2 will be installed at $Msys2Root. Use that installation directory in the installer window."
        Wait-ForAcknowledgement 'Press Enter to download and launch the MSYS2 installer.'
        Invoke-WebRequest -Uri $msys2InstallerUrl -OutFile $installerPath
        Start-Process -FilePath $installerPath -Wait
        Wait-ForAcknowledgement 'After the MSYS2 installer finishes, press Enter to continue.'

        if (-not (Test-Path -LiteralPath $msys2Bash)) {
            throw "MSYS2 was not found at $Msys2Root. Re-run this script with -Msys2Root set to the installation directory."
        }
    }

    Write-Host 'Updating MSYS2 packages. The pacman prompts will appear in this terminal.'
    Wait-ForAcknowledgement 'Press Enter to run the first MSYS2 update.'
    Invoke-Msys2 'pacman -Syu'

    Write-Host 'MSYS2 recommends a second update after the first update completes.'
    Wait-ForAcknowledgement 'Press Enter to run the second MSYS2 update.'
    Invoke-Msys2 'pacman -Syu'

    Wait-ForAcknowledgement 'Press Enter to install GNU make, GCC, and GFortran.'
    Invoke-Msys2 'pacman -S --needed make mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-gcc-fortran'

    $msysInstallDirectory = (& (Join-Path $Msys2Root 'usr\bin\cygpath.exe') -u $InstallDirectory).Trim()
    if ($LASTEXITCODE -ne 0) {
        throw 'Could not convert the installation path for MSYS2.'
    }

    $quotedInstallDirectory = $msysInstallDirectory.Replace("'", "'\''")
    Write-Host "Building in $InstallDirectory"
    Wait-ForAcknowledgement 'Press Enter to clean and compile the Acoustic Toolbox.'
    Invoke-Msys2 "cd '$quotedInstallDirectory' && make clean && make install"

    Write-Host "Build complete. Toolbox files are in $InstallDirectory"
    Write-Host 'Compiler and make commands are available inside the MSYS2 UCRT64 environment.'
}
finally {
    if (Test-Path -LiteralPath $workingDirectory) {
        Remove-Item -LiteralPath $workingDirectory -Recurse -Force
    }
}