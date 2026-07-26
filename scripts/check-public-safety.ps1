param(
  [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "skill-export-policy.ps1")
if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $resolvedRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
} else {
  $resolvedRoot = Resolve-Path -LiteralPath $RepoRoot
}
$root = $resolvedRoot.Path.TrimEnd("\", "/")

$issues = New-Object System.Collections.Generic.List[object]
$forbiddenNames = @("auth.json", "auth1.json", "id_rsa", "id_ed25519")
$forbiddenExtensions = @(".key", ".pem", ".p12", ".pfx", ".sqlite", ".log")

$skillsRoot = Join-Path $root "skills"
if (Test-Path -LiteralPath $skillsRoot) {
  Get-ChildItem -LiteralPath $skillsRoot -Directory -Force | ForEach-Object {
    if (Test-TimestampedSkillBackupName -Name $_.Name) {
      $issues.Add([PSCustomObject]@{
        Path = "skills/$($_.Name)"
        Line = 0
        Reason = "timestamped skill backup must not be published"
      })
    }
  }
}

Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object {
  $relativePath = $_.FullName.Substring($root.Length).TrimStart("\", "/").Replace("\", "/")
  if ($relativePath -match "(^|/)\.git/") {
    return
  }

  $isPrivateEnv = $_.Name -like ".env*" -and $_.Name -notin @(".env.example", ".env.sample")
  if (
    $_.Name -in $forbiddenNames -or
    $isPrivateEnv -or
    $_.Extension -in $forbiddenExtensions -or
    $_.Name -match "\.sqlite-.+$"
  ) {
    $issues.Add([PSCustomObject]@{
      Path = $relativePath
      Line = 0
      Reason = "forbidden sensitive or machine-state filename"
    })
    return
  }

  try {
    $lineNumber = 0
    foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $_.FullName -ErrorAction Stop) {
      $lineNumber++
      $reason = $null
      if ($line -match "-----BEGIN (?:RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----") {
        $reason = "private key material"
      } elseif ($line -match "(?i)\b(?:sk-(?!(?:test|fake|example|placeholder|your)-)(?:proj-)?[A-Za-z0-9_-]{20,}|github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,})\b") {
        $reason = "credential-like token"
      } elseif ($line -match "\bAKIA[0-9A-Z]{16}\b") {
        $reason = "AWS access-key-like token"
      } elseif ($line -match "\bxox[baprs]-[A-Za-z0-9-]{20,}\b") {
        $reason = "Slack token-like value"
      } elseif ($line -match "\bAIza[0-9A-Za-z_-]{35}\b") {
        $reason = "Google API-key-like token"
      } elseif (
        $relativePath -eq "config/config.toml.template" -and
        $line -match '(?i)http_headers\s*=' -and
        $line -notmatch "PUT_LOCAL_KEY_HERE"
      ) {
        $reason = "non-placeholder HTTP header in public config template"
      }

      if ($null -ne $reason) {
        $issues.Add([PSCustomObject]@{
          Path = $relativePath
          Line = $lineNumber
          Reason = $reason
        })
      }
    }
  } catch {
    # Binary and unreadable files are covered by filename checks and Git review.
  }
}

if ($issues.Count -gt 0) {
  $issues | Format-Table -AutoSize
  throw "Public repository safety check failed with $($issues.Count) issue(s)."
}

Write-Host "OK: public repository safety check found no credential or machine-state files."
