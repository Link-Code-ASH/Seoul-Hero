@echo off
cd /d "%~dp0.."
set "GODOT=C:\Users\geniu\Documents\GitHub\Godot\Godot_v4.7.2-stable_win64.exe"
if not exist exports mkdir exports
"%GODOT%" --headless --path . --import > "exports\night-ops-more-import.log" 2>&1
"%GODOT%" --path . res://tools/guild_office_preview.tscn -- --ui-preview --output=res://exports/night-ops-guild > "exports\night-ops-guild.log" 2>&1
"%GODOT%" --path . res://tools/economy_preview.tscn -- --ui-preview --output=res://exports/night-ops-economy > "exports\night-ops-economy.log" 2>&1
