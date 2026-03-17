"""
checkid — Python client for the CheckID compliance registry.

Provides lightweight, dependency-free access to registry.json so that
Python-based tools can look up checks, search by framework or control ID,
and obtain coverage statistics without shelling out to PowerShell.

Basic usage::

    from checkid import CheckIDRegistry

    reg = CheckIDRegistry()                      # loads bundled registry.json
    check = reg.get_by_id("ENTRA-ADMIN-001")
    print(check["name"])

    results = reg.search(framework="hipaa", keyword="password")
    coverage = reg.framework_coverage()
"""

from .registry import CheckIDRegistry

__all__ = ["CheckIDRegistry"]
__version__ = "1.0.0"
