#!/bin/sh
# Default command of the front-end content image: replace the contents of the
# target directory (default /out, or $TARGET_DIR) with the built files in /dist.
# Meant for a one-shot compose service with a named volume mounted at /out; the
# web server mounts the same volume read-only. Emptying first means an upgrade
# leaves no stale files behind.
set -eu
target="${TARGET_DIR:-/out}"
case "$target" in
  /|/dist|/dist/*|/licenses|"") echo "copy-dist: refusing target '$target'" >&2; exit 1 ;;
esac
if [ ! -d "$target" ]; then
  echo "copy-dist: $target does not exist; mount a volume there" >&2
  exit 1
fi
find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -R /dist/. "$target"/
echo "copy-dist: $(find "$target" -type f | wc -l) files copied to $target"
