# CheckID

Universal identifier system for M365 security checks with multi-framework compliance mapping.

## What Is CheckID?

CheckID provides a stable, unique identifier for every security check in an M365 assessment.
Each CheckID maps to controls across 13 compliance frameworks simultaneously, enabling
framework-agnostic compliance reporting.

**Format:** `{COLLECTOR}-{AREA}-{NNN}` (e.g., `ENTRA-ADMIN-001`, `DEFENDER-SAFELINKS-001`)

**Coverage:**
- 233 total checks (138 automated, 81 superseded, 14 manual/tracked)
- 9 collectors: Entra, CAEvaluator, ExchangeOnline, DNS, Defender, Compliance, Intune, SharePoint, Teams
- 13 frameworks: CIS M365 v6, NIST 800-53, NIST CSF, ISO 27001, STIG, PCI DSS, CMMC, HIPAA, CISA SCuBA, SOC 2, and more

## Quick Start

### Add as a git submodule

```bash
git submodule add https://github.com/SelvageLabs/CheckID.git lib/CheckID
```

### Load the registry in PowerShell

```powershell
# Dot-source the loader
. ./lib/CheckID/scripts/Import-ControlRegistry.ps1

# Load the registry (returns a hashtable keyed by CheckID)
$registry = Import-ControlRegistry -ControlsPath ./lib/CheckID/data

# Look up a specific check
$check = $registry['ENTRA-ADMIN-001']
$check.name          # "Ensure that between two and four global admins are designated"
$check.frameworks    # Hashtable of all 13 framework mappings
```

### Generate a compliance matrix (XLSX)

```powershell
./lib/CheckID/scripts/Export-ComplianceMatrix.ps1 -AssessmentFolder ./output
```

## Repository Structure

```
CheckID/
├── data/                          Registry data
│   ├── registry.json              Master registry (233 checks, 13 frameworks)
│   ├── check-id-mapping.csv       CheckID to collector/area assignments
│   ├── framework-mappings.csv     CIS to multi-framework cross-references
│   └── frameworks/                Framework definitions
│       ├── cis-m365-v6.json       CIS M365 v6.0.1 profiles and sections
│       └── soc2-tsc.json          SOC 2 Trust Services Criteria
├── scripts/                       PowerShell scripts
│   ├── Build-Registry.ps1         Generates registry.json from CSVs
│   ├── Import-ControlRegistry.ps1 Loads registry into memory
│   ├── Show-CheckProgress.ps1     Real-time progress display
│   └── Export-ComplianceMatrix.ps1 XLSX multi-framework report
├── tests/                         Pester 5.x tests
│   └── registry-integrity.Tests.ps1
└── docs/
    └── CheckId-Guide.md           Detailed system documentation
```

## Supported Frameworks

| Framework | Key |
|-----------|-----|
| CIS Microsoft 365 v6.0.1 | `cis-m365-v6` |
| NIST SP 800-53 Rev 5 | `nist-800-53` |
| NIST Cybersecurity Framework 2.0 | `nist-csf` |
| ISO/IEC 27001:2022 | `iso-27001` |
| DISA STIG | `stig` |
| PCI DSS v4.0.1 | `pci-dss` |
| CMMC 2.0 | `cmmc` |
| HIPAA Security Rule | `hipaa` |
| CISA SCuBA | `cisa-scuba` |
| SOC 2 Trust Services Criteria | `soc2` |

## Rebuilding the Registry

After editing the CSV files, regenerate `registry.json`:

```powershell
./scripts/Build-Registry.ps1 -Verbose
```

Then run the integrity tests:

```powershell
Invoke-Pester ./tests/ -Output Detailed
```

## License

MIT
