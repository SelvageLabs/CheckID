# CheckID Python Client

Python client for the [CheckID](https://github.com/SelvageLabs/CheckID) compliance registry — dependency-free access to the control registry from Python tools.

## Installation

**From the repository (editable install):**

```bash
pip install -e clients/python
```

## Usage

```python
from checkid import CheckIDRegistry

reg = CheckIDRegistry()         # loads data/registry.json from the repo root

# Look up a specific check
check = reg.get_by_id("ENTRA-ADMIN-001")
print(check["name"])
# → "Ensure that between two and four global admins are designated"
print(check["frameworks"]["nist-800-53"]["controlId"])
# → "AC-2;AC-6"

# Search by framework
hipaa_checks = reg.search(framework="hipaa")
print(f"{len(hipaa_checks)} HIPAA-mapped checks")

# Search by control ID substring
ac6_checks = reg.search(control_id="AC-6")

# Combined search
results = reg.search(framework="hipaa", keyword="password")

# Framework coverage statistics (excludes superseded entries)
for cov in reg.framework_coverage():
    print(f"{cov['framework_key']:20s}  {cov['check_count']:3d} checks  "
          f"({cov['automated_count']} automated)")
```

## Custom Registry Path

If you distribute only the JSON (not the full repo):

```python
reg = CheckIDRegistry(registry_path="/path/to/registry.json")
```

## API Reference

### `CheckIDRegistry(registry_path=None)`

Loads the registry from disk.  If `registry_path` is omitted, looks for
`data/registry.json` relative to the repository root (the directory three
levels above the `checkid/` package directory).

| Method | Description |
|--------|-------------|
| `get_by_id(check_id)` | Return a single check dict by exact CheckId, or `None` |
| `search(*, framework, control_id, keyword)` | Filter checks (all params optional, AND semantics) |
| `framework_coverage()` | Per-framework check counts (superseded excluded) |
| `checks` | All check dicts (property) |
| `schema_version` | Registry schema version string |
| `data_version` | Registry data date string |
| `__len__` | Total check count including superseded |
| `__iter__` | Iterate over all checks |

## Requirements

- Python 3.9+
- No third-party dependencies
