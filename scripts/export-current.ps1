param(
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }),
  [switch]$SkipConfig,
  [switch]$SkipSafetyCheck
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Get-RelativePathCompat {
  param(
    [string]$BasePath,
    [string]$FullPath
  )

  $baseResolved = (Resolve-Path -LiteralPath $BasePath).Path.TrimEnd("\", "/")
  $fullResolved = (Resolve-Path -LiteralPath $FullPath).Path
  return $fullResolved.Substring($baseResolved.Length).TrimStart("\", "/")
}

function Test-ExcludedSkillFile {
  param(
    [string]$RelativePath,
    [System.IO.FileInfo]$File
  )

  $excludedDirectories = @(
    ".git",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    ".tox",
    ".venv",
    "__pycache__",
    "node_modules"
  )
  $segments = $RelativePath -split "[\\/]"
  if ($segments[0] -eq ".system") {
    return $true
  }
  foreach ($segment in $segments) {
    if ($excludedDirectories -contains $segment) {
      return $true
    }
  }

  $name = $File.Name
  if ($name -in @("auth.json", ".DS_Store", "Thumbs.db")) {
    return $true
  }
  if ($name -like ".env*" -and $name -notin @(".env.example", ".env.sample")) {
    return $true
  }
  if ($name -match "\.(key|pem|p12|pfx|pyc|pyo|log)$") {
    return $true
  }
  if ($name -match "\.sqlite(?:-.+)?$") {
    return $true
  }

  return $false
}

function Copy-PortableFile {
  param(
    [string]$Source,
    [string]$Destination
  )

  $bytes = [IO.File]::ReadAllBytes($Source)
  if ($bytes -contains 0) {
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
    return
  }

  try {
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    $text = $strictUtf8.GetString($bytes)
    $normalized = $text.Replace("`r`n", "`n").Replace("`r", "`n")
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Destination, $normalized, $utf8NoBom)
  } catch [System.Text.DecoderFallbackException] {
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
  }
}

$agentsSrc = Join-Path $CodexHome "AGENTS.md"
if (Test-Path -LiteralPath $agentsSrc) {
  Copy-PortableFile -Source $agentsSrc -Destination (Join-Path $repoRoot "AGENTS.md")
}

$skillsSrc = Join-Path $CodexHome "skills"
$skillsDst = Join-Path $repoRoot "skills"
if (Test-Path -LiteralPath $skillsSrc) {
  $repoFull = (Resolve-Path -LiteralPath $repoRoot).Path.TrimEnd("\", "/")
  $skillsDstFull = [IO.Path]::GetFullPath($skillsDst).TrimEnd("\", "/")
  if (-not $skillsDstFull.StartsWith("$repoFull\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to replace skills outside the repository: $skillsDstFull"
  }

  if (Test-Path -LiteralPath $skillsDst) {
    Get-ChildItem -LiteralPath $skillsDst -Force | Remove-Item -Recurse -Force
  } else {
    New-Item -ItemType Directory -Path $skillsDst -Force | Out-Null
  }

  $copied = 0
  Get-ChildItem -LiteralPath $skillsSrc -Recurse -File -Force | ForEach-Object {
    $relativePath = Get-RelativePathCompat -BasePath $skillsSrc -FullPath $_.FullName
    if (Test-ExcludedSkillFile -RelativePath $relativePath -File $_) {
      return
    }

    $destination = Join-Path $skillsDst $relativePath
    $destinationParent = Split-Path $destination -Parent
    New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    Copy-PortableFile -Source $_.FullName -Destination $destination
    $copied++
  }
}

if (-not $SkipConfig) {
  & (Join-Path $PSScriptRoot "export-safe-config.ps1") -CodexHome $CodexHome
}

& (Join-Path $PSScriptRoot "generate-skill-index.ps1") -CodexHome $CodexHome

if (-not $SkipSafetyCheck) {
  & (Join-Path $PSScriptRoot "check-public-safety.ps1")
}

Write-Host "Exported AGENTS.md, $copied user-owned skill files, safe config preferences, and managed skill indexes from $CodexHome"
