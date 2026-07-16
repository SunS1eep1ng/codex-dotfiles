param(
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }),
  [switch]$SkipConfig,
  [switch]$MirrorSkills
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

function Backup-File {
  param([string]$Path)
  if (Test-Path -LiteralPath $Path) {
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$timestamp" -Force
  }
}

function Assert-ChildPath {
  param(
    [string]$Child,
    [string]$Parent
  )
  $childResolved = (Resolve-Path -LiteralPath $Child).Path.TrimEnd('\', '/')
  $parentResolved = (Resolve-Path -LiteralPath $Parent).Path.TrimEnd('\', '/')
  if (-not $childResolved.StartsWith($parentResolved, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to modify path outside CodexHome: $childResolved"
  }
}

New-Item -ItemType Directory -Path $CodexHome -Force | Out-Null

$agentsSrc = Join-Path $repoRoot "AGENTS.md"
$agentsDst = Join-Path $CodexHome "AGENTS.md"
Backup-File $agentsDst
Copy-Item -LiteralPath $agentsSrc -Destination $agentsDst -Force

if (-not $SkipConfig) {
  $configSrc = Join-Path $repoRoot "config\config.toml.template"
  $configDst = Join-Path $CodexHome "config.toml"
  Backup-File $configDst
  Copy-Item -LiteralPath $configSrc -Destination $configDst -Force
}

$skillsSrc = Join-Path $repoRoot "skills"
$skillsDst = Join-Path $CodexHome "skills"
New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null

if ($MirrorSkills) {
  Assert-ChildPath -Child $skillsDst -Parent $CodexHome
  Get-ChildItem -LiteralPath $skillsDst -Force |
    Where-Object { $_.Name -ne ".system" } |
    Remove-Item -Recurse -Force
}

Get-ChildItem -LiteralPath $skillsSrc -Force | ForEach-Object {
  Copy-Item -LiteralPath $_.FullName -Destination $skillsDst -Recurse -Force
}

Write-Host "Synced Codex dotfiles to $CodexHome"
Write-Host "Backups use suffix .bak-$timestamp"
if ($MirrorSkills) {
  Write-Host "Mirrored user-owned skills; preserved the version-bound .system directory."
}
if (-not $SkipConfig) {
  Write-Host "Review local MCP secrets after config sync; real keys are intentionally not stored in this repo."
}
