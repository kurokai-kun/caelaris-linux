#!/usr/bin/env bash
set -euo pipefail

# Caelaris Custom Package Repository Generator
# Builds and signs the [Caelaris] pacman database

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pkgs"
DB_NAME="Caelaris"

mkdir -p "$REPO_DIR"

echo "=========================================================="
echo " Building Caelaris Repository: ${DB_NAME}                   "
echo " Directory: ${REPO_DIR}                                   "
echo "=========================================================="

cd "$REPO_DIR"

PKG_COUNT=$(find . -name "*.pkg.tar.zst" | wc -l)
if [[ "$PKG_COUNT" -eq 0 ]]; then
    echo "No .pkg.tar.zst packages found in $REPO_DIR yet."
    echo "Place built packages here and re-run this script to update the repository database."
    exit 0
fi

echo "Adding ${PKG_COUNT} packages to ${DB_NAME}.db.tar.zst..."
repo-add -n -R "${DB_NAME}.db.tar.zst" *.pkg.tar.zst

echo "Repository successfully updated!"
echo "You can host this directory with Nginx, GitHub Pages, or any web server."
