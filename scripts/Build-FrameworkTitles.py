#!/usr/bin/env python3
"""Build framework control title lookups from SecFrame sources.

Reads NIST OSCAL catalogs and other structured sources to produce
data/framework-titles.json — a lookup table mapping control IDs to
human-readable titles for each framework.

Usage:
    python scripts/Build-FrameworkTitles.py
    python scripts/Build-FrameworkTitles.py --secframe C:/git/SecFrame
"""
import argparse
import csv
import io
import json
import os
import re
import sys
from pathlib import Path

# Ensure UTF-8 output on Windows
if sys.stdout.encoding != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

SCRIPT_DIR = Path(__file__).parent
REPO_ROOT = SCRIPT_DIR.parent
DEFAULT_OUTPUT = REPO_ROOT / "data" / "framework-titles.json"


def extract_oscal_controls(catalog_path: Path, use_prose: bool = False) -> dict[str, str]:
    """Extract control ID -> title from an OSCAL JSON catalog.

    Args:
        catalog_path: Path to the OSCAL catalog JSON.
        use_prose: If True, prefer the 'statement' part prose over the title
                   field for subcategories (needed for CSF where subcategory
                   titles are just the ID repeated).
    """
    with open(catalog_path, encoding="utf-8") as f:
        data = json.load(f)

    titles = {}
    for group in data.get("catalog", {}).get("groups", []):
        for ctrl in group.get("controls", []):
            cid = ctrl["id"].upper()
            titles[cid] = ctrl["title"]
            for sub in ctrl.get("controls", []):
                sid = sub["id"].upper()
                title = _get_prose(sub) if use_prose else sub["title"]
                # Fall back to title field if prose is empty
                titles[sid] = title or sub["title"]
    return titles


def _get_prose(control: dict) -> str | None:
    """Extract the statement prose from an OSCAL control's parts."""
    for part in control.get("parts", []):
        if part.get("name") == "statement" and part.get("prose"):
            return part["prose"]
    return None


def build_nist_800_53(secframe: Path) -> dict[str, str]:
    """Build NIST 800-53 Rev 5 title lookup."""
    catalog = secframe / "NIST" / "NIST_SP-800-53_rev5_catalog.json"
    if not catalog.exists():
        print(f"  WARNING: {catalog} not found")
        return {}
    titles = extract_oscal_controls(catalog)
    print(f"  nist-800-53: {len(titles)} titles from OSCAL catalog")
    return titles


def build_nist_csf(secframe: Path) -> dict[str, str]:
    """Build NIST CSF 2.0 title lookup.

    Uses prose extraction because CSF subcategory 'title' fields just repeat
    the control ID (e.g., PR.AA-03 -> "PR.AA-03").  The real description lives
    in each subcategory's statement prose.
    """
    catalog = secframe / "NIST" / "NIST_CSF_v2.0_catalog.json"
    if not catalog.exists():
        print(f"  WARNING: {catalog} not found")
        return {}
    titles = extract_oscal_controls(catalog, use_prose=True)
    print(f"  nist-csf: {len(titles)} titles from OSCAL catalog")
    return titles


# Static title lookups for frameworks without structured sources.
# These cover the control IDs actually used in CheckID's registry.

