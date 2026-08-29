$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'package-manifest.json'
$skillsRoot = Join-Path $repoRoot 'skills'
$agentsRoot = Join-Path $repoRoot 'agents'

& (Join-Path $PSScriptRoot 'validate-skills.ps1')

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$declaredSkills = @($manifest.skills | Sort-Object)
$actualSkills = @(
    Get-ChildItem -LiteralPath $skillsRoot -Directory |
        Sort-Object Name |
        Select-Object -ExpandProperty Name
)

$skillDifference = @(Compare-Object -ReferenceObject $declaredSkills -DifferenceObject $actualSkills)
if ($skillDifference.Count -ne 0) {
    throw "Skill manifest mismatch: $($skillDifference | Out-String)"
}

$declaredAgents = @($manifest.agents | Sort-Object)
$agentFiles = @(Get-ChildItem -LiteralPath $agentsRoot -File -Filter '*.toml' | Sort-Object BaseName)
$actualAgents = @($agentFiles.BaseName)

$agentDifference = @(Compare-Object -ReferenceObject $declaredAgents -DifferenceObject $actualAgents)
if ($agentDifference.Count -ne 0) {
    throw "Agent manifest mismatch: $($agentDifference | Out-String)"
}

foreach ($file in $agentFiles) {
    $content = Get-Content -Raw -LiteralPath $file.FullName
    if ($content -notmatch '(?m)^model\s*=') {
        throw "Missing model in $($file.FullName)"
    }
    if ($content -notmatch '(?m)^developer_instructions\s*=\s*\"\"\"') {
        throw "Missing developer_instructions in $($file.FullName)"
    }
    if ($content -match '(?i)oh-my-codex|\bomx\b|\.omx') {
        throw "Legacy runtime reference in $($file.FullName)"
    }
    if ($content -match '(?i)TODO|replace me') {
        throw "Unfinished placeholder in $($file.FullName)"
    }

    $nameMatch = [regex]::Match($content, '(?m)^name\s*=\s*\"([^\"]+)\"')
    if ($nameMatch.Success -and $nameMatch.Groups[1].Value -ne $file.BaseName) {
        throw "Agent name mismatch in $($file.FullName)"
    }

    Write-Output "VALID agent $($file.BaseName)"
}

Write-Output "VALIDATED $($agentFiles.Count) agents"
