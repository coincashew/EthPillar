"""
Client version requirements for Ethereum networks.

This module defines minimum client versions required for specific fork activations
and provides validation utilities to ensure compatibility.

Networks requiring Fusaka fork (PeerDAS support):
- Ephemery: Activates Fusaka at epoch 10 (resets every 28 days)
- Hoodi: Fusaka active since epoch 50688
"""

# Minimum client versions for Fusaka fork (PeerDAS support)
# Required for: Ephemery (active at epoch 10), Hoodi (active since epoch 50688)
FUSAKA_MIN_VERSIONS = {
    # Consensus clients
    'lighthouse': 'v8.0.0',
    'teku': '25.9.3',
    'nimbus': 'v25.9.2',
    'lodestar': 'v1.35.0',
    'prysm': 'v6.1.0',
    # Execution clients
    'reth': 'v1.7.0',
    'besu': '25.7.0',
    'nethermind': 'v1.34.0'
}


def parse_version(version_string):
    """
    Pure function: Parse semantic version string into comparable parts.

    Args:
        version_string: Version string (e.g., 'v8.0.0', '25.9.3-rc.0')

    Returns:
        Tuple of (major, minor, patch, prerelease)

    Examples:
        >>> parse_version('v8.0.0')
        (8, 0, 0, None)
        >>> parse_version('25.9.3-rc.0')
        (25, 9, 3, 'rc.0')
    """
    clean_version = version_string.lstrip('v')
    parts = clean_version.split('-')
    version_nums = parts[0].split('.')

    nums = [int(n) if n.isdigit() else 0 for n in version_nums]
    nums.extend([0] * (3 - len(nums)))  # Pad to 3 elements

    prerelease = parts[1] if len(parts) > 1 else None
    return (*nums[:3], prerelease)


def compare_versions(v1, v2):
    """
    Pure function: Compare two semantic version strings.

    Args:
        v1: First version string
        v2: Second version string

    Returns:
        -1 if v1 < v2, 0 if equal, 1 if v1 > v2

    Examples:
        >>> compare_versions('v8.0.0', 'v7.1.0')
        1
        >>> compare_versions('v8.0.0-rc.0', 'v8.0.0')
        -1
    """
    v1_parts = parse_version(v1)
    v2_parts = parse_version(v2)

    # Compare major, minor, patch
    for a, b in zip(v1_parts[:3], v2_parts[:3]):
        if a < b: return -1
        if a > b: return 1

    # Compare prerelease (no prerelease > has prerelease)
    v1_pre, v2_pre = v1_parts[3], v2_parts[3]
    if v1_pre is None and v2_pre is not None: return 1
    if v1_pre is not None and v2_pre is None: return -1
    if v1_pre == v2_pre: return 0
    return -1 if v1_pre < v2_pre else 1


def validate_version_for_network(client_name, version, network):
    """
    Pure function: Validate if version meets network requirements.

    Args:
        client_name: Name of the client (e.g., 'lighthouse', 'reth')
        version: Version string to validate
        network: Network name (e.g., 'ephemery', 'hoodi', 'mainnet')

    Returns:
        Tuple of (is_valid: bool, error_message: str | None)

    Networks requiring Fusaka (PeerDAS):
    - Ephemery: Active at epoch 10 (resets every 28 days)
    - Hoodi: Active since epoch 50688

    Examples:
        >>> validate_version_for_network('lighthouse', 'v8.0.0', 'ephemery')
        (True, None)
        >>> validate_version_for_network('lighthouse', 'v7.1.0', 'ephemery')
        (False, 'ERROR: ...')
        >>> validate_version_for_network('lighthouse', 'v7.1.0', 'mainnet')
        (True, None)  # Mainnet doesn't require Fusaka yet
    """
    # Only validate for networks running Fusaka fork
    if network not in ["ephemery", "hoodi"]:
        return (True, None)

    min_version = FUSAKA_MIN_VERSIONS.get(client_name)
    if not min_version:
        return (True, None)

    if compare_versions(version, min_version) >= 0:
        return (True, None)

    error_msg = (
        f"\nERROR: {client_name.capitalize()} {version} is not compatible with {network.capitalize()}\n"
        f"{network.capitalize()} requires Fusaka fork support (minimum version: {min_version})\n"
        f"The latest {client_name.capitalize()} release ({version}) does not meet this requirement.\n"
        f"\nPlease wait for a newer {client_name.capitalize()} release or choose a different network."
    )
    return (False, error_msg)
