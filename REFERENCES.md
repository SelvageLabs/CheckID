# CheckID References

## Upstream: SecFrame

[SecFrame](https://github.com/Galvnyz/SecFrame) is the authoritative source
for security framework reference data. CheckID's framework mappings are derived from:

| SecFrame File | What It Provides |
|---------------|-----------------|
| `CIS/CIS_M365_to_NIST_to_FedRAMP_Crosswalk.csv` | CIS M365 to NIST 800-53 to FedRAMP mappings |
| `SOC/tsc_to_nist_800-53.xlsx` | SOC 2 Trust Services Criteria to NIST 800-53 |
| `SCF/secure-controls-framework-scf-2025-4.csv` | Master cross-framework mapping (80+ frameworks) |
| `SCF/scf.db` | Normalized SQLite database (13 tables, 261 frameworks, 66K+ mappings) |
| `SCF/checkid-framework-export.csv` | CheckID-compatible flat export from SCF database |
| `NIST/csf-pf-to-sp800-53r5-mappings.xlsx` | NIST CSF 2.0 to NIST 800-53 R5 |

### Update Workflow (Automated)

When SecFrame merges changes to framework data directories, the CI cascade triggers:

1. **SecFrame** `notify-checkid.yml` dispatches `secframe-updated` to CheckID
2. **CheckID** `rebuild-from-secframe.yml` fetches latest data, rebuilds registry, opens PR
3. After PR merge and tag, `notify-downstream.yml` dispatches `checkid-released` to consumers
4. Consumers receive dispatch and auto-create sync PRs

Manual workflow: edit CSVs → `Build-Registry.ps1` → `Test-RegistryData.ps1` → commit → tag

## Downstream Consumers

| Project | Repository | Integration | Sync Method |
|---------|-----------|-------------|-------------|
| **M365-Assess** | [Galvnyz/M365-Assess](https://github.com/Galvnyz/M365-Assess) | CI cache (`controls/registry.json`) | `sync-checkid.yml` auto-PR on dispatch |
| **M365-Remediate** | [Galvnyz/M365-Remediate](https://github.com/Galvnyz/M365-Remediate) | Submodule (`lib/CheckID/`) | `sync-checkid.yml` auto-PR on dispatch |
| **StrykerScan** | [Galvnyz/StrykerScan](https://github.com/Galvnyz/StrykerScan) | Mapping file (`checks/checkid-mapping.json`) | Metadata only, not runtime |
| **Stitch-M365** | Private | Submodule (`Engine/lib/CheckID/`) | Manual submodule update |
| **Darn** | [Galvnyz/Darn](https://github.com/Galvnyz/Darn) | Planned | — |

### CI Cascade Flow

```
SecFrame merge → notify-checkid.yml → repository_dispatch
    ↓
CheckID rebuild-from-secframe.yml → PR → merge → tag
    ↓
CheckID notify-downstream.yml → repository_dispatch to:
    ├── M365-Assess sync-checkid.yml → fetch registry + frameworks → PR
    ├── M365-Remediate sync-checkid.yml → update submodule → PR
    └── StrykerScan (receives dispatch, validates mapping)
```

### Consumer Integration Guide

**CI cache sync** (recommended for PowerShell tools like M365-Assess):
- Add `sync-checkid.yml` workflow that receives `checkid-released` dispatch
- Fetch `data/registry.json` and `data/frameworks/*.json` from the tagged version
- Store in a local `controls/` directory

**Git submodule** (recommended for .NET apps like M365-Remediate):
```bash
git submodule add https://github.com/Galvnyz/CheckID.git lib/CheckID
```

**Mapping file** (recommended for standalone scanners like StrykerScan):
- Create `checkid-mapping.json` mapping local check IDs to CheckID universal IDs
- Metadata only — no runtime dependency on CheckID

### Secrets Required

Cross-repo dispatch requires a `CROSS_REPO_TOKEN` secret (classic GitHub PAT with `repo` + `workflow` scopes) configured in CheckID, SecFrame, and each consumer repo.
