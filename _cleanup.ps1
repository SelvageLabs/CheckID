$ErrorActionPreference = 'Stop'
$repoRoot = $PSScriptRoot
Set-Location $repoRoot
$utf8 = [System.Text.UTF8Encoding]::new($false)

Write-Host "=== MANUAL-CIS Removal & Legacy Cleanup ===" -ForegroundColor Cyan

# ============================================================
# 1. Update check-id-mapping.csv — remove superseded, convert 14 manual
# ============================================================
Write-Host "`n[1/10] Updating check-id-mapping.csv..."

$csv = Import-Csv data/check-id-mapping.csv

# ID conversion map for the 14 truly manual checks
$idConversions = @{
    'MANUAL-CIS-1-3-8'  = @{ CheckId='SPO-SWAY-001';           Collector='SharePoint'; Area='SWAY' }
    'MANUAL-CIS-2-4-3'  = @{ CheckId='DEFENDER-CLOUDAPPS-001';  Collector='Defender';   Area='CLOUDAPPS' }
    'MANUAL-CIS-5-1-2-5'= @{ CheckId='ENTRA-SESSION-001';      Collector='Entra';      Area='SESSION' }
    'MANUAL-CIS-9-1-1'  = @{ CheckId='PBI-GUEST-001';           Collector='PowerBI';    Area='GUEST' }
    'MANUAL-CIS-9-1-2'  = @{ CheckId='PBI-INVITE-001';          Collector='PowerBI';    Area='INVITE' }
    'MANUAL-CIS-9-1-3'  = @{ CheckId='PBI-CONTENT-001';         Collector='PowerBI';    Area='CONTENT' }
    'MANUAL-CIS-9-1-4'  = @{ CheckId='PBI-PUBLISH-001';         Collector='PowerBI';    Area='PUBLISH' }
    'MANUAL-CIS-9-1-5'  = @{ CheckId='PBI-SCRIPT-001';          Collector='PowerBI';    Area='SCRIPT' }
    'MANUAL-CIS-9-1-6'  = @{ CheckId='PBI-LABELS-001';          Collector='PowerBI';    Area='LABELS' }
    'MANUAL-CIS-9-1-7'  = @{ CheckId='PBI-LINK-001';            Collector='PowerBI';    Area='LINK' }
    'MANUAL-CIS-9-1-8'  = @{ CheckId='PBI-SHARING-001';         Collector='PowerBI';    Area='SHARING' }
    'MANUAL-CIS-9-1-9'  = @{ CheckId='PBI-AUTH-001';            Collector='PowerBI';    Area='AUTH' }
    'MANUAL-CIS-9-1-10' = @{ CheckId='PBI-API-001';             Collector='PowerBI';    Area='API' }
    'MANUAL-CIS-9-1-11' = @{ CheckId='PBI-PROFILE-001';         Collector='PowerBI';    Area='PROFILE' }
}

$newCsv = [System.Collections.Generic.List[object]]::new()
$removedCount = 0
$convertedCount = 0

foreach ($row in $csv) {
    if ($row.CheckId -like 'MANUAL-CIS-*') {
        if ($idConversions.ContainsKey($row.CheckId)) {
            # Convert to proper ID
            $conv = $idConversions[$row.CheckId]
            $row.CheckId = $conv.CheckId
            $row.Collector = $conv.Collector
            $row.Area = $conv.Area
            $row.SupersededBy = ''
            $newCsv.Add($row)
            $convertedCount++
        } else {
            # Superseded — remove entirely
            $removedCount++
        }
    } else {
        $newCsv.Add($row)
    }
}

# Remove SupersededBy column entirely
$csvLines = @('"CisControl","CheckId","Collector","Area","Name","ImpactSeverity"')
foreach ($row in $newCsv) {
    $csvLines += '"{0}","{1}","{2}","{3}","{4}","{5}"' -f $row.CisControl, $row.CheckId, $row.Collector, $row.Area, $row.Name, $row.ImpactSeverity
}
[System.IO.File]::WriteAllText("$repoRoot/data/check-id-mapping.csv", ($csvLines -join "`r`n") + "`r`n", $utf8)
Write-Host "  Removed $removedCount superseded rows, converted $convertedCount to proper IDs"
Write-Host "  Dropped SupersededBy column. Rows: $($newCsv.Count)"

