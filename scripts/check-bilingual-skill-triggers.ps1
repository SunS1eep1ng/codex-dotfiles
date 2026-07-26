param(
  [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }),
  [switch]$FailOnMissing
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "skill-export-policy.ps1")
$skillsRoot = Join-Path $CodexHome "skills"
if (-not (Test-Path -LiteralPath $skillsRoot)) {
  throw "Skills directory not found: $skillsRoot"
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
      if ($value -in @(">-", "|-", ">", "|")) {
        $parts = New-Object System.Collections.Generic.List[string]
        for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
          $next = $Lines[$j]
          if ($next -match "^\S[\w-]*:\s*" -or $next -eq "---") {
            break
          }
          if ($next.Trim().Length -gt 0) {
            $parts.Add($next.Trim())
          }
        }
        return ($parts -join " ")
      }
      return $value.Trim('"').Trim("'")
    }
  }

  return ""
}

$rootResolved = (Resolve-Path -LiteralPath $skillsRoot).Path.TrimEnd("\", "/")
$missing = @()
Get-ChildItem -LiteralPath $skillsRoot -Recurse -File -Filter "SKILL.md" -Force | ForEach-Object {
  $relativePath = $_.FullName.Substring($rootResolved.Length).TrimStart("\", "/")
  $topLevelName = ($relativePath -split "[\\/]")[0]
  if (
    $topLevelName -eq ".system" -or
    (Test-PathUnderTimestampedSkillBackup -RelativePath $relativePath)
  ) {
    return
  }

  $text = Get-Content -Raw -Encoding UTF8 -LiteralPath $_.FullName
  $frontmatter = ""
  if ($text -match "(?s)^---\s*(.*?)\s*---") {
    $frontmatter = $Matches[1]
  }
  $lines = $frontmatter -split "`r?`n"
  $name = Get-FrontmatterValue -Lines $lines -Key "name"
  $description = Get-FrontmatterValue -Lines $lines -Key "description"
  $hasChinese = $description -match "[\u3400-\u9fff]"
  $hasEnglish = Test-HasEnglishTriggerWording -Text $description

  if (-not $hasChinese -or -not $hasEnglish) {
    $missing += [PSCustomObject]@{
      Name = $name
      Path = $relativePath.Replace("\", "/")
      MissingChinese = -not $hasChinese
      MissingEnglish = -not $hasEnglish
    }
  }
}

if ($missing.Count -eq 0) {
  Write-Host "OK: all user-owned skill descriptions contain Chinese and English trigger wording."
  exit 0
}

$missing | Sort-Object Path | Format-Table -AutoSize
Write-Host "Found $($missing.Count) user-owned skill descriptions that need bilingual trigger wording."
if ($FailOnMissing) {
  exit 2
}
