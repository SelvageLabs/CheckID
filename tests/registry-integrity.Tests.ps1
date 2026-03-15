Describe 'Control Registry Integrity' {
    BeforeAll {
        $registryPath = "$PSScriptRoot/../data/registry.json"
        $raw = Get-Content -Path $registryPath -Raw | ConvertFrom-Json
        $checks = $raw.checks
    }

    # --- Schema-level tests ---

    It 'Has schemaVersion field with valid semver' {
        $raw.schemaVersion | Should -Match '^\d+\.\d+\.\d+$' `
            -Because "schemaVersion must follow semver format"
    }

    It 'Has dataVersion field with valid date format' {
        $raw.dataVersion | Should -Match '^\d{4}-\d{2}-\d{2}$' `
            -Because "dataVersion must be a YYYY-MM-DD date"
    }

    It 'Has generatedFrom field' {
        $raw.generatedFrom | Should -Not -BeNullOrEmpty
    }

    # --- Check count and uniqueness ---

    It 'Has at least 139 entries (matching CIS benchmark count)' {
        $checks.Count | Should -BeGreaterOrEqual 139
    }

    It 'Has no duplicate CheckIds' {
        $ids = $checks | ForEach-Object { $_.checkId }
        $dupes = $ids | Group-Object | Where-Object { $_.Count -gt 1 }
        $dupes | Should -BeNullOrEmpty -Because "CheckIds must be unique"
    }

    # --- Required fields ---

    It 'Every entry has required fields' {
        foreach ($check in $checks) {
            $check.checkId | Should -Not -BeNullOrEmpty
            $check.name | Should -Not -BeNullOrEmpty
            $check.frameworks | Should -Not -BeNullOrEmpty
        }
    }

    It 'Every entry has a licensing.minimum field' {
        foreach ($check in $checks) {
            $check.licensing.minimum | Should -BeIn @('E3', 'E5') `
                -Because "$($check.checkId) must have a valid licensing.minimum (E3 or E5)"
        }
    }

    It 'hasAutomatedCheck is explicitly set for all checks' {
        foreach ($check in $checks) {
            $check.PSObject.Properties.Name | Should -Contain 'hasAutomatedCheck' `
                -Because "$($check.checkId) must have an explicit hasAutomatedCheck field"
        }
    }

    # --- Naming conventions ---

    It 'Tracks MANUAL-CIS migration progress' {
        $manualIds = $checks | Where-Object { $_.checkId -like 'MANUAL-*' }
        Write-Host "  MANUAL-CIS entries remaining: $($manualIds.Count) of $($checks.Count) total"
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

    It 'All automated checks have a collector field' {
        $automated = $checks | Where-Object { $_.hasAutomatedCheck -eq $true }
        foreach ($check in $automated) {
            $check.collector | Should -Not -BeNullOrEmpty `
                -Because "$($check.checkId) is automated and needs a collector"
        }
    }

    It 'Collector values are from the known set' {
        $knownCollectors = @('Entra', 'CAEvaluator', 'ExchangeOnline', 'DNS', 'Defender', 'Compliance', 'Intune', 'SharePoint', 'Teams')
        $automated = $checks | Where-Object { $_.hasAutomatedCheck -eq $true }
        foreach ($check in $automated) {
            $check.collector | Should -BeIn $knownCollectors `
                -Because "$($check.checkId) collector '$($check.collector)' must be a known collector"
        }
    }

    # --- CIS framework ---

    It 'CIS-mapped entries have valid CIS framework data' {
        $cisMapped = $checks | Where-Object { $_.frameworks.PSObject.Properties.Name -contains 'cis-m365-v6' }
        $cisMapped.Count | Should -BeGreaterOrEqual 139 -Because "at least 139 CIS benchmark controls exist"
        foreach ($check in $cisMapped) {
            $check.frameworks.'cis-m365-v6'.controlId | Should -Not -BeNullOrEmpty `
                -Because "$($check.checkId) has CIS mapping and needs a controlId"
        }
    }

    It 'CIS profiles contain only valid values' {
        $validProfiles = @('E3-L1', 'E3-L2', 'E5-L1', 'E5-L2')
        $cisMapped = $checks | Where-Object { $_.frameworks.PSObject.Properties.Name -contains 'cis-m365-v6' }
        foreach ($check in $cisMapped) {
            $profiles = $check.frameworks.'cis-m365-v6'.profiles
            if ($profiles -and $profiles.Count -gt 0) {
                foreach ($p in $profiles) {
                    $p | Should -BeIn $validProfiles `
                        -Because "$($check.checkId) profile '$p' must be a valid CIS profile"
                }
            }
        }
    }

    # --- NIST 800-53 profiles ---

    It 'Most NIST 800-53 entries have profiles array' {
        $nistMapped = $checks | Where-Object { $_.frameworks.PSObject.Properties.Name -contains 'nist-800-53' }
        $nistMapped.Count | Should -BeGreaterOrEqual 1 -Because "at least some checks must map to NIST 800-53"
        $withProfiles = @($nistMapped | Where-Object { $_.frameworks.'nist-800-53'.profiles }).Count
        $withProfiles | Should -BeGreaterOrEqual ($nistMapped.Count * 0.9) `
            -Because "at least 90% of NIST 800-53 entries should have baseline profiles (some enhancements may not be in any baseline)"
    }

    # --- Framework coverage ---

    It 'All 14 frameworks are represented across checks' {
        $expectedFrameworks = @('cis-m365-v6', 'nist-800-53', 'nist-csf', 'iso-27001', 'stig', 'pci-dss', 'cmmc', 'hipaa', 'cisa-scuba', 'soc2', 'fedramp', 'cis-controls-v8', 'essential-eight', 'mitre-attack')
        $allFrameworks = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($check in $checks) {
            foreach ($prop in $check.frameworks.PSObject.Properties) {
                [void]$allFrameworks.Add($prop.Name)
            }
        }
        foreach ($fw in $expectedFrameworks) {
            $allFrameworks | Should -Contain $fw `
                -Because "framework '$fw' must be present in at least one check"
        }
    }

    It 'HIPAA control IDs use correct section symbol encoding' {
        $hipaaChecks = $checks | Where-Object { $_.frameworks.PSObject.Properties.Name -contains 'hipaa' }
        $hipaaChecks.Count | Should -BeGreaterOrEqual 1 -Because "at least some checks must map to HIPAA"
        foreach ($check in $hipaaChecks) {
            $controlId = $check.frameworks.hipaa.controlId
            $controlId | Should -Not -BeNullOrEmpty `
                -Because "$($check.checkId) has HIPAA mapping and needs a controlId"
            # Detect garbled encoding: Â§ instead of §
            $controlId | Should -Not -Match '\xC3\x82\xC2\xA7' `
                -Because "$($check.checkId) HIPAA controlId must not contain double-encoded section symbol"
            $controlId | Should -Not -Match 'Â§' `
                -Because "$($check.checkId) HIPAA controlId has garbled section symbol encoding"
        }
    }

    # --- Cross-references ---

    It 'supersededBy references valid CheckIds when present' {
        $superseded = $checks | Where-Object { $_.PSObject.Properties.Name -contains 'supersededBy' }
        $allIds = $checks | ForEach-Object { $_.checkId }
        foreach ($check in $superseded) {
            $check.supersededBy | Should -BeIn $allIds `
                -Because "$($check.checkId) supersededBy '$($check.supersededBy)' must reference an existing CheckId"
        }
    }

    It 'Every superseded check has a matching automated check' {
        $superseded = $checks | Where-Object { $_.PSObject.Properties.Name -contains 'supersededBy' }
        foreach ($check in $superseded) {
            $target = $checks | Where-Object { $_.checkId -eq $check.supersededBy }
            $target.hasAutomatedCheck | Should -Be $true `
                -Because "$($check.checkId) supersededBy '$($check.supersededBy)' — the target must be automated"
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

    # --- CSV-to-JSON fidelity ---

    It 'Registry check count matches CSV-derived expectation' {
        $fmPath = "$PSScriptRoot/../data/framework-mappings.csv"
        $cidPath = "$PSScriptRoot/../data/check-id-mapping.csv"
        $saPath = "$PSScriptRoot/../data/standalone-checks.json"

        $fm = Import-Csv -Path $fmPath
        $cid = Import-Csv -Path $cidPath
        $sa = if (Test-Path $saPath) { (Get-Content $saPath -Raw | ConvertFrom-Json) } else { @() }

        # Each framework-mapping row produces 1 check, plus 1 more if it has supersededBy
        $supersededCount = @($cid | Where-Object { -not [string]::IsNullOrWhiteSpace($_.SupersededBy) }).Count
        $expectedCount = $fm.Count + $supersededCount + $sa.Count

        $checks.Count | Should -Be $expectedCount `
            -Because "registry should have $($fm.Count) CIS + $supersededCount superseded + $($sa.Count) standalone = $expectedCount checks"
    }
}
