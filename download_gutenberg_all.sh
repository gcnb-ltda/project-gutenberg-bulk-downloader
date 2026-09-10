#!/usr/bin/env bash
set -euo pipefail

DEST="${1:-$HOME/ProjectGutenberg}"
MODE="${2:-full}"

mkdir -p "$DEST"

if ! command -v rsync >/dev/null 2>&1; then
  echo "Erro: rsync não encontrado."
  echo "Debian/Ubuntu: sudo apt install rsync"
  echo "macOS (Homebrew): brew install rsync"
  exit 1
fi

sync_one () {
  local module="$1"
  local target="$2"
  mkdir -p "$target"

  echo "Sincronizando $module -> $target"
  if ! rsync -avHS --partial --info=progress2 --timeout=600 --delete \
      "gutenberg.pglaf.org::$module" "$target"; then
    echo "Servidor principal indisponível; tentando ibiblio..."
    rsync -avHS --partial --info=progress2 --timeout=600 --delete \
      "rsync.ibiblio.org::$module" "$target"
  fi
}

case "$MODE" in
  full)
    sync_one "gutenberg" "$DEST/main"
    sync_one "gutenberg-epub" "$DEST/generated"
    ;;
  generated)
    sync_one "gutenberg-epub" "$DEST/generated"
    ;;
  main)
    sync_one "gutenberg" "$DEST/main"
    ;;
  *)
    echo "Uso: $0 [DESTINO] [full|generated|main]"
    exit 2
    ;;
esac

echo
echo "Concluído."
echo "Destino: $DEST"
