param(
  [string]$EnginePath = ''
)
& (Join-Path $PSScriptRoot 'play.ps1') -EnginePath $EnginePath -Editor
