@echo off
setlocal enabledelayedexpansion

set ISO=%1
if "%ISO%"=="" (
    for %%F in (..\out\*.iso) do set ISO=%%F
)

if "%ISO%"=="" (
    echo Error: No ISO file found in ..\out.
    echo Usage: test_qemu.bat [path_to_iso]
    pause
    exit /b 1
)

echo Starting QEMU for %ISO%...
qemu-system-x86_64.exe -m 4G -smp 4 -vga virtio -cdrom "%ISO%" -boot d
