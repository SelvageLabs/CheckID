@{
    # Module metadata
    RootModule        = 'CheckID.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = 'a3b7c4d5-1e2f-4a5b-8c9d-0e1f2a3b4c5d'
    Author            = 'SelvageLabs'
    CompanyName       = 'SelvageLabs'
    Copyright         = '(c) SelvageLabs. All rights reserved. MIT License.'
    Description       = 'Stable, unique identifiers for security configuration checks mapped across 14 compliance frameworks.'

    # Requirements
    PowerShellVersion = '7.0'

    # Exported members
    FunctionsToExport = @(
        'Get-CheckRegistry'
        'Get-CheckById'
        'Search-Check'
        'Get-FrameworkCoverage'
        'Test-CheckRegistryData'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()

    # Module data
    FileList = @(
        'CheckID.psd1'
        'CheckID.psm1'
        'data/registry.json'
        'data/registry.schema.json'
        'data/framework-titles.json'
        'data/derived-mappings.json'
        'data/framework-mappings.csv'
        'data/check-id-mapping.csv'
        'data/standalone-checks.json'
        'data/frameworks/cis-m365-v6.json'
        'data/frameworks/nist-800-53-r5.json'
        'data/frameworks/nist-csf-2.json'
        'data/frameworks/iso-27001-2022.json'
        'data/frameworks/disa-stig-m365.json'
        'data/frameworks/pci-dss-v4.json'
        'data/frameworks/cmmc-2.json'
        'data/frameworks/hipaa-security-rule.json'
        'data/frameworks/cisa-scuba-baselines.json'
        'data/frameworks/soc2-tsc.json'
        'data/frameworks/essential-eight.json'
        'data/frameworks/cis-controls-v8.json'
        'data/frameworks/fedramp.json'
        'data/frameworks/mitre-attack.json'
        'scripts/Build-Registry.ps1'
        'scripts/Build-DerivedMappings.py'
        'scripts/Build-FrameworkTitles.py'
        'scripts/Export-ComplianceMatrix.ps1'
        'scripts/Import-ControlRegistry.ps1'
        'scripts/Import-NistBaselines.ps1'
        'scripts/Search-Registry.ps1'
        'scripts/Show-CheckProgress.ps1'
        'scripts/Test-RegistryData.ps1'
    )

    PrivateData = @{
        PSData = @{
            Tags         = @('Security', 'Compliance', 'CheckID', 'NIST', 'CIS', 'ISO27001', 'HIPAA', 'SOC2', 'FedRAMP', 'M365')
            LicenseUri   = 'https://github.com/SelvageLabs/CheckID/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/SelvageLabs/CheckID'
            ReleaseNotes = 'v1.1.0: Add Get-FrameworkCoverage cmdlet, hash-indexed Get-CheckById for O(1) lookups.'
        }
    }
}
