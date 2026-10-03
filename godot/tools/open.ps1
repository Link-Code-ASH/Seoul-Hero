param(
  [string]$EnginePath = 'C:\Users\geniu\Documents\GitHub\Godot\Godot_v4.7.2-stable_win64.exe'
)
$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf)) {
  throw 'Godot 실행 파일을 찾을 수 없습니다. -EnginePath로 파일 경로를 지정하세요.'
}
# This is intentionally an interactive editor opened by the player.
& $EnginePath --editor --path $projectDirectory
