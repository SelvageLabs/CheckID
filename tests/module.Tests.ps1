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
        $expected = @('Get-CheckById', 'Get-CheckRegistry', 'Search-Check', 'Test-CheckRegistryData') | Sort-Object
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
