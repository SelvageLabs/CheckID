# CheckID References

## Upstream: SecFrame

[SecFrame](https://github.com/SelvageLabs/SecFrame) (`C:\git\SecFrame`) is the authoritative source
for security framework reference data. CheckID's framework mappings are derived from:

| SecFrame File | What It Provides |
|---------------|-----------------|
| `CIS/CIS_M365_to_NIST_to_FedRAMP_Crosswalk.csv` | CIS M365 to NIST 800-53 to FedRAMP mappings |
| `SOC/tsc_to_nist_800-53.xlsx` | SOC 2 Trust Services Criteria to NIST 800-53 |
| `SCF/secure-controls-framework-scf-2025-4.csv` | Master cross-framework mapping (80+ frameworks) |
| `NIST/csf-pf-to-sp800-53r5-mappings.xlsx` | NIST CSF 2.0 to NIST 800-53 R5 |

### Update Workflow

1. Update relevant source files in SecFrame
2. Update `data/framework-mappings.csv` and/or `data/check-id-mapping.csv` in this repo
3. Run `scripts/Build-Registry.ps1` to regenerate `data/registry.json`
4. Commit and push
5. Consumers bump their CheckID submodule pointer

## Downstream Consumers

These projects consume CheckID as a git submodule:

| Project | Repository | Submodule Path | What They Use |
|---------|-----------|---------------|--------------|
| **M365-Assess** | [github.com/SelvageLabs/M365-Assess](https://github.com/SelvageLabs/M365-Assess) | `lib/CheckID/` | Full library (scripts + data) |
| **Stitch-M365** | Private | `Engine/lib/CheckID/` | Full library (scripts + data) |
| **Darn** | [github.com/SelvageLabs/Darn](https://github.com/SelvageLabs/Darn) | `lib/CheckID/` | Data only (`data/registry.json`) |
