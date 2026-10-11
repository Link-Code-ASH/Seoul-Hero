@echo off
rem Night-operations UI check: import new art, then capture production screens without save writes.
cd /d "%~dp0.."
set "GODOT=C:\Users\geniu\Documents\GitHub\Godot\Godot_v4.7.2-stable_win64.exe"
set "OUT=%~1"
if "%OUT%"=="" set "OUT=night-ops-capture"
if not exist exports mkdir exports
"%GODOT%" --headless --path . --import > "exports\%OUT%-import.log" 2>&1
"%GODOT%" --path . res://tools/image_skin_capture.tscn -- --ui-preview --output=res://exports/%OUT% > "exports\%OUT%.log" 2>&1
