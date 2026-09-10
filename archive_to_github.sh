#!/usr/bin/env bash
set -euo pipefail

# Project Gutenberg all-text archive -> GitHub-safe shards.
# Each shard is <= 90 MiB, below GitHub's 100 MB Git object hard limit.
# Default repo payload target is 8 GiB, leaving headroom below the 10 GB
# recommended on-disk repository size. Pushes happen every 10 shards (~900 MiB),
# below GitHub's 2 GiB push limit.

SOURCE_URL="${SOURCE_URL:-https://www.gutenberg.org/cache/epub/feeds/txt-files.tar.zip}"
CHUNK_MIB="${CHUNK_MIB:-90}"
TARGET_GIB="${TARGET_GIB:-8}"
PUSH_EVERY="${PUSH_EVERY:-10}"
START_OFFSET="${START_OFFSET:-0}"
OUT_DIR="${OUT_DIR:-archive_parts}"
STATE_FILE="${STATE_FILE:-continuation-state.json}"
MANIFEST="${MANIFEST:-archive-manifest.tsv}"

CHUNK_BYTES=$((CHUNK_MIB * 1024 * 1024))
TARGET_BYTES=$((TARGET_GIB * 1024 * 1024 * 1024))

command -v curl >/dev/null 2>&1 || { echo 'curl is required'; exit 1; }
command -v git >/dev/null 2>&1 || { echo 'git is required'; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo 'sha256sum is required'; exit 1; }

mkdir -p "$OUT_DIR"

# Resume from state when available unless START_OFFSET was explicitly supplied.
if [[ -f "$STATE_FILE" && "${START_OFFSET}" == "0" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    saved=$(python3 - <<'PY'
import json
try:
    with open('continuation-state.json', encoding='utf-8') as f:
        print(int(json.load(f).get('next_offset', 0)))
except Exception:
    print(0)
PY
)
    if [[ "$saved" =~ ^[0-9]+$ ]] && (( saved > 0 )); then
      START_OFFSET="$saved"
    fi
  fi
fi

printf 'source_url\tpart\tstart_byte\tend_byte\tbytes\tsha256\tfilename\n' > "$MANIFEST".new
if [[ -f "$MANIFEST" ]]; then
  tail -n +2 "$MANIFEST" >> "$MANIFEST".new || true
fi
mv "$MANIFEST".new "$MANIFEST"

repo_added=0
offset="$START_OFFSET"
part=1

# Continue numbering after existing local parts.
last=$(find "$OUT_DIR" -maxdepth 1 -type f -name 'pg-all-text-*.part' -printf '%f\n' 2>/dev/null | sort | tail -n1 || true)
if [[ -n "$last" ]]; then
  n=$(echo "$last" | sed -E 's/.*-([0-9]{5})\.part/\1/' | sed 's/^0*//')
  [[ -n "$n" ]] && part=$((n + 1))
fi

while (( repo_added + CHUNK_BYTES <= TARGET_BYTES )); do
  start="$offset"
  end=$((start + CHUNK_BYTES - 1))
  filename=$(printf '%s/pg-all-text-%05d.part' "$OUT_DIR" "$part")
  tmp="${filename}.download"

  echo "Downloading bytes ${start}-${end} -> ${filename}"
  curl -L --fail --retry 5 --retry-delay 5 --connect-timeout 30 \
    --range "${start}-${end}" "$SOURCE_URL" -o "$tmp"

  actual=$(wc -c < "$tmp" | tr -d ' ')

  # A short final chunk means EOF. A larger-than-requested response means the
  # origin ignored Range; abort to avoid accidentally committing an 11GB file.
  if (( actual > CHUNK_BYTES )); then
    rm -f "$tmp"
    echo "ERROR: server ignored byte-range request (received $actual bytes)."
    exit 3
  fi
  if (( actual == 0 )); then
    rm -f "$tmp"
    echo "No more bytes returned; archive appears complete."
    break
  fi

  mv "$tmp" "$filename"
  sha=$(sha256sum "$filename" | awk '{print $1}')
  real_end=$((start + actual - 1))
  printf '%s\t%05d\t%s\t%s\t%s\t%s\t%s\n' \
    "$SOURCE_URL" "$part" "$start" "$real_end" "$actual" "$sha" "$filename" >> "$MANIFEST"

  offset=$((real_end + 1))
  repo_added=$((repo_added + actual))

  cat > "$STATE_FILE" <<EOF
{
  "source_url": "$SOURCE_URL",
  "first_offset_in_this_repo": $START_OFFSET,
  "next_offset": $offset,
  "chunk_mib": $CHUNK_MIB,
  "target_gib": $TARGET_GIB,
  "last_local_part": $part,
  "bytes_stored_this_run": $repo_added
}
EOF

  git add "$filename" "$MANIFEST" "$STATE_FILE"

  if (( part % PUSH_EVERY == 0 )); then
    git commit -m "Add Gutenberg text archive shards through part $(printf '%05d' "$part")" || true
    git push
  fi

  # EOF if final segment is shorter than requested.
  if (( actual < CHUNK_BYTES )); then
    echo "Reached end of Gutenberg archive."
    break
  fi

  part=$((part + 1))
done

git add "$MANIFEST" "$STATE_FILE" "$OUT_DIR" || true
git commit -m "Checkpoint Gutenberg archive at byte $offset" || true
git push

echo
echo "Repository shard load complete."
echo "Bytes added in this run: $repo_added"
echo "Next repository START_OFFSET: $offset"
echo "Copy $STATE_FILE and $MANIFEST to the next repository to continue."