ISO_27001_TITLES = {
    "A.5.1": "Policies for information security",
    "A.5.2": "Information security roles and responsibilities",
    "A.5.3": "Segregation of duties",
    "A.5.4": "Management responsibilities",
    "A.5.5": "Contact with authorities",
    "A.5.6": "Contact with special interest groups",
    "A.5.7": "Threat intelligence",
    "A.5.8": "Information security in project management",
    "A.5.9": "Inventory of information and other associated assets",
    "A.5.10": "Acceptable use of information and other associated assets",
    "A.5.11": "Return of assets",
    "A.5.12": "Classification of information",
    "A.5.13": "Labelling of information",
    "A.5.14": "Information transfer",
    "A.5.15": "Access control",
    "A.5.16": "Identity management",
    "A.5.17": "Authentication information",
    "A.5.18": "Access rights",
    "A.5.19": "Information security in supplier relationships",
    "A.5.20": "Addressing information security within supplier agreements",
    "A.5.21": "Managing information security in the ICT supply chain",
    "A.5.22": "Monitoring, review and change management of supplier services",
    "A.5.23": "Information security for use of cloud services",
    "A.5.24": "Information security incident management planning and preparation",
    "A.5.25": "Assessment and decision on information security events",
    "A.5.26": "Response to information security incidents",
    "A.5.27": "Learning from information security incidents",
    "A.5.28": "Collection of evidence",
    "A.5.29": "Information security during disruption",
    "A.5.30": "ICT readiness for business continuity",
    "A.5.31": "Legal, statutory, regulatory and contractual requirements",
    "A.5.32": "Intellectual property rights",
    "A.5.33": "Protection of records",
    "A.5.34": "Privacy and protection of PII",
    "A.5.35": "Independent review of information security",
    "A.5.36": "Compliance with policies, rules and standards for information security",
    "A.5.37": "Documented operating procedures",
    "A.6.1": "Screening",
    "A.6.2": "Terms and conditions of employment",
    "A.6.3": "Information security awareness, education and training",
    "A.6.4": "Disciplinary process",
    "A.6.5": "Responsibilities after termination or change of employment",
    "A.6.6": "Confidentiality or non-disclosure agreements",
    "A.6.7": "Remote working",
    "A.6.8": "Information security event reporting",
    "A.7.1": "Physical security perimeters",
    "A.7.2": "Physical entry",
    "A.7.3": "Securing offices, rooms and facilities",
    "A.7.4": "Physical security monitoring",
    "A.7.5": "Protecting against physical and environmental threats",
    "A.7.6": "Working in secure areas",
    "A.7.7": "Clear desk and clear screen",
    "A.7.8": "Equipment siting and protection",
    "A.7.9": "Security of assets off-premises",
    "A.7.10": "Storage media",
    "A.7.11": "Supporting utilities",
    "A.7.12": "Cabling security",
    "A.7.13": "Equipment maintenance",
    "A.7.14": "Secure disposal or re-use of equipment",
    "A.8.1": "User endpoint devices",
    "A.8.2": "Privileged access rights",
    "A.8.3": "Information access restriction",
    "A.8.4": "Access to source code",
    "A.8.5": "Secure authentication",
    "A.8.6": "Capacity management",
    "A.8.7": "Protection against malware",
    "A.8.8": "Management of technical vulnerabilities",
    "A.8.9": "Configuration management",
    "A.8.10": "Information deletion",
    "A.8.11": "Data masking",
    "A.8.12": "Data leakage prevention",
    "A.8.13": "Information backup",
    "A.8.14": "Redundancy of information processing facilities",
    "A.8.15": "Logging",
    "A.8.16": "Monitoring activities",
    "A.8.17": "Clock synchronization",
    "A.8.18": "Use of privileged utility programs",
    "A.8.19": "Installation of software on operational systems",
    "A.8.20": "Networks security",
    "A.8.21": "Security of network services",
    "A.8.22": "Segregation of networks",
    "A.8.23": "Web filtering",
    "A.8.24": "Use of cryptography",
    "A.8.25": "Secure development life cycle",
    "A.8.26": "Application security requirements",
    "A.8.27": "Secure system architecture and engineering principles",
    "A.8.28": "Secure coding",
    "A.8.29": "Security testing in development and acceptance",
    "A.8.30": "Outsourced development",
    "A.8.31": "Separation of development, test and production environments",
    "A.8.32": "Change management",
    "A.8.33": "Test information",
    "A.8.34": "Protection of information systems during audit testing",
}

