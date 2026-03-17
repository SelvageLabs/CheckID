# CheckID

Stable, unique identifiers for security configuration checks — mapped across compliance frameworks.

## What Is CheckID?

CheckID gives every security check a permanent ID and maps it to controls across multiple compliance frameworks simultaneously. Instead of tracking "CIS 1.1.3" in one report and "AC-6(5)" in another, you reference `ENTRA-ADMIN-001` and get both — plus ISO 27001, HIPAA, SOC 2, and more.

**Format:** `{SERVICE}-{AREA}-{NNN}` (e.g., `ENTRA-ADMIN-001`, `DEFENDER-SAFELINKS-001`)

**Current coverage:**
- 233 checks across Microsoft 365 (Entra ID, Exchange Online, Defender, SharePoint, Teams, Intune, Compliance)
- 14 compliance frameworks mapped per check
- Automated + manual checks with supersession tracking

CheckID starts with M365 but is designed to expand. The identifier format, registry schema, and framework mapping approach are platform-agnostic — new services and platforms can be added without breaking existing consumers.

## Quick Start

### Install from PSGallery (recommended)

```powershell
Install-Module -Name CheckID -Scope CurrentUser
```

```powershell
# Load all checks
$checks = Get-CheckRegistry

# Look up a specific check
$check = Get-CheckById 'ENTRA-ADMIN-001'
$check.name          # "Ensure that between two and four global admins are designated"
$check.frameworks    # All framework mappings with titles

# Search by framework, control ID, or keyword
Search-Check -Framework 'hipaa' -Keyword 'password'
Search-Check -ControlId 'AC-6'

# Framework coverage analytics (excludes superseded entries)
Get-FrameworkCoverage | Format-Table
Get-FrameworkCoverage -Framework 'hipaa'
```

### Add as a git submodule (legacy)

> The submodule approach still works and will continue to be supported during the transition period. New projects should prefer `Install-Module`.

```bash
git submodule add https://github.com/SelvageLabs/CheckID.git lib/CheckID
```

```powershell
# Dot-source the loader
. ./lib/CheckID/scripts/Import-ControlRegistry.ps1

# Load the registry (returns a hashtable keyed by CheckID)
$registry = Import-ControlRegistry -ControlsPath ./lib/CheckID/data

# Look up a specific check
$check = $registry['ENTRA-ADMIN-001']
$check.name          # "Ensure that between two and four global admins are designated"
$check.frameworks    # Hashtable of all framework mappings
```

### Use the registry data directly

`data/registry.json` is a standalone JSON file — consume it from any language:

```python
import json
with open('lib/CheckID/data/registry.json') as f:
    registry = json.load(f)

for check in registry['checks']:
    if 'hipaa' in check['frameworks']:
        print(f"{check['checkId']}: {check['frameworks']['hipaa']['controlId']}")
```

### Use the Python client library

A higher-level Python client is available in `clients/python/`:

```bash
pip install -e lib/CheckID/clients/python
```

```python
from checkid import CheckIDRegistry

reg = CheckIDRegistry()

# Look up a specific check
check = reg.get_by_id("ENTRA-ADMIN-001")
print(check["name"])

# Search by framework, control ID, or keyword
results = reg.search(framework="hipaa", keyword="password")
results = reg.search(control_id="AC-6")

# Coverage analytics per framework
for cov in reg.framework_coverage():
    print(f"{cov['framework_key']:20s}  {cov['check_count']} checks")
```

### Generate a compliance matrix (XLSX)

```powershell
./lib/CheckID/scripts/Export-ComplianceMatrix.ps1 -AssessmentFolder ./output
```

## Supported Frameworks

| Framework | Key | Coverage | Profiles |
|-----------|-----|----------|----------|
| CIS Microsoft 365 v6.0.1 | `cis-m365-v6` | 221 checks | E3-L1, E3-L2, E5-L1, E5-L2 |
| NIST SP 800-53 Rev 5 | `nist-800-53` | 233 checks | Low, Moderate, High, Privacy |
| NIST Cybersecurity Framework 2.0 | `nist-csf` | 229 checks | |
| ISO/IEC 27001:2022 | `iso-27001` | 233 checks | |
| DISA STIG | `stig` | 22 checks | |
| PCI DSS v4.0.1 | `pci-dss` | 223 checks | |
| CMMC 2.0 | `cmmc` | 223 checks | |
| HIPAA Security Rule | `hipaa` | 226 checks | |
| CISA SCuBA | `cisa-scuba` | 71 checks | |
| SOC 2 Trust Services Criteria | `soc2` | 232 checks | |
| FedRAMP Rev 5 | `fedramp` | 223 checks | |
| CIS Controls v8.1 | `cis-controls-v8` | 190 checks | |
| Essential Eight | `essential-eight` | 77 checks | |
| MITRE ATT&CK v10 | `mitre-attack` | 217 checks | |

### NIST 800-53 Baseline Profiles

