[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$syncScript = Join-Path $PSScriptRoot 'sync-runtime.ps1'
if (-not (Test-Path -LiteralPath $syncScript -PathType Leaf)) {
    throw "Missing sync script: $syncScript"
}
$repoRoot = Split-Path -Parent $PSScriptRoot
$temporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = Join-Path $temporaryBase "codex-essentials-sync-test-$([guid]::NewGuid().ToString('N'))"
$agentsOnlyRoot = Join-Path $temporaryBase "codex-essentials-agents-test-$([guid]::NewGuid().ToString('N'))"
$junctionRoot = Join-Path $temporaryBase "codex-essentials-junction-test-$([guid]::NewGuid().ToString('N'))"
$preflightRoot = Join-Path $temporaryBase "codex-essentials-preflight-test-$([guid]::NewGuid().ToString('N'))"
$lateCollisionRoot = Join-Path $temporaryBase "codex-essentials-parent-file-test-$([guid]::NewGuid().ToString('N'))"

function Assert-ThrowsLike {
    param([scriptblock]$Action, [string]$Pattern)
    try { & $Action *> $null } catch {
        if ($_.Exception.Message -match $Pattern) { return }
        throw
    }
    throw "Expected failure matching: $Pattern"
}

try {
    & $syncScript -Mode Apply -RuntimeRoot $testRoot
    & $syncScript -Mode Verify -RuntimeRoot $testRoot
    $agentPath = Join-Path $testRoot 'agents\analyst.toml'
    $skillPath = Join-Path $testRoot 'skills\analyze\SKILL.md'
    Add-Content -LiteralPath $agentPath -Value "`n# intentional test drift"
    Add-Content -LiteralPath $skillPath -Value "`n<!-- intentional test drift -->"
    Assert-ThrowsLike { & $syncScript -Mode Verify -RuntimeRoot $testRoot } 'Runtime drift detected'
    Assert-ThrowsLike { & $syncScript -Mode Apply -RuntimeRoot $testRoot } 'Runtime drift detected after Apply'
    if ((Get-Content -Raw -LiteralPath $agentPath) -notmatch 'intentional test drift') {
        throw 'Apply without ReplaceChanged overwrote changed managed content.'
    }
    if ((Get-Content -Raw -LiteralPath $skillPath) -notmatch 'intentional test drift') {
        throw 'Apply without ReplaceChanged overwrote changed skill content.'
    }
    if ((Test-Path -LiteralPath "$agentPath.bak") -or (Test-Path -LiteralPath "$skillPath.bak")) {
        throw 'Preserve mode created a backup.'
    }
    & $syncScript -Mode Apply -ReplaceChanged -RuntimeRoot $testRoot
    if ((Get-Content -Raw -LiteralPath "$agentPath.bak") -notmatch 'intentional test drift') {
        throw 'ReplaceChanged did not preserve the changed agent backup.'
    }
    if ((Get-Content -Raw -LiteralPath "$skillPath.bak") -notmatch 'intentional test drift') {
        throw 'ReplaceChanged did not preserve the changed skill backup.'
    }

    $extraFile = Join-Path $testRoot 'skills\analyze\runtime-only.txt'
    Set-Content -LiteralPath $extraFile -Value 'must not be pruned automatically'
    Assert-ThrowsLike { & $syncScript -Mode Apply -RuntimeRoot $testRoot } 'Runtime drift detected after Apply'
    if (-not (Test-Path -LiteralPath $extraFile)) { throw 'Apply pruned an unmanaged runtime file.' }

    & $syncScript -Mode Apply -Components Agents -RuntimeRoot $agentsOnlyRoot
    & $syncScript -Mode Verify -Components Agents -RuntimeRoot $agentsOnlyRoot
    if (-not (Test-Path -LiteralPath (Join-Path $agentsOnlyRoot 'agents\analyst.toml') -PathType Leaf)) {
        throw 'Agents-only synchronization did not install native agents.'
    }
    if (Test-Path -LiteralPath (Join-Path $agentsOnlyRoot 'skills')) {
        throw 'Agents-only synchronization created a skills runtime.'
    }

    foreach ($overlap in @($repoRoot, (Join-Path $repoRoot 'runtime-test'), (Split-Path -Parent $repoRoot))) {
        Assert-ThrowsLike { & $syncScript -Mode Apply -Components Agents -RuntimeRoot $overlap } 'overlaps the authoring repository'
    }

    $junctionRuntime = Join-Path $junctionRoot 'runtime'
    $outside = Join-Path $junctionRoot 'outside'
    New-Item -ItemType Directory -Path $junctionRuntime, $outside -Force | Out-Null
    $sentinel = Join-Path $outside 'sentinel.txt'
    Set-Content -LiteralPath $sentinel -Value 'unchanged'
    foreach ($component in @('Agents', 'Skills')) {
        $destinationName = $component.ToLowerInvariant()
        $junction = Join-Path $junctionRuntime $destinationName
        New-Item -ItemType Junction -Path $junction -Target $outside | Out-Null
        Assert-ThrowsLike { & $syncScript -Mode Apply -Components $component -RuntimeRoot $junctionRuntime } 'reparse point'
        if ((Get-Content -Raw -LiteralPath $sentinel).Trim() -ne 'unchanged' -or (Get-ChildItem -LiteralPath $outside).Count -ne 1) {
            throw "Rejected $component junction changed content outside the runtime root."
        }
        [System.IO.Directory]::Delete($junction)
    }

    $preflightAgents = Join-Path $preflightRoot 'agents'
    New-Item -ItemType Directory -Path $preflightAgents -Force | Out-Null
    $changedAgent = Join-Path $preflightAgents 'analyst.toml'
    Set-Content -LiteralPath $changedAgent -Value 'intentional drift'
    Set-Content -LiteralPath "$changedAgent.bak" -Value 'existing backup'
    Assert-ThrowsLike { & $syncScript -Mode Apply -Components Agents -ReplaceChanged -RuntimeRoot $preflightRoot } 'existing backup'
    if (Test-Path -LiteralPath (Join-Path $preflightAgents 'architect.toml')) {
        throw 'Backup collision was not preflighted before missing files were written.'
    }
    if ((Get-Content -Raw -LiteralPath $changedAgent).Trim() -ne 'intentional drift') {
        throw 'Backup collision changed the managed destination.'
    }

    $lateSkillsRoot = Join-Path $lateCollisionRoot 'skills'
    New-Item -ItemType Directory -Path $lateSkillsRoot -Force | Out-Null
    $lateParentFile = Join-Path $lateSkillsRoot 'wiki'
    Set-Content -LiteralPath $lateParentFile -Value 'must remain a regular file'
    Assert-ThrowsLike { & $syncScript -Mode Apply -Components Skills -RuntimeRoot $lateCollisionRoot } 'Destination ancestor must be a directory'
    if ((Get-Content -Raw -LiteralPath $lateParentFile).Trim() -ne 'must remain a regular file') {
        throw 'Late parent-file collision changed the blocking file.'
    }
    $actualLateEntries = @(Get-ChildItem -LiteralPath $lateCollisionRoot -Recurse -Force | ForEach-Object { $_.FullName } | Sort-Object)
    $expectedLateEntries = @($lateSkillsRoot, $lateParentFile) | Sort-Object
    if (
        $actualLateEntries.Count -ne $expectedLateEntries.Count -or
        (Compare-Object -ReferenceObject $expectedLateEntries -DifferenceObject $actualLateEntries)
    ) {
        throw 'Late parent-file collision wrote unexpected runtime entries before failing.'
    }

    Write-Output 'PASS sync-runtime safety, zero-write preflight, preserve/replace backups, no-prune, and component behavior'
} finally {
    foreach ($junction in @((Join-Path $junctionRoot 'runtime\agents'), (Join-Path $junctionRoot 'runtime\skills'))) {
        if ((Test-Path -LiteralPath $junction) -and ((Get-Item -LiteralPath $junction -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            [System.IO.Directory]::Delete($junction)
        }
    }
    foreach ($candidate in @($testRoot, $agentsOnlyRoot, $junctionRoot, $preflightRoot, $lateCollisionRoot)) {
        if (Test-Path -LiteralPath $candidate) {
            $resolvedTestRoot = [System.IO.Path]::GetFullPath($candidate).TrimEnd('\')
            if (-not $resolvedTestRoot.StartsWith("$temporaryBase\codex-essentials-", [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Unsafe test cleanup target: $resolvedTestRoot"
            }
            Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
        }
    }
}
