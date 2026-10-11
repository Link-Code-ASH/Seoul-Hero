@echo off
cd /d "%~dp0.."
set "GODOT=C:\Users\geniu\Documents\GitHub\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist exports mkdir exports
"%GODOT%" --headless --path . --import > "exports\loot-shower-import.log" 2>&1
"%GODOT%" --path . res://tools/loot_shower_capture.tscn -- --ui-preview --output=res://exports/loot-shower > "exports\loot-shower.log" 2>&1
