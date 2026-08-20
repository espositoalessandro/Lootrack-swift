#!/bin/bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! command -v brew >/dev/null 2>&1; then
    echo "error: Homebrew is required to install Lootrack's development tools." >&2
    exit 1
fi

brew bundle --file="$repo_root/Brewfile"

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit Scripts/setup-dev-tools.sh

echo "Lootrack development tools are ready."
echo "Pre-commit formatting and linting are enabled for this clone."
