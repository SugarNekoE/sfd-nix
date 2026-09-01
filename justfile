set shell := ["bash", "-euo", "pipefail", "-c"]

export CACHIX_CACHE_NAME := env("CACHIX_CACHE_NAME", "sfd-nix")

# List available recipes.
default:
    @just --list

# Format the Nix sources.
format:
    nix fmt --accept-flake-config

# Build the desktop client and create ./result.
build:
    nix build --accept-flake-config .#sing-box-for-desktop

# Run the desktop client.
run:
    nix run --accept-flake-config .

# Build all checks for the native system.
check:
    nix flake check --accept-flake-config

# Evaluate every supported system without cross-building.
check-all:
    nix flake check --accept-flake-config --all-systems --no-build

# Diagnose local Cachix and Nix configuration.
cache-doctor:
    cachix doctor --cache "$CACHIX_CACHE_NAME"

# Check, build, and upload the release outputs to Cachix.
cache-push: check
    nix build --accept-flake-config --no-link --print-out-paths \
        .#sing-box-for-desktop .#sing-box-daemon \
        | cachix push "$CACHIX_CACHE_NAME"
