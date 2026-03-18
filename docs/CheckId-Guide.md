# CheckId System Guide

The CheckId system is the backbone of M365-Assess's multi-framework compliance reporting. Each security check gets a framework-agnostic identifier that maps to controls across 14 compliance frameworks simultaneously.

## What Is a CheckId?

A CheckId is a stable, human-readable identifier assigned to every security check in the assessment. Instead of referencing checks by CIS control numbers (which are framework-specific), CheckIds provide a universal key that works across all frameworks.

**Format**: `{COLLECTOR}-{AREA}-{NNN}`

| Part | Description | Examples |
|------|-------------|---------|
| Collector | Which M365 service | `ENTRA`, `EXO`, `DEFENDER`, `SPO`, `TEAMS`, `CA`, `DNS`, `INTUNE`, `COMPLIANCE` |
| Area | Security domain | `ADMIN`, `MFA`, `PASSWORD`, `SHARING`, `MEETING`, `HYBRID`, `SCRIPT`, `B2B` |
| NNN | Sequential number | `001`, `002`, `003` |

**Examples:**
- `ENTRA-ADMIN-001` -- Global administrator count check
- `ENTRA-HYBRID-001` -- Password hash sync for hybrid deployments
- `CA-BLOCK-001` -- Conditional Access policy evaluation
- `EXO-FORWARD-001` -- Auto-forwarding to external domains
- `DNS-SPF-001` -- SPF record validation
- `DEFENDER-ANTIPHISH-001` -- Anti-phishing policy settings
- `SPO-SHARING-004` -- Default sharing link type
- `SPO-SCRIPT-001` -- Custom script execution restriction
- `TEAMS-MEETING-003` -- Lobby bypass configuration
- `INTUNE-ENROLL-001` -- Device enrollment restrictions

### Sub-Numbering

When a single CheckId evaluates multiple settings (e.g., an anti-phishing policy has several configurable thresholds), collectors auto-append a sub-number:

- `DEFENDER-ANTIPHISH-001.1` -- Phishing email threshold
- `DEFENDER-ANTIPHISH-001.2` -- Spoof action
- `DEFENDER-ANTIPHISH-001.3` -- Mailbox intelligence action

This is handled automatically by the `Add-Setting` function's `$checkIdCounter` hash in each collector. The registry entry uses the base CheckId (`DEFENDER-ANTIPHISH-001`); the sub-numbers appear only in CSV output and the report.

## How Many CheckIds Exist?

| Type | Count | Description |
|------|-------|-------------|
| Automated | 168 | Checked by collectors, appear in CSV output and reports |
| Manual | 1 | CIS benchmark controls not yet automated, tracked for coverage |
| **Total** | **169** | Full registry across all frameworks |

## The Control Registry

All CheckIds live in `data/registry.json`. Each entry contains:

```json
{
  "checkId": "ENTRA-ADMIN-001",
  "name": "Ensure that between two and four global admins are designated",
  "category": "ADMIN",
  "collector": "Entra",
  "hasAutomatedCheck": true,
  "licensing": { "minimum": "E3" },
  "frameworks": {
    "cis-m365-v6": {
      "controlId": "1.1.3",
      "title": "Ensure that between two and four global admins are designated",
      "profiles": ["E3-L1", "E5-L1"]
    },
    "nist-800-53": {
      "controlId": "AC-2;AC-6",
      "title": "Account Management; Least Privilege",
      "profiles": ["Low", "Moderate", "High"]
    },
    "nist-csf": { "controlId": "PR.AA-05" },
    "iso-27001": { "controlId": "A.5.15;A.5.18;A.8.2" },
    "stig": { "controlId": "V-260335" },
    "pci-dss": { "controlId": "8.2.x" },
    "cmmc": { "controlId": "3.1.5;3.1.6" },
    "hipaa": { "controlId": "§164.312(a)(1);§164.308(a)(4)(i)" },
    "cisa-scuba": { "controlId": "MS.AAD.7.1v1" },
    "soc2": { "controlId": "CC6.1;CC6.2;CC6.3", "evidenceType": "config-export" }
  }
}
```

**Key fields:**
- `hasAutomatedCheck` -- Whether a collector evaluates this check automatically
- `collector` -- Which collector script produces the result (see Collectors table below)
- `licensing.minimum` -- E3 or E5 license required
- `frameworks` -- Maps to every applicable compliance framework

### Collectors

