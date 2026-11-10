#!/bin/sh
# Actualiza tu clon de herdrmatrix con Phosphor Rain desde ~/.config/herdr-app.
# Uso: sh empaquetar-phosphor-rain.sh [carpeta-del-clon]
set -e

HOME_HERDR="$HOME/.config/herdr-app"
DEST="${1:-$HOME/herdrmatrix}"
[ -d "$DEST/.git" ] || { echo "No encuentro el clon en $DEST. Primero: git clone https://github.com/gara501/herdrmatrix ~/herdrmatrix"; exit 1; }
OUT="$DEST/phosphor-rain"
HERE="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$OUT/layouts" "$OUT/themes" "$OUT/mods"

# Layout + preview, tema y mods
cp "$HOME_HERDR/layouts/phosphor-rain.json" "$OUT/layouts/"
[ -f "$HOME_HERDR/layouts/phosphor-rain.svg" ] && cp "$HOME_HERDR/layouts/phosphor-rain.svg" "$OUT/layouts/"
cp "$HOME_HERDR/themes/phosphor-rain.json" "$OUT/themes/"
rsync -a --exclude '.DS_Store' --exclude '*.error' --exclude 'jsconfig.json' --exclude '*.d.ts' \
  "$HOME_HERDR/mods/phosphor-rain" "$HOME_HERDR/mods/phosphor-tabs" "$OUT/mods/"

# programs.json opcional (solo las entradas del tema)
[ -f "$HERE/phosphor-rain/programs.json" ] && cp "$HERE/phosphor-rain/programs.json" "$OUT/"

# RECIPE.md: el que viene junto a este script
cp "$HERE/phosphor-rain/RECIPE.md" "$OUT/RECIPE.md"

# Captura real del layout como preview.png
herdr-app do layout.switch '{"name":"phosphor-rain"}' >/dev/null
sleep 1
herdr-app shot "$OUT/preview.png" >/dev/null && echo "preview.png guardado"

# README de la raíz del repo
cat > "$DEST/README.md" <<'EOF'
# Phosphor Rain for Herdr

A green-phosphor neon layout for [Herdr](https://herdr.dev) with digital rain, position-based tab avatars and a rain wallpaper.

![Phosphor Rain](phosphor-rain/preview.png)

## Install

Ask your agent:

```
Read ~/.config/herdr-app/AGENTS.md, then add this layout: https://github.com/gara501/herdrmatrix/tree/main/phosphor-rain
```

Or by hand: copy `layouts/`, `themes/` and `mods/` into `~/.config/herdr-app/`, then switch with `ctrl-shift-l`.

See [`phosphor-rain/RECIPE.md`](phosphor-rain/RECIPE.md) for details.
EOF

# Validación rápida
herdr-app check "$OUT/mods/phosphor-rain" && herdr-app check "$OUT/mods/phosphor-tabs"

cd "$DEST"
git add -A
git status --short
echo "Revisa los cambios de arriba. Si están bien:"
echo "  cd $DEST && git commit -m 'Update Phosphor Rain: tab images, panel, background' && git push"
