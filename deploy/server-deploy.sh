#!/usr/bin/env bash
# PetGuardian — server-side release switcher.
# Expects an uploaded build at /tmp/petguardian-next/ (publish.ps1 does this).
# Run ON THE SERVER:
#   bash server-deploy.sh
set -euo pipefail

APP=petguardian
WWW_ROOT=/var/www/$APP
STAGE=/tmp/petguardian-next
TS=$(date +%Y%m%d%H%M%S)

if [ ! -f "$STAGE/index.html" ]; then
  echo "ERROR: no staged build at $STAGE/index.html (run publish.ps1 first)" >&2
  exit 1
fi

echo "==> validating staged build"
# A truncated upload would otherwise go live; index.html is the entry point
# and main.dart.js must exist for the app to boot at all.
if ! ls "$STAGE"/main.dart.js >/dev/null 2>&1 && ! ls "$STAGE"/*.wasm >/dev/null 2>&1; then
  echo "ERROR: staged build has neither main.dart.js nor *.wasm — upload incomplete" >&2
  exit 1
fi

echo "==> releasing $TS"
mkdir -p "$WWW_ROOT/releases"
rsync -a --delete "$STAGE/" "$WWW_ROOT/releases/$TS/"
rm -rf "$STAGE"

PREV=$(readlink "$WWW_ROOT/current" || true)
echo "==> switching current -> releases/$TS (previous: ${PREV:-none})"
# If current/ is a real directory (legacy setup), ln -sfn would nest the new
# link inside it. Convert it to a symlink target first; refuse if unexpected
# content is in there rather than pointing nginx at the wrong tree.
if [ -e "$WWW_ROOT/current" ] && [ ! -L "$WWW_ROOT/current" ]; then
  rmdir "$WWW_ROOT/current" 2>/dev/null \
    || { echo "ERROR: $WWW_ROOT/current is a non-empty real directory" >&2; exit 1; }
fi
ln -sfn "$WWW_ROOT/releases/$TS" "$WWW_ROOT/current"

echo "==> nginx config test + reload"
sudo nginx -t && sudo systemctl reload nginx

# Keep the last 5 releases for rollback; older ones are pruned.
echo "==> pruning old releases (keeping 5)"
ls -1dt "$WWW_ROOT/releases"/*/ 2>/dev/null | tail -n +6 | xargs -r sudo rm -rf

echo "==> smoke check"
if curl -fsS -o /dev/null http://127.0.0.1/ ; then
  echo "OK: http://127.0.0.1/ returns 200"
else
  echo "FAILED: local curl did not return success" >&2
  exit 1
fi

if [ -n "$PREV" ] && [ -e "$PREV" ]; then
  echo "ROLLBACK: sudo ln -sfn $PREV $WWW_ROOT/current && sudo systemctl reload nginx"
fi
echo "DONE. New release: $WWW_ROOT/releases/$TS"