| Registry Name | Script | Section |
|--------------|--------|---------|
| `Entra` | `Entra/Get-EntraSecurityConfig.ps1` | Identity |
| `CAEvaluator` | `Entra/Get-CASecurityConfig.ps1` | Identity |
| `ExchangeOnline` | `Exchange-Online/Get-ExoSecurityConfig.ps1` | Email |
| `DNS` | `Exchange-Online/Get-DnsSecurityConfig.ps1` | Email |
| `Defender` | `Security/Get-DefenderSecurityConfig.ps1` | Security |
| `Compliance` | `Security/Get-ComplianceSecurityConfig.ps1` | Security |
| `Intune` | `Intune/Get-IntuneSecurityConfig.ps1` | Intune |
| `SharePoint` | `Collaboration/Get-SharePointSecurityConfig.ps1` | Collaboration |
| `Teams` | `Collaboration/Get-TeamsSecurityConfig.ps1` | Collaboration |

## Supported Frameworks

| Framework | Registry Key | Notes |
|-----------|-------------|-------|
| CIS M365 v6.0.1 | `cis-m365-v6` | 4 profiles: E3-L1, E3-L2, E5-L1, E5-L2 |
| NIST 800-53 Rev 5 | `nist-800-53` | 4 baseline profiles: Low, Moderate, High, Privacy |
| NIST CSF 2.0 | `nist-csf` | Functions and categories (PR.AC, DE.CM, etc.) |
| ISO 27001:2022 | `iso-27001` | Annex A controls |
| DISA STIG | `stig` | Vulnerability IDs (V-xxxxxx) |
| PCI DSS v4.0.1 | `pci-dss` | Requirements |
| CMMC 2.0 | `cmmc` | Practices (3.x.x) |
| HIPAA Security Rule | `hipaa` | Sec. 164.3xx references |
| CISA SCuBA | `cisa-scuba` | MS.AAD/EXO/DEFENDER/SPO/TEAMS baselines |
| SOC 2 TSC | `soc2` | Trust Services Criteria (CC/A/C/PI/P) |
| FedRAMP Rev 5 | `fedramp` | Derived from NIST 800-53 via SCF bridge |
| CIS Controls v8.1 | `cis-controls-v8` | Derived from NIST 800-53 via SCF bridge |
| Essential Eight (ASD) | `essential-eight` | ML1–ML3 maturity levels, P1–P7 strategies; derived via SCF bridge |
| MITRE ATT&CK v10 | `mitre-attack` | Derived from NIST 800-53 via SCF bridge |

SOC 2 mappings are auto-derived from NIST 800-53 control families using rules in `scripts/Build-Registry.ps1`. FedRAMP, CIS Controls v8, Essential Eight, and MITRE ATT&CK are derived via the SecFrame SCF transitive bridge.

### NIST 800-53 Coverage Scope

NIST 800-53 Rev 5 catalogs 1,189 controls spanning physical security, personnel processes, contingency planning, and technical configuration. CheckID maps the **59 controls that are verifiable through M365 configuration export**, concentrated in 7 control families:

| Family | Controls Mapped | Examples |
|--------|----------------|---------|
| AC (Access Control) | 25 | Account management, least privilege, remote access |
| IA (Identification/Auth) | 12 | MFA, authenticator management, credential policies |
| CM (Configuration Mgmt) | 8 | Baseline config, least functionality |
| SC (System/Comms Protection) | 5 | Boundary protection, DLP, encryption |
| SI (System/Info Integrity) | 5 | Malware protection, security alerts |
| AU (Audit/Accountability) | 2 | Audit record generation |
| AT (Awareness/Training) | 2 | Security awareness |

**Families with zero coverage** (by design -- not assessable via M365 config export):

PE (Physical), CP (Contingency Planning), PS (Personnel), MA (Maintenance), MP (Media Protection), IR (Incident Response), SA (System Acquisition), SR (Supply Chain), PL (Planning), PM (Program Management), PT (Privacy), RA (Risk Assessment), CA (Security Assessment)

### Baseline Profiles

Both CIS and NIST use cumulative profile hierarchies. Each registry entry includes a `profiles` array indicating which baselines apply:

- **CIS:** `["E3-L1", "E5-L1"]` -- L1 is a subset of L2; E3 is a subset of E5
- **NIST:** `["Low", "Moderate", "High"]` -- Low is a subset of Moderate, which is a subset of High; Privacy is independent

Consumers can use profiles to scope coverage reporting accurately. For example, instead of reporting *"25 of 1,189 NIST controls"*, a consumer can report *"Of the 149 Low baseline controls, 25 are M365-assessable and we check all 25."*

### Essential Eight (ASD)

