<#
.SYNOPSIS
    Validates registry data integrity and encoding.
.DESCRIPTION
    Standalone validation script that checks the control registry and its source
    CSVs for common data quality issues:
      - UTF-8 encoding (detects garbled HIPAA section symbols)
      - Duplicate CheckIds
      - Empty required fields
      - CSV-to-JSON consistency (check counts match)

    Returns exit code 0 if all checks pass, 1 if any fail. Suitable for CI and
    local use.
.PARAMETER DataPath
    Path to the data directory containing registry.json and CSVs.
    Defaults to data/ relative to the repository root.
.EXAMPLE
    ./scripts/Test-RegistryData.ps1
    Validates all data files in the default data/ directory.
.EXAMPLE
    ./scripts/Test-RegistryData.ps1 -DataPath ./custom-data
    Validates data files in a custom directory.
.NOTES
    Version: 1.0.0
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$DataPath
)

$ErrorActionPreference = 'Stop'

# Resolve paths
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (-not $DataPath) {
    $DataPath = Join-Path $repoRoot 'data'
}

$registryPath    = Join-Path $DataPath 'registry.json'
$frameworkCsv    = Join-Path $DataPath 'framework-mappings.csv'
$checkIdCsv      = Join-Path $DataPath 'check-id-mapping.csv'
$standalonePath  = Join-Path $DataPath 'standalone-checks.json'

$errors   = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$passed   = 0

