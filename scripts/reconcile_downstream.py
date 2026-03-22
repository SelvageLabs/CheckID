#!/usr/bin/env python3
"""Reconcile downstream check registries against CheckID.

Reads CheckID, M365-Assess, M365-Remediate, and StrykerScan to find
checks that exist downstream but not in CheckID's registry.

Outputs:
  - Console report of missing checks
  - standalone-checks-additions.json with entries to add
"""
import json
import os
import re
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
GIT_ROOT = REPO_ROOT.parent  # C:\git

def load_checkid_registry():
    """Load CheckID registry.json and standalone-checks.json."""
    reg = json.loads((REPO_ROOT / "data" / "registry.json").read_text(encoding="utf-8"))
    ids = {c["checkId"] for c in reg["checks"]}
    return ids

def load_m365_assess_registry():
    """Load M365-Assess controls/registry.json."""
    path = GIT_ROOT / "M365-Assess" / "controls" / "registry.json"
    if not path.exists():
        print(f"  SKIP: {path} not found")
        return {}
    reg = json.loads(path.read_text())
    return {c["checkId"]: c for c in reg["checks"]}

def load_m365_remediate_yaml():
    """Extract checkIds from M365-Remediate YAML files."""
    remed_dir = GIT_ROOT / "M365-Remediate" / "remediation"
    if not remed_dir.exists():
        print(f"  SKIP: {remed_dir} not found")
        return set()
    ids = set()
    for yaml_file in remed_dir.rglob("*.yaml"):
        text = yaml_file.read_text(errors="replace")
        match = re.search(r"^checkId:\s*(.+)", text, re.MULTILINE)
        if match:
            ids.add(match.group(1).strip())
    return ids

def load_strykerscan_checks():
    """Extract STK-xxx IDs from StrykerScan check scripts."""
    checks_dir = GIT_ROOT / "StrykerScan" / "checks"
    if not checks_dir.exists():
        print(f"  SKIP: {checks_dir} not found")
        return {}
    stk = {}
    for ps1 in checks_dir.glob("*.ps1"):
        text = ps1.read_text(errors="replace")
        id_match = re.search(r"CheckId\s*=\s*['\"]?(STK-\d+)", text)
        name_match = re.search(r"Name\s*=\s*['\"]([^'\"]+)", text)
        if id_match:
            stk_id = id_match.group(1)
            stk[stk_id] = name_match.group(1) if name_match else ps1.stem
    return stk

def main():
    print("=== CheckID Downstream Reconciliation ===\n")

    # Load all sources
    checkid_ids = load_checkid_registry()
    print(f"CheckID registry: {len(checkid_ids)} checks")

    assess_checks = load_m365_assess_registry()
    print(f"M365-Assess registry: {len(assess_checks)} checks")

    remediate_ids = load_m365_remediate_yaml()
    print(f"M365-Remediate YAML: {len(remediate_ids)} checkIds")

    stryker_checks = load_strykerscan_checks()
    print(f"StrykerScan: {len(stryker_checks)} checks")

    # Compute diffs
    assess_missing = {cid for cid in assess_checks if cid not in checkid_ids}
    remediate_missing = remediate_ids - checkid_ids
    # STK IDs use different format, all are "missing" by definition

    # Filter out MANUAL-CIS-* (intentionally excluded from CheckID)
    manual_cis = {cid for cid in assess_missing if cid.startswith("MANUAL-CIS")}
    assess_actionable = assess_missing - manual_cis

    print(f"\n--- DIFF RESULTS ---")
    print(f"M365-Assess missing (total): {len(assess_missing)}")
    print(f"  MANUAL-CIS (excluded): {len(manual_cis)}")
    print(f"  Actionable: {len(assess_actionable)}")
    print(f"M365-Remediate missing: {len(remediate_missing)}")
    print(f"StrykerScan (all new): {len(stryker_checks)}")

    # Build additions from M365-Assess (has full framework data)
    additions = []
    for cid in sorted(assess_actionable):
        check = assess_checks[cid]
        entry = {
            "checkId": check["checkId"],
            "name": check.get("name", ""),
            "category": check.get("category", ""),
            "collector": check.get("collector", ""),
        }
        if check.get("impactRating"):
            entry["impactRating"] = check["impactRating"]
        if check.get("frameworks"):
            fw = {}
            if hasattr(check["frameworks"], "__iter__") and not isinstance(check["frameworks"], str):
                # Handle dict or object
                if isinstance(check["frameworks"], dict):
                    fw = check["frameworks"]
                else:
                    # PSCustomObject serialized as dict
                    fw = dict(check["frameworks"])
            entry["frameworks"] = fw
        additions.append(entry)

    # Add M365-Remediate checks that are missing and NOT already covered by M365-Assess
    remediate_only = remediate_missing - assess_actionable - manual_cis
    for cid in sorted(remediate_only):
        additions.append({
            "checkId": cid,
            "name": f"(from M365-Remediate YAML, needs enrichment)",
            "category": cid.split("-")[1] if "-" in cid else "",
            "collector": cid.split("-")[0] if "-" in cid else "",
            "frameworks": {}
        })

    # Output report
    print(f"\n--- ACTIONABLE CHECKS TO ADD ---")
    print(f"Total additions: {len(additions)}")
    for a in additions:
        fw_count = len(a.get("frameworks", {}))
        print(f"  {a['checkId']}: {a['name'][:60]} ({fw_count} frameworks)")

    print(f"\n--- STRYKER CHECKS (need mapping file) ---")
    for stk_id, name in sorted(stryker_checks.items()):
        print(f"  {stk_id}: {name}")

    # Write additions file
    out_path = REPO_ROOT / "data" / "standalone-checks-additions.json"
    with open(out_path, "w") as f:
        json.dump(additions, f, indent=2)
    print(f"\nWritten {len(additions)} entries to {out_path}")

    # Write STK mapping template
    stk_path = REPO_ROOT / "data" / "stryker-mapping-template.json"
    with open(stk_path, "w") as f:
        json.dump(stryker_checks, f, indent=2)
    print(f"Written STK mapping template to {stk_path}")

if __name__ == "__main__":
    main()