The [Essential Eight](https://www.cyber.gov.au/resources-business-and-government/essential-cyber-security/essential-eight) is published by the Australian Signals Directorate (ASD). It defines eight mitigation strategies at three maturity levels:

| Strategy | Key | Description |
|----------|-----|-------------|
| Application Control | P1 | Prevent execution of unapproved programs |
| Patch Applications | P2 | Patch security vulnerabilities in applications |
| Configure Microsoft Office Macro Settings | P3 | Disable macros for users without a business requirement |
| User Application Hardening | P4 | Harden web browsers and applications |
| Restrict Administrative Privileges | P5 | Validate and monitor privileged access |
| Patch Operating Systems | P6 | Patch security vulnerabilities in operating systems |
| Multi-Factor Authentication | P7 | Require stronger authentication for sensitive systems |
| Regular Backups | P8 | Back up data, applications, and settings |

Control IDs use the format `ML{level}-P{strategy}` (e.g., `ML1-P4;ML2-P4;ML3-P4`). Higher maturity levels are cumulative — ML3 includes all ML2 requirements, which include all ML1 requirements.

Seven of the eight strategies (P1–P7) are mapped to M365 checks. P8 (Regular Backups) is not assessable through M365 configuration export. Essential Eight mappings are derived from NIST 800-53 controls via the SecFrame SCF transitive bridge.

The framework definition is in `data/frameworks/essential-eight.json`.

## How It Works End-to-End

```
Collector runs          CSV output              Report generator
---------------        ----------              ----------------
Entra collector   ->  CheckId column in CSV  ->  Looks up CheckId
checks settings      (e.g., ENTRA-ADMIN-001)   in registry.json
                                                    |
                                                    v
                                              Extracts ALL framework
                                              mappings from one entry
                                                    |
                                                    v
                                              Populates 14 framework
                                              columns in compliance
                                              matrix (HTML + XLSX)
```

1. **Collectors** evaluate security settings and tag each finding with a CheckId
2. **CSV output** contains the CheckId as a column alongside Status, Setting, Remediation
3. **Report generator** loads the control registry, looks up each CheckId, and extracts all framework mappings
4. **Compliance matrix** shows one row per check with columns for every framework's control IDs

## Status Values

Each check produces one of five statuses:

| Status | Meaning | Scoring |
|--------|---------|---------|
| Pass | Meets benchmark requirement | Counted in pass rate |
| Fail | Violates benchmark -- CIS says "Ensure" and the setting is wrong | Counted in pass rate |
| Warning | Degraded security -- suboptimal but not a hard violation | Counted in pass rate |
| Review | Cannot determine automatically -- requires manual assessment | Counted in pass rate |
| Info | Informational data point -- no right/wrong answer | **Excluded** from scoring |

## Building the Registry

The registry can be generated from two CSV source files:

```
data/framework-mappings.csv          ->  CIS controls + framework cross-references
data/check-id-mapping.csv            ->  CheckId assignments + collector mapping
                                         |
                                         v
                               scripts/Build-Registry.ps1
                                         |
                                         v
                               data/registry.json (169 entries)
```

To rebuild after editing the source CSVs:

```powershell
.\scripts\Build-Registry.ps1
```

> **Note:** New automated checks added since v0.7.0 are typically added directly to `registry.json` rather than going through the CSV pipeline. Both approaches produce the same registry format.

## Adding a New CheckId

1. **Assign the CheckId** following the `{COLLECTOR}-{AREA}-{NNN}` convention
2. **Add the entry** to `data/registry.json` with framework mappings
3. **Add the check** to the appropriate collector script using `Add-Setting -CheckId 'YOUR-CHECK-001'`
5. **Run tests** to validate: `Invoke-Pester -Path './tests'`

### Checklist for New Checks

- [ ] CheckId follows `{COLLECTOR}-{AREA}-{NNN}` format
- [ ] Registry entry has `hasAutomatedCheck: true`, `collector`, `category`, and `licensing`
- [ ] All applicable framework mappings included (at minimum: `cis-m365-v6`, `nist-800-53`, `soc2`)
- [ ] Collector uses `Add-Setting` with `-CheckId` parameter
- [ ] Status logic: Pass/Fail for deterministic checks, Review for API gaps, Info for data points
- [ ] Remediation text includes specific portal path or PowerShell command
- [ ] Registry integrity tests pass (`Invoke-Pester ./tests/`)

## Using CheckIds in Reports

The compliance matrix appears in both the HTML report and the XLSX export:

- **HTML report** -- Interactive table with framework column toggles and status filters
- **XLSX export** -- `_Compliance-Matrix_{tenant}.xlsx` with two sheets: full matrix + per-framework summary with pass rates

Both are driven by the same CheckId -> registry lookup. If a check has a CheckId and the registry has an entry, it appears in the compliance matrix automatically.
