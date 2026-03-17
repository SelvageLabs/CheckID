<#
.SYNOPSIS
    CheckID PowerShell module — stable identifiers for security checks mapped
    across compliance frameworks.
.DESCRIPTION
    Provides cmdlets to load, query, and validate the CheckID registry.
    Wraps the existing script-based functionality into proper module exports.
#>

# Module-scoped registry cache
$script:RegistryCache = $null
$script:ModuleRoot = $PSScriptRoot

function Get-CheckRegistry {
    <#
    .SYNOPSIS
        Loads the CheckID registry and returns all checks.
    .DESCRIPTION
        Reads data/registry.json and returns the full check collection.
        Results are cached for the session — call with -Force to reload.
    .PARAMETER Force
        Bypass the cache and reload from disk.
    .OUTPUTS
        PSCustomObject[] — array of check objects from registry.json.
    .EXAMPLE
        $checks = Get-CheckRegistry
        $checks | Where-Object { $_.hasAutomatedCheck } | Measure-Object
    #>
    [CmdletBinding()]
    param(
        [switch]$Force
    )

    if ($script:RegistryCache -and -not $Force) {
        return $script:RegistryCache
    }

    $registryPath = Join-Path $script:ModuleRoot 'data' 'registry.json'
    if (-not (Test-Path $registryPath)) {
        Write-Error "Registry not found: $registryPath"
        return
    }

    $raw = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
    $script:RegistryCache = $raw.checks
    return $script:RegistryCache
}

function Get-CheckById {
    <#
    .SYNOPSIS
        Looks up a single check by its CheckId.
    .PARAMETER CheckId
        The CheckId to look up (e.g., ENTRA-ADMIN-001).
    .OUTPUTS
        PSCustomObject — the matching check, or $null if not found.
    .EXAMPLE
        Get-CheckById -CheckId ENTRA-ADMIN-001
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$CheckId
    )

    $checks = Get-CheckRegistry
    return $checks | Where-Object { $_.checkId -eq $CheckId }
}

function Search-Check {
    <#
    .SYNOPSIS
        Searches the CheckID registry by framework, control ID, or keyword.
    .PARAMETER Framework
        Filter to checks mapped to this framework key (e.g., hipaa, soc2).
    .PARAMETER ControlId
        Search for checks containing this control ID substring.
    .PARAMETER Keyword
        Search check names for this keyword (case-insensitive).
    .OUTPUTS
        PSCustomObject[] — matching check objects.
    .EXAMPLE
        Search-Check -Framework hipaa -Keyword 'password'
    .EXAMPLE
        Search-Check -ControlId 'AC-6'
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Framework,

        [Parameter()]
        [string]$ControlId,

        [Parameter(Position = 0)]
        [string]$Keyword
    )

    $checks = Get-CheckRegistry

    if ($Framework) {
        $checks = $checks | Where-Object {
            $_.frameworks.PSObject.Properties.Name -contains $Framework
        }
    }

    if ($ControlId) {
        $checks = $checks | Where-Object {
            $found = $false
            foreach ($fwProp in $_.frameworks.PSObject.Properties) {
                if ($Framework -and $fwProp.Name -ne $Framework) { continue }
                if ($fwProp.Value.controlId -like "*$ControlId*") {
                    $found = $true
                    break
                }
            }
            $found
        }
    }

    if ($Keyword) {
        $checks = $checks | Where-Object {
            $_.name -like "*$Keyword*"
        }
    }

    return @($checks)
}

function Get-FrameworkCoverage {
    <#
    .SYNOPSIS
        Returns coverage statistics for each compliance framework in the registry.
    .DESCRIPTION
        Counts how many active (non-superseded) checks map to each compliance framework
        and returns a summary object per framework. Superseded MANUAL-CIS entries are
        excluded so counts reflect the active, non-duplicate check population.
        Useful for dashboards, gap analysis, and integration with downstream
        assessment tools such as M365-Assess and Darn.
    .PARAMETER Framework
        Limit results to a single framework key (e.g., 'hipaa', 'nist-800-53').
        If omitted, all frameworks are returned in alphabetical order.
    .OUTPUTS
        PSCustomObject[] — one object per framework with properties:
          FrameworkKey    — Registry key (e.g., 'nist-800-53')
          CheckCount      — Total active checks mapped to this framework
          AutomatedCount  — Checks with hasAutomatedCheck = $true
          ManualCount     — Checks with hasAutomatedCheck = $false
    .EXAMPLE
        Get-FrameworkCoverage
        Returns coverage for all 14 frameworks.
    .EXAMPLE
        Get-FrameworkCoverage -Framework 'hipaa'
        Returns coverage stats for HIPAA only.
    .EXAMPLE
        Get-FrameworkCoverage | Sort-Object CheckCount -Descending | Format-Table
        Show frameworks ranked by check coverage.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Framework
    )

    $checks = Get-CheckRegistry

    # Exclude superseded entries so counts reflect the active check population
    $active = @($checks | Where-Object {
        -not ($_.PSObject.Properties.Name -contains 'supersededBy')
    })

    # Collect all framework keys present across active checks
    $allFrameworks = [System.Collections.Generic.SortedSet[string]]::new()
    foreach ($check in $active) {
        foreach ($fw in $check.frameworks.PSObject.Properties.Name) {
            [void]$allFrameworks.Add($fw)
        }
    }

    $results = foreach ($fw in $allFrameworks) {
        if ($Framework -and $fw -ne $Framework) { continue }
        $mapped = @($active | Where-Object {
            $_.frameworks.PSObject.Properties.Name -contains $fw
        })
        [PSCustomObject]@{
            FrameworkKey   = $fw
            CheckCount     = $mapped.Count
            AutomatedCount = @($mapped | Where-Object { $_.hasAutomatedCheck -eq $true }).Count
            ManualCount    = @($mapped | Where-Object { $_.hasAutomatedCheck -ne $true }).Count
        }
    }

    return @($results)
}

function Test-CheckRegistryData {
    <#
    .SYNOPSIS
        Runs data quality validation checks against the registry.
    .DESCRIPTION
        Wrapper around scripts/Test-RegistryData.ps1. Returns $true if all
        checks pass, $false otherwise.
    .OUTPUTS
        Boolean — $true if all validation checks pass.
    .EXAMPLE
        if (-not (Test-CheckRegistryData)) { Write-Error "Registry validation failed" }
    #>
    [CmdletBinding()]
    param()

    $scriptPath = Join-Path $script:ModuleRoot 'scripts' 'Test-RegistryData.ps1'
    if (-not (Test-Path $scriptPath)) {
        Write-Error "Validation script not found: $scriptPath"
        return $false
    }

    & $scriptPath -DataPath (Join-Path $script:ModuleRoot 'data')
    return $LASTEXITCODE -eq 0
}

# Export module members
Export-ModuleMember -Function @(
    'Get-CheckRegistry'
    'Get-CheckById'
    'Search-Check'
    'Get-FrameworkCoverage'
    'Test-CheckRegistryData'
)