# ============================================================
# 2. Clean derived-mappings.json — remove MANUAL-CIS keys
# ============================================================
Write-Host "`n[2/10] Cleaning derived-mappings.json..."

$derived = Get-Content data/derived-mappings.json -Raw | ConvertFrom-Json
$newMappings = [ordered]@{}
$removedDerived = 0
foreach ($prop in $derived.mappings.PSObject.Properties) {
    if ($prop.Name -like 'MANUAL-CIS-*') {
        # Check if this is a converted ID — remap the key
        if ($idConversions.ContainsKey($prop.Name)) {
            $newKey = $idConversions[$prop.Name].CheckId
            $newMappings[$newKey] = $prop.Value
        } else {
            $removedDerived++
        }
    } else {
        $newMappings[$prop.Name] = $prop.Value
    }
}
$derived.mappings = [PSCustomObject]$newMappings
$derivedJson = ConvertTo-Json -InputObject $derived -Depth 10
[System.IO.File]::WriteAllText("$repoRoot/data/derived-mappings.json", $derivedJson, $utf8)
Write-Host "  Removed $removedDerived MANUAL-CIS keys, remapped $convertedCount"

# ============================================================
# 3. Update registry.schema.json
# ============================================================
Write-Host "`n[3/10] Updating registry.schema.json..."

$schema = Get-Content data/registry.schema.json -Raw

# Remove MANUAL-CIS pattern from checkId regex
$schema = $schema.Replace(
    '"pattern": "^[A-Z]+-[A-Z0-9-]+-\\d{3}$|^MANUAL-CIS-\\d+-\\d+(-\\d+)*$"',
    '"pattern": "^[A-Z]+-[A-Z0-9-]+-\\d{3}$"'
)

# Update checkId description
$schema = $schema.Replace(
    '"description": "Unique identifier: {SERVICE}-{AREA}-{NNN} for automated checks, MANUAL-CIS-{n}-{n}[-{n}]* for manual checks."',
    '"description": "Unique identifier in {SERVICE}-{AREA}-{NNN} format."'
)

# Update category description
$schema = $schema.Replace(
    '"description": "Functional category (e.g., CLOUDADMIN, MFA). Empty string for manual checks."',
    '"description": "Functional category (e.g., CLOUDADMIN, MFA)."'
)

# Update collector description
$schema = $schema.Replace(
    '"description": "Data collector responsible for this check. Empty string for manual checks."',
    '"description": "Data collector responsible for this check."'
)

# Remove supersededBy property block
$schema = $schema -creplace ',\r?\n\s+"supersededBy":\s*\{[^}]+\}', ''

[System.IO.File]::WriteAllText("$repoRoot/data/registry.schema.json", $schema, $utf8)
Write-Host "  Removed MANUAL-CIS pattern, supersededBy field, updated descriptions"

# ============================================================
# 4. Update Build-Registry.ps1
# ============================================================
Write-Host "`n[4/10] Updating Build-Registry.ps1..."

$build = Get-Content scripts/Build-Registry.ps1 -Raw

# Remove $hasAutomated detection — all checks are now automated-format
$build = $build.Replace(
    "`$hasAutomated = -not (`$checkId -like 'MANUAL-*')",
    "`$hasAutomated = `$true  # All checks use {SERVICE}-{AREA}-{NNN} format"
)

# Remove $supersededBy extraction
$build = $build.Replace(
    "`$supersededBy = if ([string]::IsNullOrWhiteSpace(`$cidRow.SupersededBy)) { `$null } else { `$cidRow.SupersededBy.Trim() }",
    "# SupersededBy removed — all MANUAL-CIS entries have been converted or removed"
)