function Test-Check {
    param([string]$Name, [scriptblock]$Test)
    try {
        $result = & $Test
        if ($result) {
            $script:errors.Add("FAIL: $Name - $result")
            Write-Host "  FAIL: $Name" -ForegroundColor Red
            Write-Host "        $result" -ForegroundColor Red
        } else {
            $script:passed++
            Write-Host "  PASS: $Name" -ForegroundColor Green
        }
    } catch {
        $script:errors.Add("FAIL: $Name - $($_.Exception.Message)")
        Write-Host "  FAIL: $Name" -ForegroundColor Red
        Write-Host "        $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nCheckID Data Quality Validation" -ForegroundColor Cyan
Write-Host "================================`n"

# ------------------------------------------------------------------
# 1. File existence
# ------------------------------------------------------------------
Write-Host "File checks:" -ForegroundColor Yellow
foreach ($file in @($registryPath, $frameworkCsv, $checkIdCsv)) {
    $name = Split-Path $file -Leaf
    Test-Check "File exists: $name" {
        if (-not (Test-Path $file)) { return "File not found: $file" }
    }
}

if (-not (Test-Path $registryPath) -or -not (Test-Path $frameworkCsv) -or -not (Test-Path $checkIdCsv)) {
    Write-Host "`nCritical files missing — cannot continue." -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------------
# 2. JSON validity
# ------------------------------------------------------------------
Write-Host "`nJSON checks:" -ForegroundColor Yellow
$reg = $null
Test-Check "registry.json is valid JSON" {
    try {
        $script:reg = Get-Content $registryPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return "Invalid JSON: $($_.Exception.Message)"
    }
}

if (-not $reg) { Write-Host "`nRegistry JSON invalid — cannot continue." -ForegroundColor Red; exit 1 }

Test-Check "registry.json has schemaVersion" {
    if (-not $reg.schemaVersion) { return "Missing schemaVersion field" }
    if ($reg.schemaVersion -notmatch '^\d+\.\d+\.\d+$') { return "schemaVersion '$($reg.schemaVersion)' is not valid semver" }
}

Test-Check "registry.json has dataVersion" {
    if (-not $reg.dataVersion) { return "Missing dataVersion field" }
    if ($reg.dataVersion -notmatch '^\d{4}-\d{2}-\d{2}$') { return "dataVersion '$($reg.dataVersion)' is not YYYY-MM-DD" }
}

# ------------------------------------------------------------------
# 3. Duplicate CheckIds
# ------------------------------------------------------------------
Write-Host "`nUniqueness checks:" -ForegroundColor Yellow
Test-Check "No duplicate CheckIds in registry" {
    $dupes = $reg.checks | ForEach-Object { $_.checkId } | Group-Object | Where-Object { $_.Count -gt 1 }
    if ($dupes) {
        $names = ($dupes | ForEach-Object { "$($_.Name) (x$($_.Count))" }) -join ', '
        return "Duplicate CheckIds: $names"
    }
}

# ------------------------------------------------------------------
# 4. Required fields
# ------------------------------------------------------------------
Write-Host "`nRequired field checks:" -ForegroundColor Yellow
Test-Check "All checks have checkId, name, frameworks" {
    $bad = @()
    foreach ($c in $reg.checks) {
        if (-not $c.checkId) { $bad += "missing checkId" }
        elseif (-not $c.name) { $bad += "$($c.checkId): missing name" }
        elseif (-not $c.frameworks) { $bad += "$($c.checkId): missing frameworks" }
    }
    if ($bad.Count -gt 0) { return ($bad | Select-Object -First 5) -join '; ' }
}

Test-Check "All automated checks have collector" {
    $bad = @()
    foreach ($c in $reg.checks) {
        if ($c.hasAutomatedCheck -eq $true -and [string]::IsNullOrWhiteSpace($c.collector)) {
            $bad += $c.checkId
        }
    }
    if ($bad.Count -gt 0) { return "Missing collector on: $($bad -join ', ')" }
}

# ------------------------------------------------------------------
# 5. Encoding checks
# ------------------------------------------------------------------
Write-Host "`nEncoding checks:" -ForegroundColor Yellow
Test-Check "HIPAA control IDs have correct section symbol encoding" {
    $garbled = @()
    foreach ($c in $reg.checks) {
        if ($c.frameworks.PSObject.Properties.Name -contains 'hipaa') {
            $val = $c.frameworks.hipaa.controlId
            if ($val -match 'Â§') {
                $garbled += $c.checkId
            }
        }
    }
    if ($garbled.Count -gt 0) { return "Garbled section symbol (Â§) in: $($garbled -join ', ')" }
}

Test-Check "framework-mappings.csv HIPAA values have correct encoding" {
    $fm = Import-Csv $frameworkCsv
    $garbled = @()
    foreach ($row in $fm) {
        if ($row.Hipaa -match 'Â§') {
            $garbled += $row.CisControl
        }
    }
    if ($garbled.Count -gt 0) { return "Garbled section symbol in CSV rows: $($garbled -join ', ')" }
}

# ------------------------------------------------------------------
# 6. CSV-to-JSON consistency
# ------------------------------------------------------------------
Write-Host "`nConsistency checks:" -ForegroundColor Yellow
Test-Check "Registry check count matches CSV derivation" {
    $fm = Import-Csv $frameworkCsv
    $cid = Import-Csv $checkIdCsv
    $sa = if (Test-Path $standalonePath) { @(Get-Content $standalonePath -Raw | ConvertFrom-Json) } else { @() }
    $expected = $fm.Count + $sa.Count
    $actual = $reg.checks.Count
    if ($actual -ne $expected) {
        return "Expected $expected checks ($($fm.Count) CIS + $($sa.Count) standalone), got $actual"
    }
}

Test-Check "CSV column schemas are valid" {
    $fm = Import-Csv $frameworkCsv
    $cid = Import-Csv $checkIdCsv
    $fmExpected = @('CisControl','CisTitle','CisE3L1','CisE3L2','CisE5L1','CisE5L2','NistCsf','Nist80053','Iso27001','Stig','PciDss','Cmmc','Hipaa','CisaScuba')
    $cidExpected = @('CisControl','CheckId','Collector','Area','Name','ImpactSeverity')
    $fmMissing = $fmExpected | Where-Object { $_ -notin $fm[0].PSObject.Properties.Name }
    $cidMissing = $cidExpected | Where-Object { $_ -notin $cid[0].PSObject.Properties.Name }
    $issues = @()
    if ($fmMissing) { $issues += "framework-mappings.csv missing: $($fmMissing -join ', ')" }
    if ($cidMissing) { $issues += "check-id-mapping.csv missing: $($cidMissing -join ', ')" }
    if ($issues) { return $issues -join '; ' }
}

# ------------------------------------------------------------------
# Summary
# ------------------------------------------------------------------
Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Passed: $passed" -ForegroundColor Green
if ($errors.Count -gt 0) {
    Write-Host "Failed: $($errors.Count)" -ForegroundColor Red
    exit 1
} else {
    Write-Host "All data quality checks passed." -ForegroundColor Green
    exit 0
}
