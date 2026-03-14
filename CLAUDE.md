# CheckID -- Project Conventions

> Shared environment, PowerShell rules, and coding standards are inherited from the parent `../CLAUDE.md`.
> This file contains project-specific conventions only.

## Overview

CheckID is a **shared library** providing a universal identifier system for M365 security checks.
It maps 233 checks across 10 compliance frameworks. Changes here affect all downstream consumers.

- **Testing**: Pester 5.x -- on demand only
- **License**: MIT (public repository)

## Project Structure

```
CheckID/
├── data/          Registry data (JSON + CSVs) -- the core asset
│   └── frameworks/ Framework definitions (CIS, SOC2)
├── scripts/       PowerShell scripts that build, load, display, and export registry data
├── tests/         Pester tests for registry integrity
├── docs/          CheckId-Guide and design specs
├── CLAUDE.md      This file
├── REFERENCES.md  Upstream (SecFrame) and downstream (consumers) links
└── README.md      Public-facing overview
```

## Key Rules

1. **This is a shared library** -- M365-Assess, Stitch-M365, and Darn consume it via git submodule.
   After any change, consumers must bump their submodule pointer.
2. **After modifying CSVs**, run `scripts/Build-Registry.ps1` to regenerate `data/registry.json`.
3. **SecFrame is upstream** -- framework mapping data originates from `C:\git\SecFrame`. See REFERENCES.md.
4. **Do not add consumer-specific code** -- report generators, orchestrators, and collectors belong
   in their respective consumer repos, not here.

## Downstream Consumers

| Consumer | Submodule Path | Visibility |
|----------|---------------|------------|
| M365-Assess | `lib/CheckID/` | Public (MIT) |
| Stitch-M365 | `Engine/lib/CheckID/` | Private (commercial) |
| Darn | `lib/CheckID/` | Public (future) |

## Development Pipeline

### For data changes (CSV updates, new frameworks):
1. Update CSV(s) in `data/`
2. Run `scripts/Build-Registry.ps1` to regenerate `data/registry.json`
3. Run Pester tests: `Invoke-Pester ./tests/`
4. Commit all changed files

### For script changes:
1. Make the change
2. Verify parse: `Get-Command ./scripts/<file>.ps1`
3. Run Pester tests: `Invoke-Pester ./tests/`
4. Commit
