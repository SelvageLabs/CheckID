Describe 'Control Registry Integrity' {
    BeforeAll {
        $registryPath = "$PSScriptRoot/../data/registry.json"
        $raw = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
        $checks = $raw.checks
    }

    It 'Has at least 139 entries (matching CIS benchmark count)' {
        $checks.Count | Should -BeGreaterOrEqual 139
    }

    It 'Has no duplicate CheckIds' {
        $ids = $checks | ForEach-Object { $_.checkId }
        $dupes = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
        $dupes | Should -BeNullOrEmpty -Because "CheckIds must be unique"
    }

    It 'Every entry has required fields' {
        foreach ($check in $checks) {
            $check.checkId | Should -Not -BeNullOrEmpty
            $check.name | Should -Not -BeNullOrEmpty
            $check.frameworks | Should -Not -BeNullOrEmpty
        }
    }

    It 'Tracks MANUAL-CIS migration progress' {
        $manualIds = $checks | Where-Object { $_.checkId -like 'MANUAL-*' }
        # Track count for regression visibility — do not fail
        Write-Host "  MANUAL-CIS entries remaining: $($manualIds.Count) of $($checks.Count) total"
        # Fail only if count increases (regression)
        $manualIds.Count | Should -BeLessOrEqual 94 `
            -Because "MANUAL-CIS count should decrease over time, not increase (was 94 at baseline)"
    }

    It 'All automated CheckIds follow the {SERVICE}-{AREA}-{NNN} naming convention' {
        $automated = $checks | Where-Object { $_.checkId -notlike 'MANUAL-*' }
        foreach ($check in $automated) {
            $check.checkId | Should -Match '^[A-Z]+-[A-Z0-9-]+-\d{3}$' `
                -Because "$($check.checkId) must follow {SERVICE}-{AREA}-{NNN} naming convention"
        }
    }

    It 'CIS-mapped entries have valid CIS framework data' {
        $cisMapped = $checks | Where-Object { $_.frameworks.PSObject.Properties.Name -contains 'cis-m365-v6' }
        $cisMapped.Count | Should -BeGreaterOrEqual 139 -Because "at least 139 CIS benchmark controls exist"
        foreach ($check in $cisMapped) {
            $check.frameworks.'cis-m365-v6'.controlId | Should -Not -BeNullOrEmpty `
                -Because "$($check.checkId) has CIS mapping and needs a controlId"
        }
    }

    It 'All automated checks have a collector field' {
        $automated = $checks | Where-Object { $_.hasAutomatedCheck -eq $true }
        foreach ($check in $automated) {
            $check.collector | Should -Not -BeNullOrEmpty `
                -Because "$($check.checkId) is automated and needs a collector"
        }
    }

    It 'hasAutomatedCheck is explicitly set for all checks' {
        foreach ($check in $checks) {
            $check.PSObject.Properties.Name | Should -Contain 'hasAutomatedCheck' `
                -Because "$($check.checkId) must have an explicit hasAutomatedCheck field"
        }
    }

    It 'supersededBy references valid CheckIds when present' {
        $superseded = $checks | Where-Object { $_.PSObject.Properties.Name -contains 'supersededBy' }
        $allIds = $checks | ForEach-Object { $_.checkId }
        foreach ($check in $superseded) {
            $check.supersededBy | Should -BeIn $allIds `
                -Because "$($check.checkId) supersededBy '$($check.supersededBy)' must reference an existing CheckId"
        }
    }

    It 'SOC 2 mappings exist for checks that have NIST 800-53 AC/AU/IA/SC/SI families' {
        $nistFamilies = @('AC-', 'AU-', 'IA-', 'SC-', 'SI-')
        $automated = $checks | Where-Object { $_.hasAutomatedCheck -eq $true }
        foreach ($check in $automated) {
            $hasNist = $check.frameworks.PSObject.Properties.Name -contains 'nist-800-53'
            $nist = if ($hasNist) { $check.frameworks.'nist-800-53' } else { $null }
            if ($nist -and $nist.controlId) {
                $matchesFamily = $nistFamilies | Where-Object {
                    $nist.controlId -like "$_*"
                }
                if ($matchesFamily) {
                    $check.frameworks.soc2 | Should -Not -BeNullOrEmpty `
                        -Because "$($check.checkId) maps to NIST $($nist.controlId) which should have SOC 2 mapping"
                }
            }
        }
    }
}
