# Shared by the game and editor launchers. Machine paths stay in ignored cache.
function Resolve-SeoulHeroEngine {
    param([string]$EnginePath, [string]$ProjectPath)

    if (-not [string]::IsNullOrWhiteSpace($EnginePath)) {
        if (-not (Test-Path -LiteralPath $EnginePath -PathType Leaf) -or
            [System.IO.Path]::GetExtension($EnginePath) -ne '.exe') {
            throw 'Godot executable not found. Supply an executable with -EnginePath.'
        }
        return (Resolve-Path -LiteralPath $EnginePath).Path
    }

    $cacheFile = Join-Path $ProjectPath '.godot\launcher\engine-path.txt'
    if (Test-Path -LiteralPath $cacheFile -PathType Leaf) {
        $cachedPath = [System.IO.File]::ReadAllText($cacheFile).Trim()
        if (Test-Path -LiteralPath $cachedPath -PathType Leaf) {
            return (Resolve-Path -LiteralPath $cachedPath).Path
        }
    }

    $candidates = New-Object 'System.Collections.Generic.List[string]'
    foreach ($name in @('Godot_v4.7.2-stable_win64.exe', 'Godot_v4.7.2-stable_win64_console.exe')) {
        $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($null -ne $command) { [void]$candidates.Add($command.Source) }
    }

    $repositoryPath = Split-Path -Parent $ProjectPath
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $profilePath = [Environment]::GetFolderPath('UserProfile')
    $roots = @(
        (Join-Path $repositoryPath 'Godot'),
        (Join-Path (Split-Path -Parent $repositoryPath) 'Godot'),
        (Split-Path -Parent $repositoryPath),
        (Join-Path $documentsPath 'Godot'),
        (Join-Path $profilePath 'Downloads'),
        (Join-Path ([Environment]::GetFolderPath('Desktop')) 'Godot')
    ) | Select-Object -Unique
    foreach ($directory in $roots) {
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }
        $folders = @($directory)
        $folders += @(Get-ChildItem -LiteralPath $directory -Directory -Filter 'Godot*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
        foreach ($folder in $folders) {
            $files = Get-ChildItem -LiteralPath $folder -File -Filter 'Godot_v4.7.2-stable_win*.exe' -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch 'mono|dotnet' } |
                Sort-Object @{Expression={ $_.Name -like '*_console.exe' }}, FullName
            foreach ($file in $files) { [void]$candidates.Add($file.FullName) }
        }
    }
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }

    Add-Type -AssemblyName System.Windows.Forms
    $picker = New-Object System.Windows.Forms.OpenFileDialog
    $picker.Title = 'Select Godot 4.7.2 Standard executable (extract the ZIP first)'
    $picker.Filter = 'Godot executable (Godot*.exe)|Godot*.exe|Executable (*.exe)|*.exe'
    $picker.CheckFileExists = $true
    $picker.Multiselect = $false
    $picker.InitialDirectory = Join-Path $profilePath 'Downloads'
    try {
        if ($picker.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
            throw 'No engine selected. Extract Godot 4.7.2 Standard, then run this launcher again.'
        }
        return $picker.FileName
    } finally {
        $picker.Dispose()
    }
}
