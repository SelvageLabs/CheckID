"""
Registry loading and querying for the CheckID Python client.

The registry path defaults to the bundled ``data/registry.json`` located
three directories above this file (i.e. the repository root's data/ folder).
Consumers that package only the JSON can pass an explicit path::

    reg = CheckIDRegistry(registry_path="/path/to/registry.json")
"""

from __future__ import annotations

import json
import pathlib
from typing import Any, Dict, Iterator, List, Optional

# Default: <repo-root>/data/registry.json
_DEFAULT_REGISTRY = (
    pathlib.Path(__file__).resolve().parent.parent.parent.parent
    / "data"
    / "registry.json"
)


class CheckIDRegistry:
    """
    In-memory view of the CheckID control registry.

    Parameters
    ----------
    registry_path:
        Explicit path to ``registry.json``.  Defaults to the bundled copy at
        ``<repo-root>/data/registry.json``.

    Examples
    --------
    >>> reg = CheckIDRegistry()
    >>> check = reg.get_by_id("ENTRA-ADMIN-001")
    >>> check["name"]
    'Ensure that between two and four global admins are designated'
    >>> len(reg.search(framework="hipaa"))
    226
    """

    def __init__(self, registry_path: Optional[str | pathlib.Path] = None) -> None:
        path = pathlib.Path(registry_path) if registry_path else _DEFAULT_REGISTRY
        with open(path, encoding="utf-8") as fh:
            raw = json.load(fh)
        self._schema_version: str = raw.get("schemaVersion", "")
        self._data_version: str = raw.get("dataVersion", "")
        self._checks: List[Dict[str, Any]] = raw.get("checks", [])

    # ------------------------------------------------------------------
    # Properties
    # ------------------------------------------------------------------

    @property
    def schema_version(self) -> str:
        """Semver string for the registry schema (e.g. ``"1.0.0"``)."""
        return self._schema_version

    @property
    def data_version(self) -> str:
        """Date string for the registry data snapshot (e.g. ``"2026-03-15"``)."""
        return self._data_version

    @property
    def checks(self) -> List[Dict[str, Any]]:
        """All checks, including superseded MANUAL-CIS entries."""
        return self._checks

    # ------------------------------------------------------------------
    # Lookup
    # ------------------------------------------------------------------

    def get_by_id(self, check_id: str) -> Optional[Dict[str, Any]]:
        """
        Return the check with the given *check_id*, or ``None`` if not found.

        Parameters
        ----------
        check_id:
            Exact CheckId string (e.g. ``"ENTRA-ADMIN-001"``).
        """
        for check in self._checks:
            if check.get("checkId") == check_id:
                return check
        return None

    # ------------------------------------------------------------------
    # Search
    # ------------------------------------------------------------------

    def search(
        self,
        *,
        framework: Optional[str] = None,
        control_id: Optional[str] = None,
        keyword: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """
        Search the registry using one or more filter criteria.

        All supplied filters are applied together (AND semantics).  Omit a
        parameter to skip that filter.

        Parameters
        ----------
        framework:
            Framework registry key to match (e.g. ``"hipaa"``, ``"soc2"``).
            Only checks that have a mapping for this framework are returned.
        control_id:
            Control ID substring to search for across all framework mappings
            (or only within *framework* when both are supplied).
        keyword:
            Case-insensitive substring searched against check ``name``.

        Returns
        -------
        List of matching check dicts.

        Examples
        --------
        >>> reg = CheckIDRegistry()
        >>> reg.search(framework="hipaa", keyword="password")   # doctest: +SKIP
        [...]
        >>> reg.search(control_id="AC-6")                       # doctest: +SKIP
        [...]
        """
        results = list(self._checks)

        if framework:
            results = [c for c in results if framework in c.get("frameworks", {})]

        if control_id:
            filtered = []
            for check in results:
                frameworks = check.get("frameworks", {})
                for fw_key, fw_data in frameworks.items():
                    if framework and fw_key != framework:
                        continue
                    cid = fw_data.get("controlId", "") if isinstance(fw_data, dict) else ""
                    if control_id in cid:
                        filtered.append(check)
                        break
            results = filtered

        if keyword:
            kw_lower = keyword.lower()
            results = [c for c in results if kw_lower in c.get("name", "").lower()]

        return results

    # ------------------------------------------------------------------
    # Coverage analytics
    # ------------------------------------------------------------------

    def framework_coverage(self) -> List[Dict[str, Any]]:
        """
        Return per-framework coverage statistics, excluding superseded entries.

        Superseded ``MANUAL-CIS-*`` entries are excluded so that counts reflect
        the active, non-duplicate check population.

        Returns
        -------
        List of dicts sorted by ``framework_key``, each containing:

        - ``framework_key`` — registry key (e.g. ``"nist-800-53"``)
        - ``check_count``   — total active checks mapped to this framework
        - ``automated_count`` — checks with ``hasAutomatedCheck == True``
        - ``manual_count``  — checks with ``hasAutomatedCheck != True``

        Example
        -------
        >>> reg = CheckIDRegistry()
        >>> cov = reg.framework_coverage()
        >>> next(c for c in cov if c["framework_key"] == "hipaa")["check_count"]
        152
        """
        active = [c for c in self._checks if "supersededBy" not in c]

        # Collect all framework keys
        all_frameworks: set[str] = set()
        for check in active:
            all_frameworks.update(check.get("frameworks", {}).keys())

        results = []
        for fw in sorted(all_frameworks):
            mapped = [c for c in active if fw in c.get("frameworks", {})]
            results.append(
                {
                    "framework_key": fw,
                    "check_count": len(mapped),
                    "automated_count": sum(
                        1 for c in mapped if c.get("hasAutomatedCheck") is True
                    ),
                    "manual_count": sum(
                        1 for c in mapped if c.get("hasAutomatedCheck") is not True
                    ),
                }
            )
        return results

    # ------------------------------------------------------------------
    # Iteration
    # ------------------------------------------------------------------

    def __iter__(self) -> Iterator[Dict[str, Any]]:
        return iter(self._checks)

    def __len__(self) -> int:
        return len(self._checks)

    def __repr__(self) -> str:
        return (
            f"CheckIDRegistry(schema={self._schema_version!r}, "
            f"data={self._data_version!r}, checks={len(self._checks)})"
        )
