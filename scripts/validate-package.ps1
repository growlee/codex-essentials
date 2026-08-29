$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = Join-Path $repoRoot 'package-manifest.json'
$skillsRoot = Join-Path $repoRoot 'skills'
$agentsRoot = Join-Path $repoRoot 'agents'

function Assert-JsonInteger {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value,
        [Parameter(Mandatory = $true)]
        [string]$Field
    )

    if ($Value -isnot [int] -and $Value -isnot [long]) {
        throw "$Field must be a JSON integer"
    }
}

function Assert-JsonBoolean {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Value,
        [Parameter(Mandatory = $true)]
        [string]$Field
    )

    if ($Value -isnot [bool]) {
        throw "$Field must be a JSON boolean"
    }
}

& (Join-Path $PSScriptRoot 'validate-skills.ps1')

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
Assert-JsonInteger -Value $manifest.schemaVersion -Field 'package-manifest.schemaVersion'
if ($manifest.schemaVersion -ne 2) {
    throw "Unsupported package manifest schemaVersion '$($manifest.schemaVersion)'"
}

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

if (-not $manifest.routingMatrix) {
    throw 'Missing routingMatrix in package-manifest.json'
}

$routingMatrixPath = Join-Path $repoRoot ([string]$manifest.routingMatrix)
if (-not (Test-Path -LiteralPath $routingMatrixPath -PathType Leaf)) {
    throw "Routing matrix not found: $routingMatrixPath"
}

$routing = Get-Content -Raw -LiteralPath $routingMatrixPath | ConvertFrom-Json
Assert-JsonInteger -Value $routing.schemaVersion -Field 'routing-matrix.schemaVersion'
if ($routing.schemaVersion -ne 1) {
    throw "Unsupported routing matrix schemaVersion '$($routing.schemaVersion)'"
}
Assert-JsonBoolean -Value $routing.rules.automaticRouting -Field 'routing-matrix.rules.automaticRouting'
Assert-JsonBoolean -Value $routing.rules.skillLaunchesSubagents -Field 'routing-matrix.rules.skillLaunchesSubagents'
Assert-JsonBoolean -Value $routing.rules.oneOwner -Field 'routing-matrix.rules.oneOwner'
if ($routing.rules.automaticRouting -ne $false) {
    throw 'Routing matrix must keep automaticRouting disabled'
}
if ($routing.rules.skillLaunchesSubagents -ne $false) {
    throw 'Routing matrix must not let skills launch subagents'
}
if ($routing.rules.oneOwner -ne $true) {
    throw 'Routing matrix must preserve one final owner'
}

$skillRoutes = @($routing.skillRoutes)
$routeIds = @($skillRoutes | ForEach-Object { [string]$_.id })
$duplicateRouteIds = @($routeIds | Group-Object | Where-Object Count -gt 1)
if ($duplicateRouteIds.Count -gt 0) {
    throw "Duplicate routing ids: $($duplicateRouteIds.Name -join ', ')"
}

$routedSkills = @($skillRoutes | ForEach-Object { [string]$_.skill } | Sort-Object)
$routingSkillDifference = @(Compare-Object -ReferenceObject $declaredSkills -DifferenceObject $routedSkills)
if ($routingSkillDifference.Count -ne 0) {
    throw "Skill routing mismatch: $($routingSkillDifference | Out-String)"
}

$allowedInvocations = @('matched-or-explicit', 'explicit-only', 'user-requested')
$allowedDelegation = @('none', 'optional')
$requiredExplicitOnlySkills = @(
    'adversarial-check',
    'delivery-proof',
    'grill-me',
    'handoff',
    'self-check',
    'tdd',
    'visual-proof',
    'wiki'
)
$referencedAgents = [System.Collections.Generic.List[string]]::new()