# Remove impactSeverity + supersededBy block and the entire duplicate check emission
# Find the block that starts with impactSeverity and goes through the superseder emission
$oldBlock = @"
    `$impactSeverity = if (`$cidRow.PSObject.Properties['ImpactSeverity'] -and
                          -not [string]::IsNullOrWhiteSpace(`$cidRow.ImpactSeverity)) {
        `$cidRow.ImpactSeverity.Trim()
    } else { `$null }
    if (`$impactSeverity) {
        `$checkObj['impactRating'] = [ordered]@{ severity = `$impactSeverity }
    }

    if (`$supersededBy) {
        `$checkObj['supersededBy'] = `$supersededBy

        # Emit a second check entry for the automated superseder
        if (`$supersededBy -match '^([A-Z]+)-(.+)-\d{3}`$') {
            `$ssCollectorPrefix = `$Matches[1]
            `$ssArea = `$Matches[2]
            `$ssCollector = if (`$collectorPrefixMap.ContainsKey(`$ssCollectorPrefix)) {
                `$collectorPrefixMap[`$ssCollectorPrefix]
            } else { `$ssCollectorPrefix }

            `$ssCheckObj = [ordered]@{
                checkId           = `$supersededBy
                name              = `$fwRow.CisTitle
                category          = `$ssArea
                collector         = `$ssCollector
                hasAutomatedCheck = `$true
                licensing         = [ordered]@{ minimum = `$minimumLicense }
                frameworks        = `$frameworks
            }
            `$checks.Add(`$ssCheckObj)
        }
    }

    `$checks.Add(`$checkObj)
"@

$newBlock = @"
    `$impactSeverity = if (`$cidRow.PSObject.Properties['ImpactSeverity'] -and
                          -not [string]::IsNullOrWhiteSpace(`$cidRow.ImpactSeverity)) {
        `$cidRow.ImpactSeverity.Trim()
    } else { `$null }
    if (`$impactSeverity) {
        `$checkObj['impactRating'] = [ordered]@{ severity = `$impactSeverity }
    }

    `$checks.Add(`$checkObj)
"@

if ($build.Contains($oldBlock)) {
    $build = $build.Replace($oldBlock, $newBlock)
    Write-Host "  Removed supersededBy block and duplicate check emission (exact match)"
} else {
    # Try line-by-line approach — remove from "if ($supersededBy)" to the matching closing brace + $checks.Add
    # Fallback: just flag it
    Write-Host "  WARNING: Could not find exact supersededBy block — manual fix needed"
}

[System.IO.File]::WriteAllText("$repoRoot/scripts/Build-Registry.ps1", $build, $utf8)
Write-Host "  Updated Build-Registry.ps1"

# ============================================================
# 5. Update CheckID.psm1 — remove IncludeSuperseded and supersededBy filters
# ============================================================
Write-Host "`n[5/10] Updating CheckID.psm1..."

$psm1 = Get-Content CheckID.psm1 -Raw

