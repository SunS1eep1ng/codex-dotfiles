$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "skill-export-policy.ps1")

function Assert-Equal {
  param(
    [string]$Label,
    [bool]$Actual,
    [bool]$Expected
  )

  if ($Actual -ne $Expected) {
    throw "$Label expected $Expected but got $Actual"
  }
}

$backupCases = @(
  @{ Name = "wechatide-skill.backup-20260718-153615"; Expected = $true },
  @{ Name = "WECHATIDE.backup-20260718-153615"; Expected = $true },
  @{ Name = "wechatide-skill.backup-20260718-153615-extra"; Expected = $false },
  @{ Name = "wechatide-skill.backup-latest"; Expected = $false },
  @{ Name = "wechatide-skill"; Expected = $false }
)

foreach ($case in $backupCases) {
  Assert-Equal `
    -Label "backup name '$($case.Name)'" `
    -Actual (Test-TimestampedSkillBackupName -Name $case.Name) `
    -Expected $case.Expected
}

Assert-Equal `
  -Label "backup path with forward slashes" `
  -Actual (Test-PathUnderTimestampedSkillBackup -RelativePath "foo.backup-20260718-153615/SKILL.md") `
  -Expected $true
Assert-Equal `
  -Label "backup path with backslashes" `
  -Actual (Test-PathUnderTimestampedSkillBackup -RelativePath "foo.backup-20260718-153615\skills\bar\SKILL.md") `
  -Expected $true
Assert-Equal `
  -Label "nested backup-like name is not top-level" `
  -Actual (Test-PathUnderTimestampedSkillBackup -RelativePath "foo/references/bar.backup-20260718-153615/file.md") `
  -Expected $false

$hanSeparator = [string][char]0x4e2d
$technicalOnly = (
  "project.config.json / project.private.config.json" +
  $hanSeparator +
  "ES6" +
  $hanSeparator +
  "miniprogramRoot" +
  $hanSeparator +
  "appid" +
  $hanSeparator +
  "compileType" +
  $hanSeparator +
  "wechatide"
)
$englishWording = "Use for directly reading or editing WeChat mini-program project configuration."
$mixedWording = (
  $hanSeparator +
  "Root entrypoint for WeChat DevTools project configuration tasks."
)
$keywordPile = "AppID npm WXML WXSS CloudBase console network"
$negativeOnly = "Do not use this skill for browser automation tasks."
$tooShort = "Use for PDF files."

Assert-Equal `
  -Label "technical identifiers are not English wording" `
  -Actual (Test-HasEnglishTriggerWording -Text $technicalOnly) `
  -Expected $false
Assert-Equal `
  -Label "natural English trigger sentence" `
  -Actual (Test-HasEnglishTriggerWording -Text $englishWording) `
  -Expected $true
Assert-Equal `
  -Label "mixed Chinese and English trigger sentence" `
  -Actual (Test-HasEnglishTriggerWording -Text $mixedWording) `
  -Expected $true
Assert-Equal `
  -Label "technical keyword pile is not trigger wording" `
  -Actual (Test-HasEnglishTriggerWording -Text $keywordPile) `
  -Expected $false
Assert-Equal `
  -Label "negative-only English clause is not trigger wording" `
  -Actual (Test-HasEnglishTriggerWording -Text $negativeOnly) `
  -Expected $false
Assert-Equal `
  -Label "overly short English phrase is not trigger wording" `
  -Actual (Test-HasEnglishTriggerWording -Text $tooShort) `
  -Expected $false

Write-Host "OK: skill export policy regression tests passed."
