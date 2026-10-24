@echo off
setlocal
set "GAME_EXE=%~dp0tools\godot-4.7.2\Godot_v4.7.2-stable_win64.exe"
if not exist "%GAME_EXE%" (
	echo Godot 4.7.2 executable was not found:
	echo %GAME_EXE%
	pause
	exit /b 1
)
start "PROJECT: REFLECTION" "%GAME_EXE%" --path "%~dp0."
