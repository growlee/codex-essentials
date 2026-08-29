[CmdletBinding()]
param(
    [ValidateSet('Verify', 'Apply')]
    [string]$Mode = 'Verify',

    [ValidateSet('All', 'Skills', 'Agents')]
    [string]$Components = 'All',

    [string]$RuntimeRoot = $(
        if ($env:CODEX_HOME) {
            $env:CODEX_HOME
        } elseif ($env:USERPROFILE) {
            Join-Path $env:USERPROFILE '.codex'
        } else {
            throw 'Cannot resolve the Codex runtime root.'
        }
    )
)

$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$resolvedRuntimeRoot = [System.IO.Path]::GetFullPath($RuntimeRoot).TrimEnd('\')
$pathRoot = [System.IO.Path]::GetPathRoot($resolvedRuntimeRoot).TrimEnd('\')

if (-not $resolvedRuntimeRoot -or $resolvedRuntimeRoot -eq $pathRoot) {
    throw "Unsafe runtime root: $resolvedRuntimeRoot"
}
if (
    $resolvedRuntimeRoot -eq $repoRoot -or
    $repoRoot.StartsWith("$resolvedRuntimeRoot\", [System.StringComparison]::OrdinalIgnoreCase)
) {
    throw "Runtime root cannot contain the authoring repository: $resolvedRuntimeRoot"
}

$manifestPath = Join-Path $repoRoot 'package-manifest.json'
& (Join-Path $PSScriptRoot 'validate-package.ps1')
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
$pluginRoot = Join-Path $repoRoot ([string]$manifest.pluginRoot)
$sourceSkillsRoot = Join-Path $pluginRoot 'skills'
$sourceAgentsRoot = Join-Path $repoRoot 'agents'
$runtimeSkillsRoot = Join-Path $resolvedRuntimeRoot 'skills'
$runtimeAgentsRoot = Join-Path $resolvedRuntimeRoot 'agents'
$syncSkills = $Components -in @('All', 'Skills')
$syncAgents = $Components -in @('All', 'Agents')
$summaryParts = [System.Collections.Generic.List[string]]::new()
if ($syncSkills) {
    $summaryParts.Add("$($manifest.skills.Count) skills")
}
if ($syncAgents) {
    $summaryParts.Add("$($manifest.agents.Count) agents")
}
$componentSummary = $summaryParts -join ', '

function Get-RelativeFileMap {
    param([Parameter(Mandatory)][string]$Root)

    $map = @{}
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return $map
    }

    $normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    foreach ($file in Get-ChildItem -LiteralPath $normalizedRoot -Recurse -Force -File) {
        $relativePath = $file.FullName.Substring($normalizedRoot.Length).TrimStart('\')
        if ($relativePath -match '(^|\\)__pycache__(\\|$)' -or $relativePath -match '\.pyc$') {
            continue
        }
        $map[$relativePath] = $file.FullName
    }
    return $map
}

function Get-ManagedDrift {
    $drift = [System.Collections.Generic.List[string]]::new()

    if ($syncSkills) {
        foreach ($skillName in $manifest.skills) {
            $sourceRoot = Join-Path $sourceSkillsRoot $skillName
            $destinationRoot = Join-Path $runtimeSkillsRoot $skillName
            $sourceFiles = Get-RelativeFileMap -Root $sourceRoot
            $destinationFiles = Get-RelativeFileMap -Root $destinationRoot

            foreach ($relativePath in $sourceFiles.Keys) {
                if (-not $destinationFiles.ContainsKey($relativePath)) {
                    $drift.Add("MISSING skill/$skillName/$relativePath")
                    continue
                }

                $sourceHash = (Get-FileHash -LiteralPath $sourceFiles[$relativePath] -Algorithm SHA256).Hash
                $destinationHash = (Get-FileHash -LiteralPath $destinationFiles[$relativePath] -Algorithm SHA256).Hash
                if ($sourceHash -ne $destinationHash) {
                    $drift.Add("CHANGED skill/$skillName/$relativePath")
                }
            }

            foreach ($relativePath in $destinationFiles.Keys) {
                if (-not $sourceFiles.ContainsKey($relativePath)) {
                    $drift.Add("EXTRA skill/$skillName/$relativePath")
                }
            }
        }
    }

    if ($syncAgents) {
        foreach ($agentName in $manifest.agents) {
            $sourcePath = Join-Path $sourceAgentsRoot "$agentName.toml"
            $destinationPath = Join-Path $runtimeAgentsRoot "$agentName.toml"
            if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
                $drift.Add("MISSING agent/$agentName.toml")
                continue
            }

            $sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
            $destinationHash = (Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256).Hash
            if ($sourceHash -ne $destinationHash) {
                $drift.Add("CHANGED agent/$agentName.toml")
            }
        }
    }

    return @($drift)
}

function Copy-ManagedFiles {
    if ($syncSkills) {
        New-Item -ItemType Directory -Path $runtimeSkillsRoot -Force | Out-Null
        foreach ($skillName in $manifest.skills) {
            $sourceRoot = Join-Path $sourceSkillsRoot $skillName
            $destinationRoot = Join-Path $runtimeSkillsRoot $skillName
            $sourceFiles = Get-RelativeFileMap -Root $sourceRoot

            foreach ($relativePath in $sourceFiles.Keys) {
                $destinationPath = Join-Path $destinationRoot $relativePath
                $destinationDirectory = Split-Path -Parent $destinationPath
                New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
                Copy-Item -LiteralPath $sourceFiles[$relativePath] -Destination $destinationPath -Force
            }
        }
    }

    if ($syncAgents) {
        New-Item -ItemType Directory -Path $runtimeAgentsRoot -Force | Out-Null
        foreach ($agentName in $manifest.agents) {
            $sourcePath = Join-Path $sourceAgentsRoot "$agentName.toml"
            $destinationPath = Join-Path $runtimeAgentsRoot "$agentName.toml"
            Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
        }
    }
}

$initialDrift = @(Get-ManagedDrift)
if ($initialDrift.Count -eq 0) {
    Write-Output "VERIFIED runtime mirrors: $componentSummary"
    return
}

$initialDrift | ForEach-Object { Write-Output "DRIFT $_" }

if ($Mode -eq 'Verify') {
    throw "Runtime drift detected: $($initialDrift.Count) difference(s)"
}

Copy-ManagedFiles
$remainingDrift = @(Get-ManagedDrift)
if ($remainingDrift.Count -ne 0) {
    $remainingDrift | ForEach-Object { Write-Output "DRIFT $_" }
    throw "Runtime drift detected after Apply: $($remainingDrift.Count) difference(s); unmanaged files were not pruned"
}

Write-Output "SYNCHRONIZED runtime mirrors: $componentSummary"
