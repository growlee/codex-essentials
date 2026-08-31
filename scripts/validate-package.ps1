$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$manifestPath = Join-Path $repoRoot 'package-manifest.json'
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

$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
Assert-JsonInteger -Value $manifest.schemaVersion -Field 'package-manifest.schemaVersion'
if ($manifest.schemaVersion -ne 2) {
    throw "Unsupported package manifest schemaVersion '$($manifest.schemaVersion)'"
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.pluginRoot)) {
    throw 'Missing pluginRoot in package-manifest.json'
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.pluginManifest)) {
    throw 'Missing pluginManifest in package-manifest.json'
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.marketplaceManifest)) {
    throw 'Missing marketplaceManifest in package-manifest.json'
}
if ([string]$manifest.version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') {
    throw "Invalid package version '$($manifest.version)'"
}

$artifactGroups = @('templates', 'documentation', 'tools')
foreach ($group in $artifactGroups) {
    $entries = @($manifest.artifacts.$group)
    if ($entries.Count -eq 0) {
        throw "Package manifest artifacts.$group must not be empty"
    }
    foreach ($entry in $entries) {
        $artifactPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$entry)))
        if (-not $artifactPath.StartsWith("$repoRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Artifact path escapes repository: $artifactPath"
        }
        if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
            throw "Declared artifact not found: $entry"
        }
    }
}

$expectedArtifacts = @(
    'templates/AGENTS.global.example.md',
    'templates/config.minimal.toml',
    'docs/from-omx-to-essentials.md',
    'scripts/audit-harness.py',
    'scripts/test-audit-harness.py'
) | Sort-Object
$declaredArtifacts = @(
    $artifactGroups |
        ForEach-Object { @($manifest.artifacts.$_) } |
        ForEach-Object { [string]$_ }
) | Sort-Object
$artifactDifference = @(Compare-Object -ReferenceObject $expectedArtifacts -DifferenceObject $declaredArtifacts)
if ($artifactDifference.Count -ne 0) {
    throw "Public artifact manifest mismatch: $($artifactDifference | Out-String)"
}

$publicTemplatePaths = @(
    'templates/AGENTS.global.example.md',
    'templates/config.minimal.toml',
    'docs/from-omx-to-essentials.md'
)
foreach ($entry in $publicTemplatePaths) {
    $content = Get-Content -Raw -LiteralPath (Join-Path $repoRoot $entry)
    if ($content -match '(?i)(?:[A-Z]:\\Users\\|[A-Z]:\\Projects\\|/home/[^/\s]+/|TODO|replace me)') {
        throw "Private path or unfinished placeholder in public artifact '$entry'"
    }
}

$minimalConfig = Get-Content -Raw -LiteralPath (Join-Path $repoRoot 'templates/config.minimal.toml')
if ($minimalConfig -match '(?im)^\s*\[(?:mcp_servers|projects|plugins|hooks|marketplaces)(?:\.|\])') {
    throw 'Minimal config must not include environment-specific integration tables'
}