SOC2_TITLES = {
    "CC1": "Control Environment",
    "CC1.1": "COSO Principle 1: Integrity and Ethical Values",
    "CC1.2": "COSO Principle 2: Board Independence and Oversight",
    "CC1.3": "COSO Principle 3: Management Establishes Structures and Reporting Lines",
    "CC1.4": "COSO Principle 4: Commitment to Competence",
    "CC1.5": "COSO Principle 5: Enforces Accountability",
    "CC2": "Communication and Information",
    "CC2.1": "COSO Principle 13: Obtains or Generates Relevant Information",
    "CC2.2": "COSO Principle 14: Internal Communication",
    "CC2.3": "COSO Principle 15: External Communication",
    "CC3": "Risk Assessment",
    "CC3.1": "COSO Principle 6: Specifies Suitable Objectives",
    "CC3.2": "COSO Principle 7: Identifies and Analyzes Risk",
    "CC3.3": "COSO Principle 8: Assesses Fraud Risk",
    "CC3.4": "COSO Principle 9: Identifies and Analyzes Changes",
    "CC4": "Monitoring Activities",
    "CC4.1": "COSO Principle 16: Selects and Develops Ongoing and Separate Evaluations",
    "CC4.2": "COSO Principle 17: Evaluates and Communicates Deficiencies",
    "CC5": "Control Activities",
    "CC5.1": "COSO Principle 10: Selects and Develops Control Activities",
    "CC5.2": "COSO Principle 11: Selects and Develops General Controls over Technology",
    "CC5.3": "COSO Principle 12: Deploys through Policies and Procedures",
    "CC6": "Logical and Physical Access Controls",
    "CC6.1": "Logical Access Security Software, Infrastructure, and Architectures",
    "CC6.2": "Prior to Issuing System Credentials and Granting System Access",
    "CC6.3": "Enrollment and Authorization Based on Credentials",
    "CC6.6": "Restriction of Access to System Boundaries",
    "CC6.7": "Data Transmission and Movement Restriction",
    "CC6.8": "Prevention and Detection of Unauthorized Software",
    "CC7": "System Operations",
    "CC7.1": "Detection and Monitoring of New Vulnerabilities",
    "CC7.2": "Monitoring System Components for Anomalies",
    "CC7.3": "Evaluation of Identified Security Events",
    "CC7.4": "Response to Identified Security Incidents",
    "CC7.5": "Identification of Recovery from Identified Security Incidents",
    "CC8": "Change Management",
    "CC8.1": "Changes to Infrastructure, Data, Software, and Procedures",
    "CC9": "Risk Mitigation",
    "CC9.1": "Risk Mitigation Identification and Selection",
    "CC9.2": "Vendor and Business Partner Risk Management",
}

# Keys include the § prefix to match the registry CSV encoding (§164.xxx).
# The CSV embeds § (U+00A7) as a hidden prefix on HIPAA section references.
HIPAA_TITLES = {
    "\u00a7164.308(a)(1)(i)": "Security Management Process",
    "\u00a7164.308(a)(1)(ii)(A)": "Risk Analysis",
    "\u00a7164.308(a)(1)(ii)(B)": "Risk Management",
    "\u00a7164.308(a)(1)(ii)(C)": "Sanction Policy",
    "\u00a7164.308(a)(1)(ii)(D)": "Information System Activity Review",
    "\u00a7164.308(a)(2)": "Assigned Security Responsibility",
    "\u00a7164.308(a)(3)(i)": "Workforce Security",
    "\u00a7164.308(a)(3)(ii)(A)": "Authorization and/or Supervision",
    "\u00a7164.308(a)(3)(ii)(B)": "Workforce Clearance Procedure",
    "\u00a7164.308(a)(3)(ii)(C)": "Termination Procedures",
    "\u00a7164.308(a)(4)(i)": "Information Access Management",
    "\u00a7164.308(a)(4)(ii)(A)": "Isolating Health Care Clearinghouse Functions",
    "\u00a7164.308(a)(4)(ii)(B)": "Access Authorization",
    "\u00a7164.308(a)(4)(ii)(C)": "Access Establishment and Modification",
    "\u00a7164.308(a)(5)(i)": "Security Awareness and Training",
    "\u00a7164.308(a)(5)(ii)(A)": "Security Reminders",
    "\u00a7164.308(a)(5)(ii)(B)": "Protection from Malicious Software",
    "\u00a7164.308(a)(5)(ii)(C)": "Log-in Monitoring",
    "\u00a7164.308(a)(5)(ii)(D)": "Password Management",
    "\u00a7164.308(a)(6)(i)": "Security Incident Procedures",
    "\u00a7164.308(a)(6)(ii)": "Response and Reporting",
    "\u00a7164.308(a)(7)(i)": "Contingency Plan",
    "\u00a7164.308(a)(7)(ii)(A)": "Data Backup Plan",
    "\u00a7164.308(a)(7)(ii)(B)": "Disaster Recovery Plan",
    "\u00a7164.308(a)(7)(ii)(C)": "Emergency Mode Operation Plan",
    "\u00a7164.308(a)(7)(ii)(D)": "Testing and Revision Procedures",
    "\u00a7164.308(a)(7)(ii)(E)": "Applications and Data Criticality Analysis",
    "\u00a7164.308(a)(8)": "Evaluation",
    "\u00a7164.310(a)(1)": "Facility Access Controls",
    "\u00a7164.310(a)(2)(i)": "Contingency Operations",
    "\u00a7164.310(a)(2)(ii)": "Facility Security Plan",
    "\u00a7164.310(a)(2)(iii)": "Access Control and Validation Procedures",
    "\u00a7164.310(a)(2)(iv)": "Maintenance Records",
    "\u00a7164.310(b)": "Workstation Use",
    "\u00a7164.310(c)": "Workstation Security",
    "\u00a7164.310(d)(1)": "Device and Media Controls",
    "\u00a7164.310(d)(2)(i)": "Disposal",
    "\u00a7164.310(d)(2)(ii)": "Media Re-use",
    "\u00a7164.310(d)(2)(iii)": "Accountability",
    "\u00a7164.310(d)(2)(iv)": "Data Backup and Storage",
    "\u00a7164.312(a)(1)": "Access Control",
    "\u00a7164.312(a)(2)(i)": "Unique User Identification",
    "\u00a7164.312(a)(2)(ii)": "Emergency Access Procedure",
    "\u00a7164.312(a)(2)(iii)": "Automatic Logoff",
    "\u00a7164.312(a)(2)(iv)": "Encryption and Decryption",
    "\u00a7164.312(b)": "Audit Controls",
    "\u00a7164.312(c)(1)": "Integrity",
    "\u00a7164.312(c)(2)": "Mechanism to Authenticate Electronic PHI",
    "\u00a7164.312(d)": "Person or Entity Authentication",
    "\u00a7164.312(e)(1)": "Transmission Security",
    "\u00a7164.312(e)(2)(i)": "Integrity Controls",
    "\u00a7164.312(e)(2)(ii)": "Encryption",
    "\u00a7164.316(a)": "Policies and Procedures",
    "\u00a7164.316(b)(1)": "Documentation",
    "\u00a7164.316(b)(2)(i)": "Time Limit",
    "\u00a7164.316(b)(2)(ii)": "Availability",
    "\u00a7164.316(b)(2)(iii)": "Updates",
}


