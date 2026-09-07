[CmdletBinding()]
param(
    [ValidateSet('Verify', 'Apply')]
    [string]$Mode = 'Verify',

    [ValidateSet('All', 'Skills', 'Agents')]
    [string]$Components = 'All',

    [switch]$ReplaceChanged,

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

function Assert-NoReparsePoint {
    param([Parameter(Mandatory)][string]$Path)

    $candidate = [System.IO.Path]::GetFullPath($Path)
    while ($candidate) {
        try {
            $attributes = [System.IO.File]::GetAttributes($candidate)
        } catch [System.IO.FileNotFoundException], [System.IO.DirectoryNotFoundException] {
            $attributes = $null
        }
        if ($null -ne $attributes -and ($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Runtime path must not traverse a reparse point: $candidate"
        }
        $parent = [System.IO.Directory]::GetParent($candidate)
        if ($null -eq $parent) {
            break
        }
        $candidate = $parent.FullName
    }
}

function Assert-SafeDestination {
    param([Parameter(Mandatory)][string]$Path)

    $candidate = [System.IO.Path]::GetFullPath($Path)
    if (
        $candidate -ne $resolvedRuntimeRoot -and
        -not $candidate.StartsWith("$resolvedRuntimeRoot\", [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        throw "Destination escapes runtime root: $candidate"
    }
    Assert-NoReparsePoint -Path $candidate

    $ancestor = [System.IO.Directory]::GetParent($candidate)
    while ($null -ne $ancestor) {
        $ancestorPath = $ancestor.FullName
        if (
            $ancestorPath -ne $resolvedRuntimeRoot -and
            -not $ancestorPath.StartsWith("$resolvedRuntimeRoot\", [System.StringComparison]::OrdinalIgnoreCase)
        ) {
            break
        }
        if ((Test-Path -LiteralPath $ancestorPath) -and -not (Test-Path -LiteralPath $ancestorPath -PathType Container)) {
            throw "Destination ancestor must be a directory: $ancestorPath"
        }
        if ($ancestorPath -eq $resolvedRuntimeRoot) {
            break
        }
        $ancestor = $ancestor.Parent
    }
}

if (-not $resolvedRuntimeRoot -or $resolvedRuntimeRoot -eq $pathRoot) {
    throw "Unsafe runtime root: $resolvedRuntimeRoot"
}
if (
    $resolvedRuntimeRoot -eq $repoRoot -or
    $repoRoot.StartsWith("$resolvedRuntimeRoot\", [System.StringComparison]::OrdinalIgnoreCase) -or
    $resolvedRuntimeRoot.StartsWith("$repoRoot\", [System.StringComparison]::OrdinalIgnoreCase)
) {
    throw "Runtime root overlaps the authoring repository: $resolvedRuntimeRoot"
}
Assert-NoReparsePoint -Path $resolvedRuntimeRoot

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
    param(
        [Parameter(Mandatory)][string]$Root,
        [switch]$RuntimeDestination
    )

    $map = @{}
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        return $map
    }

    $normalizedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    if ($RuntimeDestination) {
        Assert-SafeDestination -Path $normalizedRoot
    } else {
        Assert-NoReparsePoint -Path $normalizedRoot
    }
    $pending = [System.Collections.Generic.Stack[string]]::new()
    $pending.Push($normalizedRoot)
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Managed path must not contain a reparse point: $($item.FullName)"
            }
            if ($item.PSIsContainer) {
                $pending.Push($item.FullName)
                continue
            }
            $relativePath = $item.FullName.Substring($normalizedRoot.Length).TrimStart('\')
            if ($relativePath -match '(^|\\)__pycache__(\\|$)' -or $relativePath -match '\.pyc$') {
                continue
            }
            $map[$relativePath] = $item.FullName
        }
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
            Assert-SafeDestination -Path $destinationRoot
            $destinationFiles = Get-RelativeFileMap -Root $destinationRoot -RuntimeDestination

            foreach ($relativePath in $sourceFiles.Keys) {
                [void]$destinationFiles.Remove("$relativePath.bak")
            }

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
            Assert-SafeDestination -Path $destinationPath
            if (-not (Test-Path -LiteralPath $destinationPath -PathType Leaf)) {
                if (Test-Path -LiteralPath $destinationPath) {
                    throw "Agent destination must be a regular file: $destinationPath"
                }
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

function Add-CopyPlanEntry {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )

    Assert-SafeDestination -Path $Destination
    $changed = Test-Path -LiteralPath $Destination -PathType Leaf
    if ($changed) {
        $sourceHash = (Get-FileHash -LiteralPath $Source -Algorithm SHA256).Hash
        $destinationHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
        if ($sourceHash -eq $destinationHash -or -not $ReplaceChanged) {
            return
        }
    } elseif (Test-Path -LiteralPath $Destination) {
        throw "Managed destination must be a regular file: $Destination"
    }

    $backupPath = if ($changed) { "$Destination.bak" } else { $null }
    if ($backupPath) {
        Assert-SafeDestination -Path $backupPath
        if (Test-Path -LiteralPath $backupPath) {
            throw "Refusing to overwrite existing backup: $backupPath"
        }
    }
    $temporaryPath = Join-Path (Split-Path -Parent $Destination) ".$(Split-Path -Leaf $Destination).codex-essentials-$PID.tmp"
    Assert-SafeDestination -Path $temporaryPath
    if (Test-Path -LiteralPath $temporaryPath) {
        throw "Temporary destination already exists: $temporaryPath"
    }
    return [pscustomobject]@{
        Source = $Source
        Destination = $Destination
        Backup = $backupPath
        Temporary = $temporaryPath
    }
}

function Get-CopyPlan {
    $plan = [System.Collections.Generic.List[object]]::new()
    if ($syncSkills) {
        foreach ($skillName in $manifest.skills) {
            $sourceRoot = Join-Path $sourceSkillsRoot $skillName
            $destinationRoot = Join-Path $runtimeSkillsRoot $skillName
            $sourceFiles = Get-RelativeFileMap -Root $sourceRoot
            foreach ($relativePath in $sourceFiles.Keys) {
                $entry = Add-CopyPlanEntry -Source $sourceFiles[$relativePath] -Destination (Join-Path $destinationRoot $relativePath)
                if ($null -ne $entry) { $plan.Add($entry) }
            }
        }
    }
    if ($syncAgents) {
        foreach ($agentName in $manifest.agents) {
            $entry = Add-CopyPlanEntry -Source (Join-Path $sourceAgentsRoot "$agentName.toml") -Destination (Join-Path $runtimeAgentsRoot "$agentName.toml")
            if ($null -ne $entry) { $plan.Add($entry) }
        }
    }
    return @($plan)
}

function Copy-ManagedFiles {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Plan)

    foreach ($item in $Plan) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $item.Destination) -Force | Out-Null
        if ($item.Backup) {
            Copy-Item -LiteralPath $item.Destination -Destination $item.Backup
        }
        try {
            Copy-Item -LiteralPath $item.Source -Destination $item.Temporary
            Move-Item -LiteralPath $item.Temporary -Destination $item.Destination -Force
        } finally {
            if (Test-Path -LiteralPath $item.Temporary) {
                Remove-Item -LiteralPath $item.Temporary -Force
            }
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

$copyPlan = @(Get-CopyPlan)
Copy-ManagedFiles -Plan $copyPlan
$remainingDrift = @(Get-ManagedDrift)
if ($remainingDrift.Count -ne 0) {
    $remainingDrift | ForEach-Object { Write-Output "DRIFT $_" }
    if (-not $ReplaceChanged -and ($remainingDrift | Where-Object { $_ -like 'CHANGED *' })) {
        Write-Warning 'Changed managed files were preserved; inspect them and rerun with -ReplaceChanged to create .bak files and replace them.'
    }
    throw "Runtime drift detected after Apply: $($remainingDrift.Count) difference(s); unmanaged files were not pruned"
}

Write-Output "SYNCHRONIZED runtime mirrors: $componentSummary"
