@echo off
setlocal

pushd "%~dp0" >nul
if errorlevel 1 (
    echo ERROR: Could not open the project directory.
    exit /b 1
)

where dotnet >nul 2>nul
if errorlevel 1 (
    echo ERROR: The dotnet command was not found.
    echo Install the .NET 10 SDK and run this file again.
    goto :failure
)

for /f "tokens=1 delims=." %%V in ('dotnet --version 2^>nul') do set "DOTNET_MAJOR=%%V"
if not "%DOTNET_MAJOR%"=="10" (
    echo ERROR: This project requires the .NET 10 SDK.
    echo Detected SDK: 
    dotnet --version
    goto :failure
)

echo Building the Disc Image Studio single-file release executable...
echo.

if "%~1"=="" (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0packaging\Build-Release.ps1"
) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0packaging\Build-Release.ps1" -Tag "%~1"
)

if errorlevel 1 goto :failure

echo.
echo Build completed successfully.
echo The executable and SHA256SUMS.txt are under artifacts\release.
popd >nul
exit /b 0

:failure
echo.
echo Build failed.
popd >nul
exit /b 1
