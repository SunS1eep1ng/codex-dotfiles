function Test-TimestampedSkillBackupName {
  param(
    [AllowEmptyString()]
    [string]$Name
  )

  if ([string]::IsNullOrWhiteSpace($Name)) {
    return $false
  }

  return $Name -match "(?i)\.backup-\d{8}-\d{6}$"
}

function Test-PathUnderTimestampedSkillBackup {
  param(
    [AllowEmptyString()]
    [string]$RelativePath
  )

  if ([string]::IsNullOrWhiteSpace($RelativePath)) {
    return $false
  }

  $topLevelName = ($RelativePath -split "[\\/]")[0]
  return Test-TimestampedSkillBackupName -Name $topLevelName
}

function Test-HasEnglishTriggerWording {
  param(
    [AllowEmptyString()]
    [string]$Text
  )

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $false
  }

  # Ignore code spans, URLs, dotted/slashed identifiers, and digit-bearing tokens.
  # These often occur in Chinese prose but do not form natural English trigger wording.
  $cleaned = [regex]::Replace($Text, '(?s)`[^`]*`', " ")
  $cleaned = [regex]::Replace($cleaned, "(?i)\b(?:https?://|www\.)\S+", " ")
  $cleaned = [regex]::Replace(
    $cleaned,
    "\b[A-Za-z][A-Za-z0-9_-]*(?:[./\\][A-Za-z0-9_-]+)+\b",
    " "
  )
  $cleaned = [regex]::Replace($cleaned, "\b[A-Za-z_-]*\d[A-Za-z0-9_-]*\b", " ")

  $actionWordPattern = (
    "(?i)\b(?:" +
    "us(?:e|es|ed|ing)|invoke(?:s)?|trigger(?:s|ed)?|" +
    "build(?:s)?|create(?:s)?|read(?:s)?|edit(?:s)?|write(?:s)?|" +
    "manage(?:s)?|analy[sz](?:e|es)|generate(?:s)?|review(?:s)?|" +
    "debug(?:s)?|diagnos(?:e|es)|install(?:s)?|sync(?:s)?|" +
    "control(?:s)?|search(?:es)?|extract(?:s)?|convert(?:s)?|" +
    "publish(?:es)?|validate(?:s)?|verif(?:y|ies)|route(?:s)?|" +
    "help(?:s)?|support(?:s)?|provide(?:s)?|architect(?:s)?|" +
    "organize(?:s)?|guide(?:s)?|detect(?:s)?|handle(?:s)?|" +
    "work(?:s)?|run(?:s)?|compile(?:s)?|deploy(?:s)?|" +
    "configure(?:s)?|test(?:s)?|entrypoint|responsible" +
    ")\b"
  )

  # Natural trigger wording appears as a printable-ASCII prose clause with
  # an action word. This rejects both keyword piles and negative-only clauses.
  foreach ($asciiRun in [regex]::Matches($cleaned, "[\x20-\x7e]+")) {
    foreach ($clause in ($asciiRun.Value -split "[.!?;]+")) {
      $clauseText = $clause.Trim()
      if ($clauseText -match "(?i)^(?:do\s+not|don't|never)\s+use\b") {
        continue
      }

      $words = [regex]::Matches($clauseText, "(?i)\b[A-Za-z][A-Za-z'-]*\b")
      if (
        $words.Count -ge 5 -and
        [regex]::IsMatch($clauseText, $actionWordPattern)
      ) {
        return $true
      }
    }
  }

  return $false
}
