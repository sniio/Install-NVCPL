# Install-NVCPL
A simple PowerShell script to install the NVIDIA Control Panel as a Win32 App!

## Usage
Run the packaged installer as an Administrator:
```ps
.\Install-NVCPL.exe
```

Or run the script directly after keeping `Install-NVCPL.ps1` and `nvcpluir.dll` in the same folder:
```ps
.\Install-NVCPL.ps1
```

## Build Single EXE
The packaged EXE embeds `Install-NVCPL.ps1` and `nvcpluir.dll`:
```ps
.\build-exe.ps1
```

## Build NVIDIA Control Panel Service Launcher
The repository includes a prebuilt `nvcpluir.dll`. To rebuild it:

1. Install `GCC` and [`UPX`](https://upx.github.io/).
2. Run `build.bat`.
3. Keep the generated `nvcpluir.dll` beside `Install-NVCPL.ps1`.
