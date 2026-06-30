param(
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" })
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

$agentsSrc = Join-Path $CodexHome "AGENTS.md"
if (Test-Path -LiteralPath $agentsSrc) {
  Copy-Item -LiteralPath $agentsSrc -Destination (Join-Path $repoRoot "AGENTS.md") -Force
}

$skillsSrc = Join-Path $CodexHome "skills"
$skillsDst = Join-Path $repoRoot "skills"
if (Test-Path -LiteralPath $skillsSrc) {
  if (Test-Path -LiteralPath $skillsDst) {
    Get-ChildItem -LiteralPath $skillsDst -Force | Remove-Item -Recurse -Force
  } else {
    New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null
  }

  Get-ChildItem -LiteralPath $skillsSrc -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $skillsDst -Recurse -Force
  }
}

& (Join-Path $PSScriptRoot "generate-skill-index.ps1") -CodexHome $CodexHome

Write-Host "Exported AGENTS.md and skills from $CodexHome"
Write-Host "Config template is not auto-regenerated because local config may contain secrets and machine-specific paths."
