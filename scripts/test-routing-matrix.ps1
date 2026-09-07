[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$temporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = Join-Path $temporaryBase "codex-essentials-routing-test-$([guid]::NewGuid().ToString('N'))"

function Invoke-ExpectedFailure {
    param([Parameter(Mandatory)][string]$Pattern)
    try {
        & (Join-Path $testRoot 'scripts\validate-package.ps1') *> $null
    } catch {
        if ($_.Exception.Message -match $Pattern) { return }
        throw
    }
    throw "Validator accepted invalid state; expected '$Pattern'"
}

function Assert-InvalidRoute {
    param([scriptblock]$Change, [string]$Pattern)
    $routing = Get-Content -Raw -LiteralPath $sourceRoutingPath | ConvertFrom-Json
    & $Change $routing
    $routing | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $routingPath
    try { Invoke-ExpectedFailure -Pattern $Pattern }
    finally { Copy-Item -LiteralPath $sourceRoutingPath -Destination $routingPath -Force }
}

try {
    New-Item -ItemType Directory -Path $testRoot | Out-Null
    foreach ($name in @('.agents', 'agents', 'docs', 'plugins', 'scripts', 'templates')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $name) -Destination $testRoot -Recurse
    }
    foreach ($name in @('LICENSE', 'package-manifest.json', 'routing-matrix.json')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $name) -Destination $testRoot
    }
    & (Join-Path $testRoot 'scripts\validate-package.ps1') *> $null

    $routingPath = Join-Path $testRoot 'routing-matrix.json'
    $sourceRoutingPath = Join-Path $repoRoot 'routing-matrix.json'
    Assert-InvalidRoute { param($r)
        $r.skillRoutes = @($r.skillRoutes | Where-Object skill -ne 'self-check')
    } 'Skill routing mismatch'
    Assert-InvalidRoute { param($r)
        ($r.skillRoutes | Where-Object skill -eq 'analyze').agents[0].name = 'designer'
    } "references undeclared agent 'designer'"
    Assert-InvalidRoute { param($r)
        ($r.skillRoutes | Where-Object skill -eq 'analyze').agents[1].name = 'critic'
    } 'Analysis must not route generic reasoning disputes to critic'
    foreach ($skill in @('self-check', 'roadmap')) {
        Assert-InvalidRoute { param($r)
            ($r.skillRoutes | Where-Object skill -eq $skill).invocation = 'user-requested'
        } "Skill '$skill' must remain explicit-only"
    }
    Assert-InvalidRoute { param($r)
        ($r.skillRoutes | Where-Object skill -eq 'diy').invocation = 'matched-or-explicit'
    } 'DIY route must remain a user-requested goal'
    Assert-InvalidRoute { param($r)
        ($r.skillRoutes | Where-Object skill -eq 'diy').kind = 'implementation'
    } 'DIY route must remain a user-requested goal'
    Assert-InvalidRoute { param($r)
        ($r.skillRoutes | Where-Object skill -eq 'roadmap').kind = 'implementation'
    } 'Roadmap route must remain a planning document'
    Assert-InvalidRoute { param($r)
        $r.rules.automaticRouting = 'false'
    } 'routing-matrix.rules.automaticRouting must be a JSON boolean'

    foreach ($skill in @('self-check', 'roadmap', 'diy')) {
        $metadataPath = Join-Path $testRoot "plugins\codex-essentials\skills\$skill\agents\openai.yaml"
        $metadata = Get-Content -Raw -LiteralPath $metadataPath
        $metadata.Replace('allow_implicit_invocation: true', 'allow_implicit_invocation: false') |
            Set-Content -LiteralPath $metadataPath
        try { Invoke-ExpectedFailure -Pattern 'invocation compatibility metadata changed without client verification' }
        finally { $metadata | Set-Content -LiteralPath $metadataPath }
    }

    $agentPath = Join-Path $testRoot 'agents\explore-luna.toml'
    $originalAgent = Get-Content -Raw -LiteralPath $agentPath
    foreach ($field in @('name', 'description', 'developer_instructions', 'model')) {
        # Replacing a key preserves valid TOML, isolating the required-field check.
        ($originalAgent -replace "(?m)^$field\s*=", "unused_$field =") | Set-Content -LiteralPath $agentPath
        Invoke-ExpectedFailure -Pattern "Missing or invalid $field"
    }
    ($originalAgent -replace '(?m)^description\s*=.*$', 'description = 42') | Set-Content -LiteralPath $agentPath
    Invoke-ExpectedFailure -Pattern 'Missing or invalid description'
    ($originalAgent -replace '(?m)^name\s*=.*$', 'name = "wrong-name"') | Set-Content -LiteralPath $agentPath
    Invoke-ExpectedFailure -Pattern 'Agent name mismatch'
    ($originalAgent + [Environment]::NewLine + "name = 'duplicate'") | Set-Content -LiteralPath $agentPath
    Invoke-ExpectedFailure -Pattern 'Invalid agent TOML'
    ($originalAgent + [Environment]::NewLine + 'broken = [') | Set-Content -LiteralPath $agentPath
    Invoke-ExpectedFailure -Pattern 'Invalid agent TOML'
    $originalAgent | Set-Content -LiteralPath $agentPath

    # Equivalent wording must not invalidate package structure. Skill behavior is
    # reviewed from the actual contract, not inferred from a magic heading/sentence.
    $diyPath = Join-Path $testRoot 'plugins\codex-essentials\skills\diy\SKILL.md'
    (Get-Content -Raw -LiteralPath $diyPath).Replace('## Automatic start', '## Start the native goal') |
        Set-Content -LiteralPath $diyPath
    $roadmapPath = Join-Path $testRoot 'plugins\codex-essentials\skills\roadmap\SKILL.md'
    (Get-Content -Raw -LiteralPath $roadmapPath).Replace(
        'Only an explicit read-only or no-edit instruction suppresses this synchronization.',
        'Skip synchronization only when the user explicitly requires read-only or no-edit work.'
    ) | Set-Content -LiteralPath $roadmapPath
    & (Join-Path $testRoot 'scripts\validate-package.ps1') *> $null

    Write-Output 'PASS routing coverage, invocation compatibility, agent TOML schema, and prose-independent structural validation'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path.TrimEnd('\')
        if (-not $resolvedTestRoot.StartsWith("$temporaryBase\codex-essentials-routing-test-")) {
            throw "Unsafe test cleanup target: $resolvedTestRoot"
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
