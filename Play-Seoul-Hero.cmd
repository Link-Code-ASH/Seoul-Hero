@echo off
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0godot\tools\play.ps1" -Screen lobby %*
if errorlevel 1 pause
