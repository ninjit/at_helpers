# Acoustic Toolbox Windows setup

This folder contains a Windows Makefile and a PowerShell script for downloading,
configuring, and compiling the Acoustic Toolbox with the MSYS2 UCRT64 toolchain.
The provider distributes the source as a ZIP archive rather than a Git repository.

## Requirements

- 64-bit Windows
- An internet connection
- The three files in this folder kept together: `install-windows.ps1`,
  `Makefile.win`, and this README

## Run the setup

Open PowerShell in this folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

By default, the toolbox is extracted to `%USERPROFILE%\AcousticsToolbox` and
MSYS2 is installed at `C:\msys64`. The toolbox folder must not already contain
files. To choose another toolbox folder or an existing MSYS2 installation, use:

```powershell
.\install-windows.ps1 -InstallDirectory 'D:\AcousticsToolbox' -Msys2Root 'D:\msys64'
```

The script pauses before each major action. The MSYS2 installer opens as a
separate window; use the MSYS2 root path printed by the script when installing.
In the terminal, `pacman` may ask for confirmation while updating and installing
packages. The script updates MSYS2 twice, installs GNU make, GCC, and GFortran,
replaces the downloaded top-level Makefile with `Makefile.win`, then runs
`make clean` and `make install` in the MSYS2 UCRT64 environment.

The compiler and make are available from that MSYS2 environment. The script does
not add MSYS2 directories to the Windows-wide PATH, avoiding conflicts with
other Windows tools.

## Build choices and limitations

`Makefile.win` uses the UCRT64 `gcc` and `gfortran` compilers and optimization
flags suitable for a general Windows build. It builds Bellhop, Kraken,
KrakenField, and Scooter. Krakel is omitted because it requires LAPACK and is
not enabled by the supplied macOS Makefile. The `clean` target removes generated
build and model-output files within the toolbox source tree.

The toolbox archive URL is HTTP, as provided by the project website, and this
script does not verify a published checksum. The MSYS2 installer is downloaded
from the official MSYS2 GitHub release endpoint. Review both sources and the
script before running it.

This setup has not been run or tested on Windows yet. Validate it on a clean
Windows machine before distributing it to others.