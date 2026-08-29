[CmdletBinding()]
param(
    [string]$SkillsRoot = (Join-Path $PSScriptRoot '..\plugins\codex-essentials\skills')
)

$ErrorActionPreference = 'Stop'
$allowedFrontmatterKeys = @('name', 'description', 'license', 'allowed-tools', 'metadata')
$failures = [System.Collections.Generic.List[string]]::new()
$skillDirectories = @(Get-ChildItem -LiteralPath $SkillsRoot -Directory | Sort-Object Name)

foreach ($skillDirectory in $skillDirectories) {
    $skillFile = Join-Path $skillDirectory.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile)) {
        $failures.Add("$($skillDirectory.Name): SKILL.md not found")
        continue
    }

    $content = (Get-Content -Raw -LiteralPath $skillFile) -replace "`r`n", "`n"
    $frontmatterMatch = [regex]::Match($content, '\A---\n(?<frontmatter>.*?)\n---(?:\n|\z)', 'Singleline')
    if (-not $frontmatterMatch.Success) {
        $failures.Add("$($skillDirectory.Name): invalid YAML frontmatter boundary")
        continue
    }

    $frontmatter = @{}
    foreach ($line in $frontmatterMatch.Groups['frontmatter'].Value -split "`n") {
        if ([string]::IsNullOrWhiteSpace($line) -or $line -match '^\s') {
            continue
        }
        $fieldMatch = [regex]::Match($line, '^(?<key>[A-Za-z0-9-]+):\s*(?<value>.*)$')
        if (-not $fieldMatch.Success) {
            $failures.Add("$($skillDirectory.Name): invalid top-level frontmatter line: $line")
            continue
        }
        $frontmatter[$fieldMatch.Groups['key'].Value] = $fieldMatch.Groups['value'].Value.Trim().Trim('"').Trim("'")
    }

    foreach ($key in $frontmatter.Keys) {
        if ($key -notin $allowedFrontmatterKeys) {
            $failures.Add("$($skillDirectory.Name): unsupported frontmatter key '$key'")
        }
    }

    $name = [string]$frontmatter['name']
    $description = [string]$frontmatter['description']
    if (-not $name) {
        $failures.Add("$($skillDirectory.Name): missing name")
    } elseif ($name -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $name.Length -gt 64) {
        $failures.Add("$($skillDirectory.Name): invalid skill name '$name'")
    } elseif ($name -ne $skillDirectory.Name) {
        $failures.Add("$($skillDirectory.Name): frontmatter name is '$name'")
    }

    if (-not $description) {
        $failures.Add("$($skillDirectory.Name): missing description")
    } elseif ($description.Length -gt 1024 -or $description -match '[<>]' -or $description -match '^\[TODO:') {
        $failures.Add("$($skillDirectory.Name): invalid description")
    }

    $body = $content.Substring($frontmatterMatch.Length)
    if ($body -match '(?m)^ {0,3}\[TODO:[^\n]*\]\s*$') {
        $failures.Add("$($skillDirectory.Name): unfinished TODO placeholder")
    }

    foreach ($referenceMatch in [regex]::Matches($body, '\]\((?<path>(?!https?://|#)[^)]+\.md)(?:#[^)]+)?\)')) {
        $referencePath = Join-Path $skillDirectory.FullName $referenceMatch.Groups['path'].Value
        if (-not (Test-Path -LiteralPath $referencePath)) {
            $failures.Add("$($skillDirectory.Name): missing reference '$($referenceMatch.Groups['path'].Value)'")
        }
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

$skillDirectories | ForEach-Object { Write-Output "VALID $($_.Name)" }
Write-Output "VALIDATED $($skillDirectories.Count) skills"
