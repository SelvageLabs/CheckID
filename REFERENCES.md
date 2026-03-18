# CheckID References

## Upstream: SecFrame

[SecFrame](https://github.com/SelvageLabs/SecFrame) is the authoritative source
for security framework reference data. CheckID's framework mappings are derived from:

| SecFrame File | What It Provides |
|---------------|-----------------|
| `CIS/CIS_M365_to_NIST_to_FedRAMP_Crosswalk.csv` | CIS M365 to NIST 800-53 to FedRAMP mappings |
| `SOC/tsc_to_nist_800-53.xlsx` | SOC 2 Trust Services Criteria to NIST 800-53 |
| `SCF/secure-controls-framework-scf-2025-4.csv` | Master cross-framework mapping (80+ frameworks) |
| `SCF/scf.db` | Normalized SQLite database (13 tables, 261 frameworks, 66K+ mappings) |
| `SCF/checkid-framework-export.csv` | CheckID-compatible flat export from SCF database |
| `NIST/csf-pf-to-sp800-53r5-mappings.xlsx` | NIST CSF 2.0 to NIST 800-53 R5 |

### Update Workflow

1. Update relevant source files in SecFrame
2. Update `data/framework-mappings.csv` and/or `data/check-id-mapping.csv` in this repo
3. Run `scripts/Build-Registry.ps1` to regenerate `data/registry.json`
4. Commit and push
5. Consumers bump their CheckID submodule pointer

## Downstream Consumers

These projects consume CheckID. All currently use git submodules; migration to the
PSGallery module is in progress.

| Project | Repository | Current Method | Target Method |
|---------|-----------|---------------|--------------|
| **M365-Assess** | [SelvageLabs/M365-Assess](https://github.com/SelvageLabs/M365-Assess) | Submodule (`lib/CheckID/`) | `Install-Module CheckID` |
| **Stitch-M365** | Private | Submodule (`Engine/lib/CheckID/`) | `Install-Module CheckID` |
| **Darn** | [SelvageLabs/Darn](https://github.com/SelvageLabs/Darn) | Submodule (`lib/CheckID/`) | `Install-Module CheckID` |
| **M365-Remediate** | [SelvageLabs/M365-Remediate](https://github.com/SelvageLabs/M365-Remediate) | Submodule (`lib/CheckID/`) | `Install-Module CheckID` |

### Migration: Submodule to PSGallery Module

**For consumers migrating from git submodule to `Install-Module`:**

1. Install the module: `Install-Module -Name CheckID -Scope CurrentUser`
2. Replace dot-source imports:
   ```powershell
   # Before (submodule)
   . ./lib/CheckID/scripts/Import-ControlRegistry.ps1
   $registry = Import-ControlRegistry -ControlsPath ./lib/CheckID/data
   $check = $registry['ENTRA-ADMIN-001']

   # After (module)
   Import-Module CheckID
   $check = Get-CheckById 'ENTRA-ADMIN-001'
   # Or load all checks:
   $checks = Get-CheckRegistry
   ```
3. Replace script calls with module cmdlets:
   - `Import-ControlRegistry` → `Get-CheckRegistry` / `Get-CheckById`
   - `Search-Registry.ps1` → `Search-Check`
   - `Test-RegistryData.ps1` → `Test-CheckRegistryData`
4. Remove the submodule: `git submodule deinit lib/CheckID && git rm lib/CheckID`

Both approaches work simultaneously during the transition period.