def resolve_title(control_id: str, titles: dict[str, str]) -> str | None:
    """Look up a title, trying exact match then progressively shorter keys."""
    cid = control_id.strip()
    if cid in titles:
        return titles[cid]
    # Try uppercase
    if cid.upper() in titles:
        return titles[cid.upper()]
    # For NIST-style IDs, try without trailing letter (e.g., AC-17a -> AC-17)
    base = re.sub(r'[a-z]$', '', cid)
    if base in titles:
        return titles[base]
    if base.upper() in titles:
        return titles[base.upper()]
    return None


def build_combined_title(control_ids: str, titles: dict[str, str]) -> str | None:
    """Build a combined title from semicolon-separated control IDs."""
    parts = [p.strip() for p in control_ids.split(";") if p.strip()]
    resolved = []
    for cid in parts:
        t = resolve_title(cid, titles)
        if t and t not in resolved:
            resolved.append(t)
    return "; ".join(resolved) if resolved else None


def main():
    parser = argparse.ArgumentParser(description="Build framework title lookups")
    parser.add_argument(
        "--secframe", type=Path,
        default=Path("C:/git/SecFrame"),
        help="Path to SecFrame repository",
    )
    parser.add_argument(
        "--output", type=Path, default=DEFAULT_OUTPUT,
        help="Output JSON path",
    )
    args = parser.parse_args()

    if not args.secframe.exists():
        print(f"ERROR: SecFrame not found at {args.secframe}")
        print("Pass --secframe /path/to/SecFrame")
        sys.exit(1)

    print("Building framework title lookups...")

    result = {
        "nist-800-53": build_nist_800_53(args.secframe),
        "nist-csf": build_nist_csf(args.secframe),
        "iso-27001": ISO_27001_TITLES,
        "hipaa": HIPAA_TITLES,
        "soc2": SOC2_TITLES,
    }

    print(f"  iso-27001: {len(ISO_27001_TITLES)} titles (static)")
    print(f"  hipaa: {len(HIPAA_TITLES)} titles (static)")
    print(f"  soc2: {len(SOC2_TITLES)} titles (static)")
    print(f"  stig: (no title source — uses raw control IDs)")
    print(f"  pci-dss: (no title source — uses raw control IDs)")
    print(f"  cmmc: (no title source — uses raw control IDs)")
    print(f"  cisa-scuba: (no title source — uses raw control IDs)")

    # Write output
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    print(f"\nWritten to {args.output}")
    total = sum(len(v) for v in result.values())
    print(f"Total titles: {total}")


if __name__ == "__main__":
    main()
