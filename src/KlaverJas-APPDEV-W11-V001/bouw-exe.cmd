@echo off
REM Bouwt Klaverjas.exe voor Windows 11 (64-bit).
REM Resultaat: Klaverjas-app\Klaverjas.exe -- een enkel bestand van ca. 162 MB
REM dat op elke Windows 11-machine draait; .NET hoeft er niet op staan.

setlocal
set DOTNET=%USERPROFILE%\.dotnet\dotnet.exe
if not exist "%DOTNET%" set DOTNET=dotnet

cd /d "%~dp0"
"%DOTNET%" publish KlaverjasWin -c Release -r win-x64 --self-contained ^
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true ^
  -o Klaverjas-app
if errorlevel 1 (
  echo.
  echo *** Bouwen mislukt ***
  exit /b 1
)
echo.
echo Klaar: %~dp0Klaverjas-app\Klaverjas.exe
endlocal
