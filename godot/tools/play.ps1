param(
    [ValidateSet('title','lobby','gate','depth','character','weapons','archive','growth','association','offline','supply','guild','settings','graphics','sd-sample')]
    [string]$Screen = 'title',
    [string]$EnginePath = 'C:\Users\geniu\Documents\GitHub\Godot\Godot_v4.7.2-stable_win64.exe'
)

$projectPath = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $EnginePath)) {
    throw 'Godot executable not found. Specify -EnginePath with its current location.'
}
# Launch the actual native project. No browser mockup or save reset is involved.
if ($Screen -eq 'title') {
    & $EnginePath --path $projectPath
} else {
    & $EnginePath --path $projectPath -- "--open=$Screen"
}
