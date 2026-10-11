[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [ValidateSet('title','lobby','gate','depth','character','weapons','archive','growth','association','offline','supply','guild','settings','graphics','sd-sample')]
    [string]$Screen = 'title',
    [string]$EnginePath = '',
    [switch]$Editor
)

$ErrorActionPreference = 'Stop'
try {
    . (Join-Path $PSScriptRoot 'engine_path.ps1')
    $projectPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
    $engine = Resolve-SeoulHeroEngine -EnginePath $EnginePath -ProjectPath $projectPath
    if (-not $PSCmdlet.ShouldProcess($projectPath, "Launch with $engine")) { return }

    $launcherCache = Join-Path $projectPath '.godot\launcher'
    New-Item -ItemType Directory -Path $launcherCache -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $launcherCache 'engine-path.txt'), $engine)
    $quotedProject = '"{0}"' -f $projectPath
    if ($Editor) {
        # The user explicitly asked to open the visible editor.
        Start-Process -FilePath $engine -ArgumentList @('--editor', '--path', $quotedProject)
        return
    }

    # A fresh clone has no .godot/imported cache. Incremental import also picks up
    # new assets after Pull; no editor window or user save is opened by this step.
    Write-Host 'Preparing game assets...'
    $importLog = Join-Path $launcherCache 'import.log'
    $importProcess = Start-Process -FilePath $engine -ArgumentList @(
        '--headless', '--path', $quotedProject, '--editor', '--import',
        '--log-file', ('"{0}"' -f $importLog)
    ) -WindowStyle Hidden -Wait -PassThru
    if ($importProcess.ExitCode -ne 0) {
        throw "Godot asset import failed. See $importLog"
    }
    $gameArguments = @('--path', $quotedProject)
    if ($Screen -ne 'title') { $gameArguments += @('--', "--open=$Screen") }
    # The requested game opens normally; the CMD helper can now close.
    Start-Process -FilePath $engine -ArgumentList $gameArguments
} catch {
    Write-Error -Message $_.Exception.Message -ErrorAction Continue
    exit 1
}
