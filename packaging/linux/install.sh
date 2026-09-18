#!/bin/sh
# Inventory Management — tek komutluk Linux kurulumu.
# Kullanim: tarball icinden cikarip `./install.sh` calistirin.
# Yaptiklari:
#   1. Uygulamayi ~/.local/share/inventory-management altina kopyalar.
#   2. Baslatici (.desktop) kaydini ~/.local/share/applications altina yazar
#      (Exec yolu kurulu dizine gore duzeltilir) — boylece Alt+Space /
#      uygulama menusu aramasinda "Inventory Management" bulunur.
#   3. Ikonlari hicolor temasina kurar.
# Sistem geneli kurulum yapmaz, sudo istemez.
set -e

SRC="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DEST="$HOME/.local/share/inventory-management"

mkdir -p "$DEST"
cp -r "$SRC/app/." "$DEST/"
chmod +x "$DEST/inventory_management"

mkdir -p "$HOME/.local/share/applications"
sed "s|^Exec=.*|Exec=$DEST/inventory_management|" \
  "$SRC/inventory-management.desktop" \
  > "$HOME/.local/share/applications/inventory-management.desktop"

for s in 128 64 48 32; do
  d="$HOME/.local/share/icons/hicolor/${s}x${s}/apps"
  mkdir -p "$d"
  cp "$SRC/icons/$s.png" "$d/inventory-management.png"
done

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$HOME/.local/share/applications" || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" || true
fi

echo "Kuruldu: $DEST"
echo "Baslatmak icin: Alt+Space (veya menude ara) -> Inventory Management"
