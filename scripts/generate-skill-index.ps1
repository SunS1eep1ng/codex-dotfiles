param(
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" })
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "skill-export-policy.ps1")
$docsDir = Join-Path $repoRoot "docs"
New-Item -ItemType Directory -Path $docsDir -Force | Out-Null

function Escape-MarkdownCell {
  param([string]$Value)
  if ($null -eq $Value) { return "" }
  return (($Value -replace "`r?`n", " ") -replace "\|", "\|").Trim()
}

function Get-FrontmatterValue {
  param(
    [string[]]$Lines,
    [string]$Key
  )

  for ($i = 0; $i -lt $Lines.Count; $i++) {
    $line = $Lines[$i]
    if ($line -match "^\s*$([regex]::Escape($Key)):\s*(.*)$") {
      $value = $Matches[1].Trim()
      if ($value -eq ">-" -or $value -eq "|-" -or $value -eq ">" -or $value -eq "|") {
        $parts = New-Object System.Collections.Generic.List[string]
        for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
          $next = $Lines[$j]
          if ($next -match "^\S[\w-]*:\s*" -or $next -eq "---") { break }
          if ($next.Trim().Length -gt 0) { $parts.Add($next.Trim()) }
        }
        return ($parts -join " ")
      }
      return ($value.Trim('"').Trim("'"))
    }
  }
  return ""
}

function Get-RelativePathCompat {
  param(
    [string]$BasePath,
    [string]$FullPath
  )

  $baseResolved = (Resolve-Path -LiteralPath $BasePath).Path
  $fullResolved = (Resolve-Path -LiteralPath $FullPath).Path
  if (-not $baseResolved.EndsWith([IO.Path]::DirectorySeparatorChar)) {
    $baseResolved = $baseResolved + [IO.Path]::DirectorySeparatorChar
  }

  $baseUri = New-Object System.Uri($baseResolved)
  $fullUri = New-Object System.Uri($fullResolved)
  return [Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fullUri).ToString())
}

function Get-SkillRecord {
  param(
    [System.IO.FileInfo]$File,
    [string]$BasePath
  )

  $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $File.FullName
  $frontmatter = ""
  if ($text -match "(?s)^---\s*(.*?)\s*---") {
    $frontmatter = $Matches[1]
  }
  $lines = $frontmatter -split "`r?`n"
  $name = Get-FrontmatterValue -Lines $lines -Key "name"
  if ([string]::IsNullOrWhiteSpace($name)) {
    $name = Split-Path (Split-Path $File.FullName -Parent) -Leaf
  }
  $description = Get-FrontmatterValue -Lines $lines -Key "description"
  $relativePath = Get-RelativePathCompat -BasePath $BasePath -FullPath $File.FullName

  [PSCustomObject]@{
    Name = $name
    Description = $description
    Path = $relativePath
    Bytes = $File.Length
  }
}

function Write-SkillMarkdown {
  param(
    [string]$OutputPath,
    [string]$Title,
    [string]$Intro,
    [object[]]$Records
  )

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add("# $Title")
  $lines.Add("")
  $lines.Add($Intro)
  $lines.Add("")
  $lines.Add("Total: $($Records.Count)")
  $lines.Add("")
  $lines.Add("| Name | Description | Path | Size |")
  $lines.Add("| --- | --- | --- | ---: |")
  foreach ($record in ($Records | Sort-Object Name, Path)) {
    $name = Escape-MarkdownCell $record.Name
    $description = Escape-MarkdownCell $record.Description
    $path = Escape-MarkdownCell $record.Path
    $lines.Add("| $name | $description | ``$path`` | $($record.Bytes) |")
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($OutputPath, ($lines -join "`n") + "`n", $utf8NoBom)
}

$skillsRoot = Join-Path $repoRoot "skills"
$installed = @()
if (Test-Path -LiteralPath $skillsRoot) {
  $installed = Get-ChildItem -Recurse -File -Filter "SKILL.md" -LiteralPath $skillsRoot -Force |
    Where-Object {
      $relativeSkillPath = Get-RelativePathCompat -BasePath $skillsRoot -FullPath $_.FullName
      -not (Test-PathUnderTimestampedSkillBackup -RelativePath $relativeSkillPath)
    } |
    ForEach-Object { Get-SkillRecord -File $_ -BasePath $repoRoot }
}

Write-SkillMarkdown `
  -OutputPath (Join-Path $docsDir "installed-skills.md") `
  -Title "Installed Skills Snapshot" `
  -Intro "Skills copied into this repo from `$CODEX_HOME/skills`. These are the files synced by the bootstrap scripts." `
  -Records $installed

$systemSkillsRoot = Join-Path (Join-Path $CodexHome "skills") ".system"
$systemSkills = @()
if (Test-Path -LiteralPath $systemSkillsRoot) {
  $systemSkills = Get-ChildItem -Recurse -File -Filter "SKILL.md" -LiteralPath $systemSkillsRoot -Force |
    ForEach-Object { Get-SkillRecord -File $_ -BasePath $CodexHome }
}

$pluginCache = Join-Path (Join-Path $CodexHome "plugins") "cache"
$pluginSkills = @()
if (Test-Path -LiteralPath $pluginCache) {
  $pluginSkills = Get-ChildItem -Recurse -File -Filter "SKILL.md" -LiteralPath $pluginCache -Force |
    ForEach-Object { Get-SkillRecord -File $_ -BasePath $CodexHome }
}
$managedSkills = @($systemSkills) + @($pluginSkills)

Write-SkillMarkdown `
  -OutputPath (Join-Path $docsDir "official-plugin-skills.md") `
  -Title "Official And Plugin Skills Snapshot" `
  -Intro "Skills discovered under `$CODEX_HOME/skills/.system` and `$CODEX_HOME/plugins/cache`. This is documentation only; each machine should recreate these version-bound skills through Codex and plugin installation." `
  -Records $managedSkills

$manifest = [PSCustomObject]@{
  schemaVersion = 1
  installedSkillCount = $installed.Count
  systemSkillCount = $systemSkills.Count
  pluginSkillCount = $pluginSkills.Count
  officialPluginSkillCount = $managedSkills.Count
  installedSkills = $installed
  systemSkills = $systemSkills
  pluginSkills = $pluginSkills
  officialPluginSkills = $managedSkills
}

$manifestJson = $manifest | ConvertTo-Json -Depth 6
$manifestPath = Join-Path $docsDir "skills-manifest.json"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$manifestJson = $manifestJson.Replace("`r`n", "`n").Replace("`r", "`n")
[IO.File]::WriteAllText($manifestPath, $manifestJson + "`n", $utf8NoBom)

Write-Host "Generated skill docs in $docsDir"
