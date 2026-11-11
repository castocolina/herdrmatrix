#!/bin/sh
# Maintainer tool: exports your local Herdr copy (~/.config/herdr-app) into this repo.
# It copies files and retakes preview.png. It does not install anything and does not stage files.
# To retake preview.png it switches the live Herdr layout to phosphor-rain.
# Run it from anywhere inside the repo: scripts/export-from-herdr.sh
set -e

HOME_HERDR="$HOME/.config/herdr-app"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Repo root: wherever this script lives
DEST="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "This script must live inside the repo folder (cloned with git)."; exit 1; }
OUT="$DEST/phosphor-rain"
echo "Repo: $DEST"

# RECIPE.md and programs.json: look in the repo root, in phosphor-rain/, or in OUT
for f in RECIPE.md programs.json; do
  for src in "$DEST/$f" "$OUT/$f"; do
    if [ -f "$src" ]; then
      [ "$src" -ef "$OUT/$f" ] || { mkdir -p "$OUT"; cp "$src" "$OUT/$f"; }
      break
    fi
  done
done
[ -f "$OUT/RECIPE.md" ] || { echo "Missing RECIPE.md"; exit 1; }

mkdir -p "$OUT/layouts" "$OUT/themes" "$OUT/mods"

# Layout, preview, theme and mods
cp "$HOME_HERDR/layouts/phosphor-rain.json" "$OUT/layouts/"
[ -f "$HOME_HERDR/layouts/phosphor-rain.svg" ] && cp "$HOME_HERDR/layouts/phosphor-rain.svg" "$OUT/layouts/"
cp "$HOME_HERDR/themes/phosphor-rain.json" "$OUT/themes/"
rsync -a --delete --exclude '.DS_Store' --exclude '*.error' --exclude 'jsconfig.json' --exclude '*.d.ts' \
  "$HOME_HERDR/mods/phosphor-rain" "$HOME_HERDR/mods/phosphor-tabs" "$OUT/mods/"

# Real screenshot as preview.png
herdr-app 'do' layout.switch '{"name":"phosphor-rain"}' >/dev/null
sleep 1
herdr-app shot "$OUT/preview.png" >/dev/null && echo "preview.png saved"

# Validation
herdr-app check "$OUT/mods/phosphor-rain"
herdr-app check "$OUT/mods/phosphor-tabs"

echo
cd "$DEST"
git status --short
echo
echo "Review with git diff, then commit what you want."
