BeforeAll {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $searchScript = Join-Path $repoRoot 'scripts' 'Search-Registry.ps1'
    $registryPath = Join-Path $repoRoot 'data' 'registry.json'
}

Describe 'Search-Registry.ps1' {

    It 'Returns a single check for exact CheckId lookup' {
        $results = & $searchScript -CheckId 'ENTRA-ADMIN-001' -AsObject
        $results | Should -HaveCount 1
        $results[0].checkId | Should -Be 'ENTRA-ADMIN-001'
    }

    It 'Returns no results for a non-existent CheckId' {
        $results = & $searchScript -CheckId 'DOES-NOT-EXIST-999' -AsObject
        $results | Should -BeNullOrEmpty
    }

    It 'Filters by framework key' {
        $results = & $searchScript -Framework 'stig' -AsObject
        $results.Count | Should -BeGreaterThan 0
        foreach ($r in $results) {
            $r.frameworks.PSObject.Properties.Name | Should -Contain 'stig'
        }
    }

    It 'Searches by control ID substring' {
        $results = & $searchScript -ControlId 'AC-6' -AsObject
        $results.Count | Should -BeGreaterThan 0
        $hasMatch = $false
        foreach ($r in $results) {
            foreach ($fw in $r.frameworks.PSObject.Properties) {
                if ($fw.Value.controlId -like '*AC-6*') { $hasMatch = $true }
            }
        }
        $hasMatch | Should -BeTrue
    }

    It 'Searches by keyword in check name' {
        $results = & $searchScript -Keyword 'MFA' -AsObject
        $results.Count | Should -BeGreaterThan 0
        foreach ($r in $results) {
            $r.name | Should -BeLike '*MFA*'
        }
    }

    It 'Combines Framework and ControlId filters' {
        $results = & $searchScript -Framework 'nist-800-53' -ControlId 'AC-6' -AsObject
        $results.Count | Should -BeGreaterThan 0
        foreach ($r in $results) {
            $r.frameworks.PSObject.Properties.Name | Should -Contain 'nist-800-53'
            $r.frameworks.'nist-800-53'.controlId | Should -BeLike '*AC-6*'
        }
    }

    It 'Combines Framework and Keyword filters' {
        $results = & $searchScript -Framework 'hipaa' -Keyword 'password' -AsObject
        $results.Count | Should -BeGreaterThan 0
        foreach ($r in $results) {
            $r.frameworks.PSObject.Properties.Name | Should -Contain 'hipaa'
            $r.name | Should -BeLike '*password*'
        }
    }

    It 'AsObject returns PSCustomObject array suitable for pipeline' {
        $results = & $searchScript -Framework 'soc2' -AsObject
        $results | Should -Not -BeNullOrEmpty
        $results[0].checkId | Should -Not -BeNullOrEmpty
        $results[0].frameworks | Should -Not -BeNullOrEmpty
    }
}
