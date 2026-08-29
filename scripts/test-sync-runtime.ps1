[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$syncScript = Join-Path $PSScriptRoot 'sync-runtime.ps1'
if (-not (Test-Path -LiteralPath $syncScript)) {
    throw "Missing sync script: $syncScript"
}

$temporaryBase = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
$testRoot = Join-Path $temporaryBase "codex-essentials-sync-test-$([guid]::NewGuid().ToString('N'))"

try {
    & $syncScript -Mode Apply -RuntimeRoot $testRoot
    & $syncScript -Mode Verify -RuntimeRoot $testRoot

    $agentPath = Join-Path $testRoot 'agents\analyst.toml'
    Add-Content -LiteralPath $agentPath -Value "`n# intentional test drift"

    $driftDetected = $false
    try {
        & $syncScript -Mode Verify -RuntimeRoot $testRoot *> $null
    } catch {
        if ($_.Exception.Message -match 'Runtime drift detected') {
            $driftDetected = $true
        } else {
            throw
        }
    }

    if (-not $driftDetected) {
        throw 'Verify did not detect changed runtime content.'
    }

    & $syncScript -Mode Apply -RuntimeRoot $testRoot

    $extraFile = Join-Path $testRoot 'skills\analyze\runtime-only.txt'
    Set-Content -LiteralPath $extraFile -Value 'must not be pruned automatically'

    $extraDriftDetected = $false
    try {
        & $syncScript -Mode Apply -RuntimeRoot $testRoot *> $null
    } catch {
        if ($_.Exception.Message -match 'Runtime drift detected') {
            $extraDriftDetected = $true
        } else {
            throw
        }
    }

    if (-not $extraDriftDetected) {
        throw 'Apply accepted an unmanaged file inside a managed skill.'
    }
    if (-not (Test-Path -LiteralPath $extraFile)) {
        throw 'Apply pruned an unmanaged runtime file.'
    }

    Write-Output 'PASS sync-runtime verify, apply, drift detection, and no-prune behavior'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTestRoot = (Resolve-Path -LiteralPath $testRoot).Path.TrimEnd('\')
        if (-not $resolvedTestRoot.StartsWith("$temporaryBase\codex-essentials-sync-test-")) {
            throw "Unsafe test cleanup target: $resolvedTestRoot"
        }
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
