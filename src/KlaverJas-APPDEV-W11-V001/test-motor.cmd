@echo off
REM Draait de motor zonder scherm: 2000 spellen met vast toevalszaad.
REM "test-motor.cmd spoor 200 1 spoor-nieuw.txt" schrijft een spoor dat je met
REM Documentatie\spoor-csharp.txt kunt vergelijken om te zien of er niets is verschoven.

setlocal
set DOTNET=%USERPROFILE%\.dotnet\dotnet.exe
if not exist "%DOTNET%" set DOTNET=dotnet

cd /d "%~dp0"
"%DOTNET%" run --project KlaverjasTest -c Release -- %*
endlocal
