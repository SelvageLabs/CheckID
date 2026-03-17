BeforeAll {
    $modulePath = "$PSScriptRoot/../CheckID.psd1"
    Import-Module $modulePath -Force
}

AfterAll {
    Remove-Module CheckID -ErrorAction SilentlyContinue
}

Describe 'CheckID Module' {

    It 'Loads successfully with correct version' {
        $mod = Get-Module CheckID
        $mod | Should -Not -BeNullOrEmpty
        $mod.Version | Should -Be '1.0.0'
    }

    It 'Exports exactly the expected functions' {
        $mod = Get-Module CheckID
        $exported = $mod.ExportedFunctions.Keys | Sort-Object
        $expected = @('Get-CheckById', 'Get-CheckRegistry', 'Get-FrameworkCoverage', 'Search-Check', 'Test-CheckRegistryData') | Sort-Object
        $exported | Should -Be $expected
    }

    It 'Does not export internal helpers' {
        $mod = Get-Module CheckID
        $mod.ExportedFunctions.Keys | Should -Not -Contain 'Resolve-FrameworkTitle'
        $mod.ExportedFunctions.Keys | Should -Not -Contain 'Get-Soc2CriteriaFromNist'
    }
}
Describe 'Get-CheckRegistry' {

    It 'Returns all checks from the registry' {
        $checks = Get-CheckRegistry
        $checks.Count | Should -BeGreaterOrEqual 233
    }

    It 'Returns cached results on second call' {
        $first = Get-CheckRegistry
        $second = Get-CheckRegistry
        $first.Count | Should -Be $second.Count
    }

    It 'Reloads from disk with -Force' {
        $checks = Get-CheckRegistry -Force
        $checks.Count | Should -BeGreaterOrEqual 233
    }
}

Describe 'Get-CheckById' {

    It 'Returns a check by exact CheckId' {
        $check = Get-CheckById 'ENTRA-ADMIN-001'
        $check | Should -Not -BeNullOrEmpty
        $check.checkId | Should -Be 'ENTRA-ADMIN-001'
    }

    It 'Returns null for non-existent CheckId' {
        $check = Get-CheckById 'DOES-NOT-EXIST-999'
        $check | Should -BeNullOrEmpty
    }
}

Describe 'Search-Check' {

    It 'Filters by framework' {
        $results = Search-Check -Framework 'stig'
        $results.Count | Should -BeGreaterThan 0
        foreach ($r in $results) {
            $r.frameworks.PSObject.Properties.Name | Should -Contain 'stig'
        }
    }

    It 'Searches by control ID' {
        $results = Search-Check -ControlId 'AC-6'
        $results.Count | Should -BeGreaterThan 0
    }

    It 'Searches by keyword' {
        $results = Search-Check -Keyword 'MFA'
        $results.Count | Should -BeGreaterThan 0
        foreach ($r in $results) {
            $r.name | Should -BeLike '*MFA*'
        }
    }

    It 'Combines framework and keyword filters' {
        $results = Search-Check -Framework 'hipaa' -Keyword 'password'
        $results.Count | Should -BeGreaterThan 0
    }
}

Describe 'Get-FrameworkCoverage' {

    It 'Returns at least 14 framework entries' {
        $coverage = Get-FrameworkCoverage
        $coverage.Count | Should -BeGreaterOrEqual 14
    }

    It 'Every entry has FrameworkKey, CheckCount, AutomatedCount, ManualCount' {
        $coverage = Get-FrameworkCoverage
        foreach ($entry in $coverage) {
            $entry.FrameworkKey | Should -Not -BeNullOrEmpty
            $entry.PSObject.Properties.Name | Should -Contain 'CheckCount'
            $entry.PSObject.Properties.Name | Should -Contain 'AutomatedCount'
            $entry.PSObject.Properties.Name | Should -Contain 'ManualCount'
        }
    }

    It 'AutomatedCount + ManualCount equals CheckCount for every framework' {
        $coverage = Get-FrameworkCoverage
        foreach ($entry in $coverage) {
            ($entry.AutomatedCount + $entry.ManualCount) | Should -Be $entry.CheckCount `
                -Because "$($entry.FrameworkKey): AutomatedCount + ManualCount must equal CheckCount"
        }
    }

    It 'NIST 800-53 coverage is at least 139 active checks' {
        $nist = Get-FrameworkCoverage -Framework 'nist-800-53'
        $nist | Should -HaveCount 1
        $nist[0].CheckCount | Should -BeGreaterOrEqual 139
    }

    It 'Single-framework filter returns exactly one result' {
        $result = Get-FrameworkCoverage -Framework 'stig'
        $result | Should -HaveCount 1
        $result[0].FrameworkKey | Should -Be 'stig'
    }

    It 'CheckCount is greater than zero for all known frameworks' {
        $knownFrameworks = @('cis-m365-v6', 'nist-800-53', 'nist-csf', 'iso-27001',
                             'stig', 'pci-dss', 'cmmc', 'hipaa', 'cisa-scuba', 'soc2',
                             'fedramp', 'cis-controls-v8', 'essential-eight', 'mitre-attack')
        $coverage = Get-FrameworkCoverage
        $byKey = @{}
        foreach ($entry in $coverage) { $byKey[$entry.FrameworkKey] = $entry }
        foreach ($fw in $knownFrameworks) {
            $byKey[$fw] | Should -Not -BeNullOrEmpty -Because "framework '$fw' must have coverage data"
            $byKey[$fw].CheckCount | Should -BeGreaterThan 0 -Because "framework '$fw' must have at least one mapped check"
        }
    }

    It 'Superseded checks are excluded from coverage counts' {
        # Load registry directly to find a framework only used by superseded entries
        $allChecks = Get-CheckRegistry
        $active    = @($allChecks | Where-Object { -not ($_.PSObject.Properties.Name -contains 'supersededBy') })
        $superseded = @($allChecks | Where-Object { $_.PSObject.Properties.Name -contains 'supersededBy' })

        # Coverage should reflect active count, not total
        $coverage = Get-FrameworkCoverage -Framework 'cis-m365-v6'
        $coverage[0].CheckCount | Should -BeLessOrEqual $active.Count `
            -Because 'superseded entries must not inflate framework coverage counts'
    }
}

Describe 'Backwards Compatibility' {

    It 'Import-ControlRegistry.ps1 still works via dot-source' {
        . "$PSScriptRoot/../scripts/Import-ControlRegistry.ps1"
        $registry = Import-ControlRegistry -ControlsPath "$PSScriptRoot/../data"
        $registry | Should -Not -BeNullOrEmpty
        $registry['ENTRA-ADMIN-001'] | Should -Not -BeNullOrEmpty
        $registry['__cisReverseLookup'] | Should -Not -BeNullOrEmpty
    }

    It 'Search-Registry.ps1 still works as standalone script' {
        $results = & "$PSScriptRoot/../scripts/Search-Registry.ps1" -CheckId 'ENTRA-ADMIN-001' -AsObject
        $results | Should -HaveCount 1
        $results[0].checkId | Should -Be 'ENTRA-ADMIN-001'
    }
}
