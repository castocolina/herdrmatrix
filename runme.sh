#!/bin/sh
# Actualiza el repo con Phosphor Rain desde ~/.config/herdr-app.
# Ponlo en la raíz del repo o dentro de phosphor-rain/ y ejecútalo: ./runme.sh
set -e

HOME_HERDR="$HOME/.config/herdr-app"
HERE="$(cd "$(dirname "$0")" && pwd)"

# Raíz del repo: donde esté este script
DEST="$(git -C "$HERE" rev-parse --show-toplevel 2>/dev/null)" || {
  echo "Este script tiene que estar dentro de la carpeta del repo (clonado con git)."; exit 1; }
OUT="$DEST/phosphor-rain"
echo "Repo: $DEST"

# RECIPE.md y programs.json: busca junto al script o en phosphor-rain/
for f in RECIPE.md programs.json; do
  for src in "$HERE/$f" "$HERE/phosphor-rain/$f" "$OUT/$f"; do
    if [ -f "$src" ]; then
      [ "$src" -ef "$OUT/$f" ] || { mkdir -p "$OUT"; cp "$src" "$OUT/$f"; }
      break
    fi
  done
done
[ -f "$OUT/RECIPE.md" ] || { echo "Falta RECIPE.md"; exit 1; }

mkdir -p "$OUT/layouts" "$OUT/themes" "$OUT/mods"

# Layout, preview, tema y mods
cp "$HOME_HERDR/layouts/phosphor-rain.json" "$OUT/layouts/"
[ -f "$HOME_HERDR/layouts/phosphor-rain.svg" ] && cp "$HOME_HERDR/layouts/phosphor-rain.svg" "$OUT/layouts/"
cp "$HOME_HERDR/themes/phosphor-rain.json" "$OUT/themes/"
rsync -a --delete --exclude '.DS_Store' --exclude '*.error' --exclude 'jsconfig.json' --exclude '*.d.ts' \
  "$HOME_HERDR/mods/phosphor-rain" "$HOME_HERDR/mods/phosphor-tabs" "$OUT/mods/"

# Captura real como preview.png
herdr-app do layout.switch '{"name":"phosphor-rain"}' >/dev/null
sleep 1
herdr-app shot "$OUT/preview.png" >/dev/null && echo "preview.png guardado"

# README en la raíz (solo si no existe)
if [ ! -f "$DEST/README.md" ]; then
cat > "$DEST/README.md" <<'EOF'
# Phosphor Rain for Herdr

A green-phosphor neon layout for [Herdr](https://herdr.dev) with digital rain, position-based tab avatars and a rain wallpaper.

![Phosphor Rain](phosphor-rain/preview.png)

## Install

Ask your agent:

```
Read ~/.config/herdr-app/AGENTS.md, then add this layout: https://github.com/gara501/herdrmatrix/tree/main/phosphor-rain
```

Or by hand: copy `layouts/`, `themes/` and `mods/` from `phosphor-rain/` into `~/.config/herdr-app/`, then switch with `ctrl-shift-l`.

See [`phosphor-rain/RECIPE.md`](phosphor-rain/RECIPE.md) for details.
EOF
fi

# Validación
herdr-app check "$OUT/mods/phosphor-rain"
herdr-app check "$OUT/mods/phosphor-tabs"

cd "$DEST"
git add -A
echo
git status --short
echo
echo "Si los cambios están bien:"
echo "  git commit -m 'Update Phosphor Rain' && git push"