foreach ($route in $skillRoutes) {
    foreach ($requiredField in @('id', 'taskShape', 'skill', 'kind', 'invocation', 'authority', 'delegation', 'result', 'stop')) {
        if ([string]::IsNullOrWhiteSpace([string]$route.$requiredField)) {
            throw "Routing entry '$($route.id)' is missing '$requiredField'"
        }
    }
    if ($route.invocation -notin $allowedInvocations) {
        throw "Routing entry '$($route.id)' has unsupported invocation '$($route.invocation)'"
    }
    if ($route.delegation -notin $allowedDelegation) {
        throw "Routing entry '$($route.id)' has unsupported delegation '$($route.delegation)'"
    }

    $routeAgents = @($route.agents)
    if ($route.delegation -eq 'none' -and $routeAgents.Count -ne 0) {
        throw "Routing entry '$($route.id)' forbids delegation but references agents"
    }
    if ($route.delegation -eq 'optional' -and $routeAgents.Count -eq 0) {
        throw "Routing entry '$($route.id)' allows delegation without an agent condition"
    }
    if ($route.kind -eq 'proof' -and $route.invocation -ne 'explicit-only') {
        throw "Proof skill '$($route.skill)' must be explicit-only"
    }
    if ($route.skill -in $requiredExplicitOnlySkills -and $route.invocation -ne 'explicit-only') {
        throw "Skill '$($route.skill)' must remain explicit-only"
    }

    $routeAgentNames = @($routeAgents | ForEach-Object { [string]$_.name })
    $duplicateRouteAgents = @($routeAgentNames | Group-Object | Where-Object Count -gt 1)
    if ($duplicateRouteAgents.Count -gt 0) {
        throw "Routing entry '$($route.id)' repeats agents: $($duplicateRouteAgents.Name -join ', ')"
    }
    foreach ($agent in $routeAgents) {
        if ([string]::IsNullOrWhiteSpace([string]$agent.name) -or [string]::IsNullOrWhiteSpace([string]$agent.when)) {
            throw "Routing entry '$($route.id)' has an incomplete agent condition"
        }
        if ([string]$agent.name -notin $declaredAgents) {
            throw "Routing entry '$($route.id)' references undeclared agent '$($agent.name)'"
        }
        $referencedAgents.Add([string]$agent.name)
    }

    if ($route.invocation -eq 'explicit-only') {
        $metadataPath = Join-Path $skillsRoot "$($route.skill)\agents\openai.yaml"
        if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
            throw "Explicit-only skill '$($route.skill)' is missing agents/openai.yaml"
        }
        $metadata = Get-Content -Raw -LiteralPath $metadataPath
        if ($metadata -notmatch '(?m)^\s*allow_implicit_invocation:\s*false\s*$') {
            throw "Explicit-only skill '$($route.skill)' does not disable implicit invocation"
        }
    }
}

$agentCatalog = @($routing.agentCatalog)
$catalogNames = @($agentCatalog | ForEach-Object { [string]$_.name } | Sort-Object)
$catalogDifference = @(Compare-Object -ReferenceObject $declaredAgents -DifferenceObject $catalogNames)
if ($catalogDifference.Count -ne 0) {
    throw "Agent routing catalog mismatch: $($catalogDifference | Out-String)"
}

$allowedClassifications = @('routed', 'standalone', 'fallback', 'never-default')
foreach ($agent in $agentCatalog) {
    foreach ($requiredField in @('name', 'classification', 'useWhen', 'avoid', 'returns')) {
        if ([string]::IsNullOrWhiteSpace([string]$agent.$requiredField)) {
            throw "Agent routing entry '$($agent.name)' is missing '$requiredField'"
        }
    }
    if ($agent.classification -notin $allowedClassifications) {
        throw "Agent '$($agent.name)' has unsupported classification '$($agent.classification)'"
    }
    if ($agent.classification -eq 'routed' -and [string]$agent.name -notin $referencedAgents) {
        throw "Routed agent '$($agent.name)' is not referenced by a skill route"
    }
    if ($agent.classification -eq 'fallback') {
        if ([string]::IsNullOrWhiteSpace([string]$agent.fallbackFor)) {
            throw "Fallback agent '$($agent.name)' is missing fallbackFor"
        }
        if ([string]$agent.fallbackFor -notin $declaredAgents) {
            throw "Fallback agent '$($agent.name)' targets undeclared agent '$($agent.fallbackFor)'"
        }
    }
}

Write-Output "VALIDATED $($agentFiles.Count) agents"
Write-Output "VALIDATED $($skillRoutes.Count) skill routes and $($agentCatalog.Count) agent routes"
