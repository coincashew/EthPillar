#!/usr/bin/env bash
# Helpers to run docker commands in rootful or rootless environments.
set -euo pipefail

# Determine docker command prefix and whether sudo is required.
# Exported variables:
#  DOCKER_CMD - full docker command (e.g. "docker" or "sudo docker")
#  DOCKER_COMPOSE_CMD - compose subcommand invocation (e.g. "docker compose" or "docker compose")

_detect_docker_mode() {
  # If docker command exists
  if ! command -v docker >/dev/null 2>&1; then
    return 1
  fi

  # Try docker info Rootless field first
  if docker info --format '{{.Rootless}}' >/dev/null 2>&1; then
    rootless=$(docker info --format '{{.Rootless}}' 2>/dev/null || echo "false")
    if [[ "$rootless" == "true" ]]; then
      DOCKER_CMD="docker"
      DOCKER_COMPOSE_CMD="docker compose"
      return 0
    fi
  fi

  # If systemctl docker is active, assume rootful daemon and require sudo for non-root users
  if systemctl is-active --quiet docker 2>/dev/null; then
    if [[ $(id -u) -ne 0 ]]; then
      DOCKER_CMD="sudo docker"
      DOCKER_COMPOSE_CMD="sudo docker compose"
    else
      DOCKER_CMD="docker"
      DOCKER_COMPOSE_CMD="docker compose"
    fi
    return 0
  fi

  # Fallback: if dockerd-rootless is running (systemd --user), assume rootless
  if pgrep -f dockerd-rootless >/dev/null 2>&1; then
    DOCKER_CMD="docker"
    DOCKER_COMPOSE_CMD="docker compose"
    return 0
  fi

  # Default to sudo docker for safety
  if [[ $(id -u) -ne 0 ]]; then
    DOCKER_CMD="sudo docker"
    DOCKER_COMPOSE_CMD="sudo docker compose"
  else
    DOCKER_CMD="docker"
    DOCKER_COMPOSE_CMD="docker compose"
  fi
  return 0
}

_detect_docker_mode

export DOCKER_CMD
export DOCKER_COMPOSE_CMD

run_docker() { # run_docker <args...>
  eval "$DOCKER_CMD" "$@"
}

run_compose() { # run_compose <compose-args...>
  eval "$DOCKER_COMPOSE_CMD" "$@"
}

# Verify docker mode and ethpillar_default network reachability.
_docker_verify_network() {
  echo "🔎 Docker detection: checking mode and network 'ethpillar_default'..."

  # Determine rootless vs system using docker info, fallback to pgrep checks
  local mode="unknown"
  if ${DOCKER_CMD} info --format '{{.Rootless}}' >/dev/null 2>&1; then
    local rl=$(${DOCKER_CMD} info --format '{{.Rootless}}' 2>/dev/null || echo "false")
    if [[ "$rl" == "true" ]]; then
      mode="rootless"
    else
      mode="system"
    fi
  else
    if pgrep -f dockerd-rootless >/dev/null 2>&1; then
      mode="rootless"
    else
      mode="system"
    fi
  fi

  echo "  - Docker mode: ${mode}"

  # Check network existence
  if ${DOCKER_CMD} network inspect ethpillar_default >/dev/null 2>&1; then
    echo "  - Network 'ethpillar_default': exists"
  else
    echo "  - Network 'ethpillar_default': NOT FOUND"
    echo "    You can create it with: ${DOCKER_CMD} network create ethpillar_default"
    return 0
  fi

  # Test reachability by running a short-lived container attached to the network.
  # Use alpine and immediately exit after ensuring it can be created on the network.
  local test_name="ethpillar_net_test_$$"
  if ${DOCKER_CMD} run --rm --network ethpillar_default --name ${test_name} alpine:3.18 true >/dev/null 2>&1; then
    echo "  - Network usability: OK (ephemeral container started on 'ethpillar_default')"
  else
    echo "  - Network usability: FAILED (could not start container on 'ethpillar_default')"
    echo "    If you're running rootless Docker, ensure your user has the required permissions and that the Docker rootless socket is available:"
    echo "      export DOCKER_HOST=unix://\$XDG_RUNTIME_DIR/docker.sock"
  fi
}

# Run verification when sourced interactively or by scripts to surface useful hints.
_docker_verify_network
