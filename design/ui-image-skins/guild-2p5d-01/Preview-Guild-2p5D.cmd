@echo off
setlocal
set "GUILD_PREVIEW_ROOT=%~dp0"
set "GUILD_PREVIEW_ENGINE=C:\Users\geniu\Documents\GitHub\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GUILD_PREVIEW_ENGINE%" (
  echo Godot 4.7.2 engine was not found.
  pause
  exit /b 1
)
start "" "%GUILD_PREVIEW_ENGINE%" --path "%GUILD_PREVIEW_ROOT%" -- --expanded
endlocal
