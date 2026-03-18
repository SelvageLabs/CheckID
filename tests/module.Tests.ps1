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
        $expected = (Import-PowerShellDataFile "$PSScriptRoot/../CheckID.psd1").ModuleVersion
        $mod.Version | Should -Be $expected
    }

    It 'Exports exactly the expected functions' {
        $mod = Get-Module CheckID
        $exported = $mod.ExportedFunctions.Keys | Sort-Object
        $expected = @('Export-ComplianceMatrix', 'Get-CheckAutomationGaps', 'Get-CheckById', 'Get-CheckRegistry', 'Get-FrameworkCoverage', 'Search-Check', 'Test-CheckRegistryData') | Sort-Object
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

    It 'Returns coverage for all frameworks' {
        $results = Get-FrameworkCoverage
        $results.Count | Should -BeGreaterOrEqual 14
        foreach ($r in $results) {
            $r.Framework | Should -Not -BeNullOrEmpty
            $r.MappedChecks | Should -BeGreaterOrEqual 1
            $r.Automated | Should -BeOfType [int]
            $r.Manual | Should -BeOfType [int]
        }
    }

    It 'Filters by single framework' {
        $result = Get-FrameworkCoverage -Framework 'nist-800-53'
        $result | Should -HaveCount 1
        $result.Framework | Should -Be 'nist-800-53'
        $result.MappedChecks | Should -BeGreaterOrEqual 100
    }
    }

    It 'Includes CoveragePct when framework definition exists' {
        $result = Get-FrameworkCoverage -Framework 'cis-m365-v6'
        $result.TotalControls | Should -Not -BeNullOrEmpty
        $result.CoveragePct | Should -Not -BeNullOrEmpty
    }
}

Describe 'Get-CheckAutomationGaps' {

    It 'Returns manual checks from the registry' {
        $gaps = Get-CheckAutomationGaps
        $gaps.Count | Should -BeGreaterThan 0
        foreach ($g in $gaps) {
            $g.hasAutomatedCheck | Should -Be $false
        }
    }

    It 'Filters by framework' {
        $gaps = Get-CheckAutomationGaps -Framework 'hipaa'
        $gaps.Count | Should -BeGreaterThan 0
        foreach ($g in $gaps) {
            $g.frameworks.PSObject.Properties.Name | Should -Contain 'hipaa'
        }
    }

    It 'Excludes superseded entries' {
        $gaps = Get-CheckAutomationGaps
        foreach ($g in $gaps) {
            if ($g.PSObject.Properties.Name -contains 'supersededBy') {
                $g.supersededBy | Should -BeNullOrEmpty
            }
        }
    }
}

