param(
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }),
  [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $OutputPath = Join-Path $repoRoot "config\config.toml.template"
}

$sourcePath = Join-Path $CodexHome "config.toml"
if (-not (Test-Path -LiteralPath $sourcePath)) {
  throw "Codex config not found: $sourcePath"
}

function Read-SimpleToml {
  param([string]$Path)

  $sections = [ordered]@{}
  $sections[""] = [ordered]@{}
  $currentSection = ""

  foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $Path) {
    $trimmed = $line.Trim()
    if ($trimmed -match "^\[(.+)\]$") {
      $currentSection = $Matches[1]
      if (-not $sections.Contains($currentSection)) {
        $sections[$currentSection] = [ordered]@{}
      }
      continue
    }

    if ($trimmed -match "^([A-Za-z0-9_.-]+)\s*=\s*(.+)$") {
      $sections[$currentSection][$Matches[1]] = $Matches[2].Trim()
    }
  }

  return $sections
}

function Add-SelectedKeys {
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [System.Collections.IDictionary]$Section,
    [string[]]$Keys
  )

  foreach ($key in $Keys) {
    if ($Section.Contains($key)) {
      $Lines.Add("$key = $($Section[$key])")
    }
  }
}

$config = Read-SimpleToml -Path $sourcePath
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Personal Codex defaults shared across machines.")
$lines.Add("# Machine-generated runtime paths, auth, cache, sessions, logs, and secrets are intentionally excluded.")
$lines.Add("")

$topKeys = @("model", "model_provider", "model_reasoning_effort", "personality", "service_tier")
Add-SelectedKeys -Lines $lines -Section $config[""] -Keys $topKeys

$provider = ""
if ($config[""].Contains("model_provider")) {
  $provider = $config[""]["model_provider"].Trim().Trim('"').Trim("'")
}
if (-not [string]::IsNullOrWhiteSpace($provider)) {
  $providerSection = "model_providers.$provider"
  if ($config.Contains($providerSection)) {
    $lines.Add("")
    $lines.Add("[$providerSection]")
    Add-SelectedKeys `
      -Lines $lines `
      -Section $config[$providerSection] `
      -Keys @("name", "wire_api", "requires_openai_auth", "supports_websockets")
  }
}

$sectionKeys = [ordered]@{
  "desktop" = @(
    "conversationDetailMode",
    "ambient-suggestions-enabled",
    "appearanceTheme",
    "keepRemoteControlAwakeWhilePluggedIn",
    "followUpQueueMode"
  )
  "windows" = @("sandbox")
}

foreach ($sectionName in $sectionKeys.Keys) {
  if ($config.Contains($sectionName)) {
    $lines.Add("")
    $lines.Add("[$sectionName]")
    Add-SelectedKeys -Lines $lines -Section $config[$sectionName] -Keys $sectionKeys[$sectionName]
  }
}

if ($config.Contains("features")) {
  $lines.Add("")
  $lines.Add("[features]")
  foreach ($key in ($config["features"].Keys | Sort-Object)) {
    $value = $config["features"][$key]
    if ($value -match "^(true|false)$") {
      $lines.Add("$key = $value")
    }
  }
}

$pluginSections = @($config.Keys | Where-Object { $_ -match '^plugins\.' } | Sort-Object)
foreach ($sectionName in $pluginSections) {
  $section = $config[$sectionName]
  if ($section.Contains("enabled") -and $section["enabled"] -match "^(true|false)$") {
    $lines.Add("")
    $lines.Add("[$sectionName]")
    $lines.Add("enabled = $($section["enabled"])")
  }
}

$lines.Add("")
$lines.Add("# Optional local MCP example. Keep keys out of Git.")
$lines.Add("# Uncomment and fill locally after sync if needed.")
$lines.Add("#")
$lines.Add("# [mcp_servers.example]")
$lines.Add('# url = "http://127.0.0.1:3501/mcp"')
$lines.Add('# http_headers = { "x-mcp-key" = "PUT_LOCAL_KEY_HERE" }')
$lines.Add("# startup_timeout_sec = 20")
$lines.Add("# tool_timeout_sec = 60")
$lines.Add("# enabled = true")
$lines.Add('# default_tools_approval_mode = "prompt"')

$outputParent = Split-Path $OutputPath -Parent
New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText($OutputPath, ($lines -join "`n") + "`n", $utf8NoBom)
Write-Host "Exported safe config template to $OutputPath"