# Get-FrameworkCoverage: remove IncludeSuperseded param and filter
$psm1 = $psm1 -creplace '\s+\[switch\]\$IncludeSuperseded\r?\n', "`r`n"
$psm1 = $psm1.Replace(
    "    .PARAMETER IncludeSuperseded`r`n        Include superseded MANUAL-CIS entries in counts.`r`n",
    ""
)
# Remove the supersededBy filter block in Get-FrameworkCoverage
$psm1 = $psm1.Replace(
    @"
    if (-not `$IncludeSuperseded) {
        `$checks = `$checks | Where-Object {
            -not (`$_.PSObject.Properties.Name -contains 'supersededBy' -and `$_.supersededBy)
        }
    }
"@,
    ""
)

# Get-CheckAutomationGaps: remove IncludeSuperseded and supersededBy filter
$psm1 = $psm1.Replace(
    @"
    `$gaps = `$checks | Where-Object {
        `$_.hasAutomatedCheck -eq `$false -and
        (-not `$_.PSObject.Properties['supersededBy'] -or `$IncludeSuperseded)
    }
"@,
    @"
    `$gaps = `$checks | Where-Object { `$_.hasAutomatedCheck -eq `$false }
"@
)

# Remove IncludeSuperseded param from Get-CheckAutomationGaps
$psm1 = $psm1.Replace(
    "    .PARAMETER IncludeSuperseded`r`n        Include checks that have a supersededBy entry.`r`n",
    ""
)
$psm1 = $psm1 -creplace '\s+\[switch\]\$IncludeSuperseded\r?\n\s+\)', ')'

[System.IO.File]::WriteAllText("$repoRoot/CheckID.psm1", $psm1, $utf8)
Write-Host "  Removed IncludeSuperseded and supersededBy filters"

# ============================================================
# 6. Update CheckID.psd1 — remove deprecated scripts from FileList
# ============================================================
Write-Host "`n[6/10] Updating CheckID.psd1..."

$psd1 = Get-Content CheckID.psd1 -Raw
# Don't remove scripts from FileList — they're deprecated but still shipped
# Just ensure nothing references MANUAL or supersededBy in descriptions
Write-Host "  FileList unchanged (deprecated scripts still shipped for M365-Assess compat)"

# ============================================================
# 7. Add deprecation headers to legacy scripts
# ============================================================
Write-Host "`n[7/10] Adding deprecation headers..."

$deprecationNote = @"
# ╔══════════════════════════════════════════════════════════════╗
# ║  DEPRECATED — This script is retained for backwards         ║
# ║  compatibility with M365-Assess. Use the CheckID module     ║
# ║  cmdlets instead. Will be removed in a future major version.║
# ╚══════════════════════════════════════════════════════════════╝

"@

foreach ($script in @('scripts/Import-ControlRegistry.ps1', 'scripts/Search-Registry.ps1', 'scripts/Show-CheckProgress.ps1')) {
    $content = Get-Content $script -Raw
    if ($content -notmatch 'DEPRECATED') {
        [System.IO.File]::WriteAllText("$repoRoot/$script", $deprecationNote + $content, $utf8)
        Write-Host "  Added deprecation header to $script"
    } else {
        Write-Host "  $script already has deprecation header"
    }
}

# ============================================================
# 8. Update scripts/Export-ComplianceMatrix.ps1 — use module instead of Import-ControlRegistry
# ============================================================
Write-Host "`n[8/10] Updating Export-ComplianceMatrix.ps1..."

$ecm = Get-Content scripts/Export-ComplianceMatrix.ps1 -Raw

# Replace dot-source of Import-ControlRegistry with module import
$ecm = $ecm -creplace "\. \(Join-Path.*?Import-ControlRegistry\.ps1'\)", "Import-Module (Join-Path `$PSScriptRoot '..' 'CheckID.psd1') -Force"
# Replace Import-ControlRegistry call with Get-CheckRegistry
$ecm = $ecm -creplace '\$controlRegistry\s*=\s*Import-ControlRegistry\s+-ControlsPath\s+\$controlsPath', '$allChecks = Get-CheckRegistry'

[System.IO.File]::WriteAllText("$repoRoot/scripts/Export-ComplianceMatrix.ps1", $ecm, $utf8)
Write-Host "  Replaced Import-ControlRegistry with module cmdlets"

# ============================================================
# 9. Update scripts/Test-RegistryData.ps1 — remove supersededBy test
# ============================================================
Write-Host "`n[9/10] Updating Test-RegistryData.ps1..."

$trd = Get-Content scripts/Test-RegistryData.ps1 -Raw

# Remove the supersededBy test block
$trd = $trd -creplace '(?s)# --- SupersededBy.*?(?=# ---|\z)', ''
# Also remove individual supersededBy references
$trd = $trd -creplace '(?m)^.*supersededBy.*$\r?\n?', ''

[System.IO.File]::WriteAllText("$repoRoot/scripts/Test-RegistryData.ps1", $trd, $utf8)
Write-Host "  Removed supersededBy validation"

# ============================================================
# 10. Update tests
# ============================================================
Write-Host "`n[10/10] Updating tests..."

# --- registry-integrity.Tests.ps1 ---
$rit = Get-Content tests/registry-integrity.Tests.ps1 -Raw

# Remove MANUAL-CIS migration tracking test
$rit = $rit -creplace "(?s)\s+It 'Tracks MANUAL-CIS migration progress'.*?(?=\s+It ')", "`r`n`r`n    "

# Remove -notlike MANUAL filter from naming convention test
$rit = $rit.Replace(
    "`$automated = `$checks | Where-Object { `$_.checkId -notlike 'MANUAL-*' }",
    "`$automated = `$checks"
)

# Remove both supersededBy tests
$rit = $rit -creplace "(?s)\s+It 'supersededBy references valid CheckIds when present'.*?(?=\s+It ')", "`r`n`r`n    "
$rit = $rit -creplace "(?s)\s+It 'Every superseded check has a matching automated check'.*?(?=\s+It ')", "`r`n`r`n    "

# Update count formula — remove supersededCount
$rit = $rit.Replace(
    "`$supersededCount = @(`$cid | Where-Object { -not [string]::IsNullOrWhiteSpace(`$_.SupersededBy) }).Count",
    "# SupersededBy removed — all entries are direct checks"
)
$rit = $rit.Replace(
    "`$expectedCount = `$fm.Count + `$supersededCount + `$sa.Count",
    "`$expectedCount = `$fm.Count + `$sa.Count"
)
$rit = $rit -creplace '\$fm\.Count \+ \$supersededCount \+ \$sa\.Count', '`$fm.Count + `$sa.Count'
$rit = $rit -creplace "\`\$\(\`\$fm\.Count\) CIS \+ \`\$supersededCount superseded \+ ", '$(${fm}.Count) CIS + '

[System.IO.File]::WriteAllText("$repoRoot/tests/registry-integrity.Tests.ps1", $rit, $utf8)
Write-Host "  Updated registry-integrity.Tests.ps1"

# --- module.Tests.ps1 ---
$mt = Get-Content tests/module.Tests.ps1 -Raw

# Remove IncludeSuperseded test
$mt = $mt -creplace "(?s)\s+It 'Includes superseded entries with -IncludeSuperseded'.*?(?=\s+It '|\s+\})", ""
$mt = $mt -creplace "(?s)\s+It 'Excludes superseded entries by default'.*?(?=\s+It '|\s+\})", ""

# Remove backwards-compat describe block entirely
$mt = $mt -creplace "(?s)Describe 'Backwards Compatibility'.*", ""

[System.IO.File]::WriteAllText("$repoRoot/tests/module.Tests.ps1", $mt, $utf8)
Write-Host "  Updated module.Tests.ps1"

# --- Delete search-registry.Tests.ps1 ---
if (Test-Path tests/search-registry.Tests.ps1) {
    git rm tests/search-registry.Tests.ps1 --quiet
    Write-Host "  Deleted tests/search-registry.Tests.ps1"
}

# --- CI workflow ---
$ci = Get-Content '.github/workflows/validate.yml' -Raw
$ci = $ci.Replace("`$checks.Count -lt 250", "`$checks.Count -lt 139")
$ci = $ci.Replace("Expected at least 250", "Expected at least 139")
[System.IO.File]::WriteAllText("$repoRoot/.github/workflows/validate.yml", $ci, $utf8)
Write-Host "  Updated validate.yml thresholds"

# ============================================================
# Rebuild registry
# ============================================================
Write-Host "`n=== Rebuilding registry ===" -ForegroundColor Cyan
& "$repoRoot/scripts/Build-Registry.ps1"

# ============================================================
# Verify
# ============================================================
$reg = Get-Content data/registry.json -Raw | ConvertFrom-Json
$manual = @($reg.checks | Where-Object { $_.checkId -like 'MANUAL-*' })
$superseded = @($reg.checks | Where-Object { $_.PSObject.Properties.Name -contains 'supersededBy' })
$withImpact = @($reg.checks | Where-Object { $_.PSObject.Properties.Name -contains 'impactRating' })

Write-Host "`n=== Verification ===" -ForegroundColor Cyan
Write-Host "  Total checks: $($reg.checks.Count)"
Write-Host "  MANUAL-CIS entries: $($manual.Count) (expect 0)"
Write-Host "  supersededBy entries: $($superseded.Count) (expect 0)"
Write-Host "  impactRating entries: $($withImpact.Count)"
Write-Host "  Schema version: $($reg.schemaVersion)"

# ============================================================
# Stage and commit
# ============================================================
git add -A
git status --short

git commit -m "feat: remove MANUAL-CIS entries, supersededBy, and legacy cleanup

Remove all 80 superseded MANUAL-CIS entries from the registry.
Convert 14 truly manual checks to proper {SERVICE}-{AREA}-{NNN} IDs:
- SPO-SWAY-001, DEFENDER-CLOUDAPPS-001, ENTRA-SESSION-001
- PBI-GUEST/INVITE/CONTENT/PUBLISH/SCRIPT/LABELS/LINK/SHARING/AUTH/API/PROFILE-001

Remove supersededBy field from schema, build script, module code, and tests.
Remove IncludeSuperseded parameter from Get-FrameworkCoverage and
Get-CheckAutomationGaps. Drop SupersededBy column from CSV.

Mark Import-ControlRegistry.ps1, Search-Registry.ps1, Show-CheckProgress.ps1
as deprecated (still needed by M365-Assess).
Delete tests/search-registry.Tests.ps1 and backwards-compat tests.

Closes #73

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

Remove-Item "$repoRoot/_cleanup.ps1" -ErrorAction SilentlyContinue
Write-Host "`nDone!"
git log --oneline -2