NIST 800-53 Rev 5 defines 1,189 controls covering everything from physical security to cloud configuration. CheckID maps the subset that is verifiable through M365 configuration export -- 59 unique controls across 7 families (AC, AT, AU, CM, IA, SC, SI).

Each registry entry's `nist-800-53` mapping includes a `profiles` array indicating which NIST baselines the mapped controls belong to:

| Baseline | Total Controls | M365-Assessable | Notes |
|----------|---------------|-----------------|-------|
| Low | 149 | 25 | Subset of Moderate |
| Moderate | 287 | 41 | Subset of High |
| High | 370 | 43 | Superset of all |
| Privacy | 96 | 2 | Independent set |

The remaining NIST controls cover areas outside M365's scope: physical security (PE), contingency planning (CP), personnel security (PS), media protection (MP), and other organizational/procedural domains. This is by design -- CheckID assesses configuration state, not procedural compliance.

Consumers can use baseline profiles to report accurately: *"Of the 149 Low baseline controls, 25 are M365-assessable and we check all 25"* rather than the misleading *"25 of 1,189 total controls."*

## Repository Structure

```
CheckID/
├── clients/                       Language-specific client libraries
│   └── python/                    Python client (pip-installable)
│       ├── checkid/               Package source
│       ├── tests/                 pytest tests
│       └── pyproject.toml
├── data/                          Registry data
│   ├── registry.json              Master registry (233 checks, 14 frameworks)
│   ├── check-id-mapping.csv       CheckID → service/area assignments
│   ├── framework-mappings.csv     CIS → multi-framework cross-references
│   ├── standalone-checks.json     Non-CIS automated checks with framework data
│   └── frameworks/                Framework definitions
│       ├── cis-m365-v6.json       CIS M365 v6.0.1 profiles and sections
│       ├── gdpr.json              GDPR security-relevant articles (Art. 5, 25, 32–35)
│       ├── nist-800-53-r5.json    NIST 800-53 Rev 5 baseline profiles
│       └── soc2-tsc.json          SOC 2 Trust Services Criteria
├── scripts/                       PowerShell 7.x scripts
│   ├── Build-Registry.ps1         Generates registry.json from CSVs
│   ├── Import-NistBaselines.ps1   Reads OSCAL baseline profiles from SecFrame
│   ├── Import-ControlRegistry.ps1 Loads registry into memory
│   ├── Export-ComplianceMatrix.ps1 XLSX multi-framework compliance report
│   ├── Search-Registry.ps1        Search registry by CheckId, framework, or keyword
│   ├── Test-RegistryData.ps1      Data quality validation
│   └── Show-CheckProgress.ps1     Real-time progress display
├── tests/                         Pester 5.x tests
│   ├── registry-integrity.Tests.ps1
│   ├── nist-baselines.Tests.ps1
│   ├── module.Tests.ps1
│   └── search-registry.Tests.ps1
└── docs/
    └── CheckId-Guide.md           Detailed system documentation
```

## Registry Schema

Each check in `registry.json` contains:

```json
{
  "checkId": "ENTRA-ADMIN-001",
  "name": "Ensure Administrative accounts are cloud-only",
  "category": "ADMIN",
  "collector": "Entra",
  "hasAutomatedCheck": true,
  "licensing": { "minimum": "E3" },
  "frameworks": {
    "cis-m365-v6": { "controlId": "1.1.1", "title": "...", "profiles": ["E3-L1", "E5-L1"] },
    "nist-800-53": { "controlId": "AC-6(5);AC-2", "title": "...", "profiles": ["Low", "Moderate", "High"] },
    "iso-27001": { "controlId": "A.5.15;A.5.18;A.8.2" },
    "hipaa": { "controlId": "§164.312(a)(1);§164.308(a)(4)(i)" },
    "soc2": { "controlId": "CC6.1;CC6.2;CC6.3", "evidenceType": "config-export" }
  }
}
```

Top-level fields: `schemaVersion` (semver), `dataVersion` (date), `generatedFrom`, `checks[]`.

## Rebuilding the Registry

After editing the CSV files, regenerate `registry.json`:

```powershell
./scripts/Build-Registry.ps1
```

Then validate:

```powershell
./scripts/Test-RegistryData.ps1          # data quality checks
Invoke-Pester ./tests/ -Output Detailed  # 57 integrity tests
```

## Contributing

Contributions are welcome — especially new framework mappings, additional service coverage, and tooling improvements.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/add-fedramp`)
3. Edit the CSVs in `data/` and run `./scripts/Build-Registry.ps1`
4. Run tests: `Invoke-Pester ./tests/` and `./scripts/Test-RegistryData.ps1`
5. Open a PR

**Areas we'd love help with:**
- Framework mappings for platforms beyond M365 (AWS, GCP, Azure IaaS)
- Adding GDPR control mappings to existing registry entries (see `data/frameworks/gdpr.json` for the article structure)
- Language-specific client libraries (Go, TypeScript)
- Documentation and guides

## License

[MIT](LICENSE)
