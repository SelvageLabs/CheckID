<#
.SYNOPSIS
    Searches the CheckID registry by CheckId, framework, control ID, or keyword.

.DESCRIPTION
    Query registry.json using flexible search criteria. Supports lookup by exact
    CheckId, filtering by framework key, searching by control ID pattern, and
    keyword search across check names. Returns formatted results to the console
    or raw objects for pipeline use.

.PARAMETER CheckId
    Exact CheckId to look up (e.g., ENTRA-ADMIN-001).

.PARAMETER Framework
    Filter checks that have a mapping for this framework key
    (e.g., nist-800-53, hipaa, soc2).

.PARAMETER ControlId
    Search for checks containing this control ID pattern (substring match).
    Searches across all frameworks unless -Framework is also specified.

.PARAMETER Keyword
    Search check names for this keyword (case-insensitive substring match).

.PARAMETER AsObject
    Return raw PSCustomObjects instead of formatted console output.
    Useful for piping to other commands.

.PARAMETER RegistryPath
    Path to registry.json. Defaults to data/registry.json relative to the
    repository root.

.EXAMPLE
    .\scripts\Search-Registry.ps1 -CheckId ENTRA-ADMIN-001
    Look up a specific check by its CheckId.

.EXAMPLE
    .\scripts\Search-Registry.ps1 -Framework hipaa
    List all checks mapped to the HIPAA framework.

.EXAMPLE
    .\scripts\Search-Registry.ps1 -ControlId "AC-6"
    Find checks referencing NIST 800-53 control AC-6 (any framework).

.EXAMPLE
    .\scripts\Search-Registry.ps1 -Keyword "MFA" -Framework nist-800-53
    Find checks mentioning MFA that have NIST 800-53 mappings.

.EXAMPLE
    .\scripts\Search-Registry.ps1 -Framework soc2 -AsObject | Export-Csv soc2.csv
    Export all SOC 2 mapped checks to CSV.
#>
[CmdletBinding(DefaultParameterSetName = 'Keyword')]
param(
    [Parameter(ParameterSetName = 'CheckId', Position = 0)]
    [string]$CheckId,

    [Parameter()]
    [string]$Framework,

    [Parameter(ParameterSetName = 'ControlId')]
    [string]$ControlId,

    [Parameter(ParameterSetName = 'Keyword', Position = 0)]
    [string]$Keyword,

    [Parameter()]
    [switch]$AsObject,

    [Parameter()]
    [string]$RegistryPath
)

# Resolve registry path
$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $RegistryPath) {
    $RegistryPath = Join-Path $repoRoot 'data' 'registry.json'
}

if (-not (Test-Path $RegistryPath)) {
    Write-Error "Registry not found: $RegistryPath"
    return
}

$registry = Get-Content -Path $RegistryPath -Raw | ConvertFrom-Json
$checks = $registry.checks

# --- Filter pipeline ---

# 1. CheckId exact match
if ($CheckId) {
    $checks = $checks | Where-Object { $_.checkId -eq $CheckId }
}

# 2. Framework filter
if ($Framework) {
    $checks = $checks | Where-Object {
        $_.frameworks.PSObject.Properties.Name -contains $Framework
    }
}

# 3. ControlId search (substring across all or specified framework)
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

# 4. Keyword search on check name
if ($Keyword) {
    $checks = $checks | Where-Object {
        $_.name -like "*$Keyword*"
    }
}

$results = @($checks)

if ($results.Count -eq 0) {
    Write-Host "No checks found matching the search criteria."
    return
}

# --- Output ---
if ($AsObject) {
    return $results
}

# Formatted console output
if ($CheckId -and $results.Count -eq 1) {
    # Detailed single-check view
    $check = $results[0]
    Write-Host ""
    Write-Host "  $($check.checkId)" -ForegroundColor Cyan -NoNewline
    Write-Host "  $($check.name)"
    Write-Host "  Category: $($check.category)  Collector: $($check.collector)  Automated: $($check.hasAutomatedCheck)  License: $($check.licensing.minimum)"

    $hasSuperBy = $check.PSObject.Properties.Name -contains 'supersededBy'
    if ($hasSuperBy) {
        Write-Host "  SupersededBy: $($check.supersededBy)" -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "  Frameworks:" -ForegroundColor White
    foreach ($fwProp in $check.frameworks.PSObject.Properties) {
        $fw = $fwProp.Value
        $hasTitle = $fw.PSObject.Properties.Name -contains 'title'
        $title = if ($hasTitle) { " — $($fw.title)" } else { '' }
        Write-Host "    $($fwProp.Name)" -ForegroundColor Green -NoNewline
        Write-Host "  $($fw.controlId)$title"
    }
    Write-Host ""
} else {
    # Table view for multiple results
    Write-Host ""
    Write-Host "  Found $($results.Count) checks" -ForegroundColor Cyan
    Write-Host ""

    $maxIdLen = ($results | ForEach-Object { $_.checkId.Length } | Measure-Object -Maximum).Maximum
    $maxIdLen = [Math]::Max($maxIdLen, 8)

    foreach ($check in $results) {
        $id = $check.checkId.PadRight($maxIdLen)
        $auto = if ($check.hasAutomatedCheck) { '[A]' } else { '[M]' }
        $fwCount = @($check.frameworks.PSObject.Properties).Count
        Write-Host "  $auto " -ForegroundColor DarkGray -NoNewline
        Write-Host "$id" -ForegroundColor Cyan -NoNewline
        Write-Host "  $($check.name)" -NoNewline
        Write-Host "  ($fwCount fw)" -ForegroundColor DarkGray
    }
    Write-Host ""
}