$pluginRoot = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$manifest.pluginRoot))).TrimEnd('\')
if (-not $pluginRoot.StartsWith("$repoRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Plugin root escapes repository: $pluginRoot"
}
$skillsRoot = Join-Path $pluginRoot 'skills'
$pluginManifestPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$manifest.pluginManifest)))
$marketplaceManifestPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot ([string]$manifest.marketplaceManifest)))
foreach ($path in @($pluginManifestPath, $marketplaceManifestPath)) {
    if (-not $path.StartsWith("$repoRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Manifest path escapes repository: $path"
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required manifest not found: $path"
    }
}
if (Test-Path -LiteralPath (Join-Path $repoRoot 'skills')) {
    throw 'Legacy root skills directory must not coexist with the plugin authoring source'
}

& (Join-Path $PSScriptRoot 'validate-skills.ps1') -SkillsRoot $skillsRoot

$plugin = Get-Content -Raw -LiteralPath $pluginManifestPath | ConvertFrom-Json
if ([string]$plugin.name -ne [string]$manifest.name) {
    throw "Plugin name '$($plugin.name)' does not match package '$($manifest.name)'"
}
if ([string]$plugin.version -ne [string]$manifest.version) {
    throw "Plugin version '$($plugin.version)' does not match package '$($manifest.version)'"
}
if ([string]$manifest.license -ne 'MIT') {
    throw "Package license must be 'MIT'"
}
if ([string]$plugin.license -ne [string]$manifest.license) {
    throw "Plugin license '$($plugin.license)' does not match package '$($manifest.license)'"
}
if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'LICENSE') -PathType Leaf)) {
    throw 'Repository LICENSE file is missing'
}
if ([string]$plugin.interface.displayName -ne 'Codex Essentials') {
    throw "Plugin display name must be 'Codex Essentials'"
}
foreach ($urlField in @('homepage', 'repository')) {
    if ([string]$plugin.$urlField -ne 'https://github.com/growlee/codex-essentials') {
        throw "Plugin $urlField must be 'https://github.com/growlee/codex-essentials'"
    }
}
if ([string]$plugin.skills -ne './skills/') {
    throw "Plugin skills path must be './skills/'"
}
foreach ($forbiddenField in @('agents', 'hooks', 'mcpServers', 'apps')) {
    if ($null -ne $plugin.PSObject.Properties[$forbiddenField]) {
        throw "Plugin manifest must not declare '$forbiddenField'"
    }
}
if (@($plugin.interface.capabilities).Count -ne 0) {
    throw 'Plugin manifest must not declare runtime capabilities'
}
$marketplace = Get-Content -Raw -LiteralPath $marketplaceManifestPath | ConvertFrom-Json
if ([string]$marketplace.name -ne [string]$manifest.name) {
    throw "Marketplace name '$($marketplace.name)' does not match package '$($manifest.name)'"
}
if ([string]$marketplace.interface.displayName -ne 'Codex Essentials') {
    throw "Marketplace display name must be 'Codex Essentials'"
}
$marketplacePlugins = @($marketplace.plugins)
if ($marketplacePlugins.Count -ne 1) {
    throw 'Marketplace must contain exactly one plugin entry'
}
$marketplacePlugin = $marketplacePlugins[0]
if ([string]$marketplacePlugin.name -ne [string]$manifest.name) {
    throw "Marketplace plugin '$($marketplacePlugin.name)' does not match package '$($manifest.name)'"
}
if ([string]$marketplacePlugin.source.source -ne 'local' -or [string]$marketplacePlugin.source.path -ne './plugins/codex-essentials') {
    throw 'Marketplace source must be local ./plugins/codex-essentials'
}
if ([string]$marketplacePlugin.policy.installation -ne 'AVAILABLE' -or [string]$marketplacePlugin.policy.authentication -ne 'ON_INSTALL') {
    throw 'Marketplace policy must remain AVAILABLE with ON_INSTALL authentication'
}

foreach ($runtimeField in @('hooks', 'automaticRouting', 'workflowState', 'backgroundServices', 'automaticUpdates')) {
    Assert-JsonBoolean -Value $manifest.runtime.$runtimeField -Field "package-manifest.runtime.$runtimeField"
    if ($manifest.runtime.$runtimeField -ne $false) {
        throw "Runtime feature '$runtimeField' must remain disabled"
    }
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
$requiredCatalogVisibleUserRequestedSkills = @('diy')
$requiredDiyAuthority = 'check material ambiguity before goal-state access; after an unambiguous explicit invocation, automatically create one native goal unless the user explicitly requests draft-only'
$diySkillPath = Join-Path $skillsRoot 'diy\SKILL.md'
if (-not (Test-Path -LiteralPath $diySkillPath -PathType Leaf)) {
    throw 'DIY skill contract is missing'
}
$diySkill = Get-Content -Raw -LiteralPath $diySkillPath
$requiredDiyContractPatterns = [ordered]@{
    'comprehension gate' = '(?m)^## Comprehension gate\s*$'
    'automatic start' = '(?m)^## Automatic start\s*$'
    'draft-only opt-out' = '(?m)^## Draft-only opt-out\s*$'
    'explicit invocation authority' = 'Act only through an explicit \x60\$diy\x60 invocation'
    'single material question' = 'ask exactly one concise question'
}
foreach ($entry in $requiredDiyContractPatterns.GetEnumerator()) {
    if ($diySkill -notmatch $entry.Value) {
        throw "DIY skill contract is missing $($entry.Key)"
    }
}
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
    if ($route.skill -in $requiredCatalogVisibleUserRequestedSkills -and $route.invocation -ne 'user-requested') {
        throw "Skill '$($route.skill)' must remain user-requested"
    }
    if ($route.skill -eq 'diy' -and $route.authority -ne $requiredDiyAuthority) {
        throw 'DIY route must preserve comprehension-gated automatic start authority'
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
    if ($route.skill -in $requiredCatalogVisibleUserRequestedSkills) {
        $metadataPath = Join-Path $skillsRoot "$($route.skill)\agents\openai.yaml"
        if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
            throw "Catalog-visible skill '$($route.skill)' is missing agents/openai.yaml"
        }
        $metadata = Get-Content -Raw -LiteralPath $metadataPath
        if ($metadata -notmatch '(?m)^\s*allow_implicit_invocation:\s*true\s*$') {
            throw "Skill '$($route.skill)' must remain catalog-visible"
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
