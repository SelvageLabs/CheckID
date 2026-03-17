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
$script:RegistryIndex = $null
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

    # Build hash index for O(1) lookups
    $script:RegistryIndex = @{}
    foreach ($check in $script:RegistryCache) {
        $script:RegistryIndex[$check.checkId] = $check
    }

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

    if (-not $script:RegistryIndex) { Get-CheckRegistry | Out-Null }
    return $script:RegistryIndex[$CheckId]
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
    'Test-CheckRegistryData'
)
