[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$temporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = Join-Path $temporaryBase "codex-essentials-routing-test-$([guid]::NewGuid().ToString('N'))"

function Invoke-ExpectedFailure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $failedAsExpected = $false
    try {
        & (Join-Path $testRoot 'scripts\validate-package.ps1') *> $null
    } catch {
        if ($_.Exception.Message -match $Pattern) {
            $failedAsExpected = $true
        } else {
            throw
        }
    }
    if (-not $failedAsExpected) {
        throw "Validator accepted invalid routing state; expected '$Pattern'"
    }
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

    $routing = Get-Content -Raw -LiteralPath $routingPath | ConvertFrom-Json
    $routing.skillRoutes = @($routing.skillRoutes | Where-Object skill -ne 'self-check')
    $routing | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $routingPath
    Invoke-ExpectedFailure -Pattern 'Skill routing mismatch'

    Copy-Item -LiteralPath $sourceRoutingPath -Destination $routingPath -Force
    $routing = Get-Content -Raw -LiteralPath $routingPath | ConvertFrom-Json
    ($routing.skillRoutes | Where-Object skill -eq 'analyze').agents[0].name = 'designer'
    $routing | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $routingPath
    Invoke-ExpectedFailure -Pattern "references undeclared agent 'designer'"

    Copy-Item -LiteralPath $sourceRoutingPath -Destination $routingPath -Force
    $routing = Get-Content -Raw -LiteralPath $routingPath | ConvertFrom-Json
    ($routing.skillRoutes | Where-Object skill -eq 'self-check').invocation = 'user-requested'
    $routing | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $routingPath
    Invoke-ExpectedFailure -Pattern "Skill 'self-check' must remain explicit-only"

    Copy-Item -LiteralPath $sourceRoutingPath -Destination $routingPath -Force
    $routing = Get-Content -Raw -LiteralPath $routingPath | ConvertFrom-Json
    $routing.rules.automaticRouting = 'false'
    $routing | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $routingPath
    Invoke-ExpectedFailure -Pattern 'routing-matrix.rules.automaticRouting must be a JSON boolean'

    Copy-Item -LiteralPath $sourceRoutingPath -Destination $routingPath -Force
    $metadataPath = Join-Path $testRoot 'plugins\codex-essentials\skills\self-check\agents\openai.yaml'
    $metadata = Get-Content -Raw -LiteralPath $metadataPath
    $metadata.Replace('allow_implicit_invocation: false', 'allow_implicit_invocation: true') |
        Set-Content -LiteralPath $metadataPath
    Invoke-ExpectedFailure -Pattern "does not disable implicit invocation"

    Write-Output 'PASS routing matrix coverage, packaged-agent references, and explicit-only metadata checks'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path.TrimEnd('\')
        if (-not $resolvedTestRoot.StartsWith("$temporaryBase\codex-essentials-routing-test-")) {
            throw "Unsafe test cleanup target: $resolvedTestRoot"
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
