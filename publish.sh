#!/bin/bash
# publish.sh: copy the estate's built project page into this repository and push it to aic-dc.net.
# Run only on Em's word. Usage:  ./publish.sh            (shows diff, asks before commit+push)
#                                ./publish.sh --dry-run  (copies + shows diff, commits nothing)
#
# The list of record is DC-Site/site-manifest.txt (rewritten by every `build.py --release`).
# Exactly the files it names are copied, byte for byte, and each is checked against the
# manifest's SHA-256 and size; one mismatch and nothing is copied. preview-* folders,
# host-check.py, host-baseline.json and the build are never published.
#
# A file published here but no longer in the manifest is removed; the removal is shown in the
# diff before you answer. Refuses unless the manifest names index.html, CNAME and .nojekyll.
set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
SITE="${DCSITE_SITE:-$REPO/../DC-Site/site}"
MANIFEST="${DCSITE_MANIFEST:-$REPO/../DC-Site/site-manifest.txt}"
KEEP="publish.sh README.md .gitignore"   # repo-only files, not part of the site
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

[ -d "$SITE" ] || { echo "no site folder at $SITE" >&2; exit 1; }
[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 1; }
cd "$REPO"
git diff --quiet && git diff --cached --quiet || { echo "repository has uncommitted changes; stop" >&2; exit 1; }
git pull -q --ff-only origin main

want=$(awk '{p=$3; sub(/^\.\//,"",p); print p}' "$MANIFEST" | sort)
for need in index.html CNAME .nojekyll; do
  grep -qxF -- "$need" <<<"$want" || { echo "REFUSED: manifest does not name $need" >&2; exit 2; }
done

# 1. Verify every manifest file first; copy nothing unless all match.
while read -r sha size path; do
  p="${path#./}"; src="$SITE/$p"
  [ -f "$src" ] || { echo "manifest names $p but $src is absent" >&2; exit 3; }
  got_sha=$(shasum -a 256 "$src" | cut -d' ' -f1); got_size=$(stat -f%z "$src")
  [ "$got_sha" = "$sha" ] && [ "$got_size" = "$size" ] || {
    echo "REFUSED: $p in site/ does not match the manifest (rebuilt since?). sha $got_sha size $got_size" >&2; exit 4; }
done < "$MANIFEST"

# 2. Remove published files the manifest no longer names (shown in the diff below).
while IFS= read -r p; do
  case " $KEEP " in *" $p "*) continue;; esac
  grep -qxF -- "$p" <<<"$want" || { echo "removing (not in manifest): $p"; git rm -q -- "$p"; }
done < <(git ls-files)

# 3. Copy, byte for byte.
while read -r sha size path; do
  p="${path#./}"; mkdir -p "$(dirname "$p")"; cp -p "$SITE/$p" "$p"
done < "$MANIFEST"

# 4. Mention anything in site/ the manifest leaves out (not published).
( cd "$SITE" && find . -type f ! -name .DS_Store | sed 's#^\./##' | sort ) \
  | comm -23 - <(echo "$want") | sed 's/^/note: in site\/ but not in manifest, not published: /'

git add -A -- $(echo "$want")
echo "---- changes ----"; git diff --cached --stat
if git diff --cached --quiet; then echo "nothing to publish"; exit 0; fi
undo(){ git reset -q --hard HEAD; git clean -fq -- $(echo "$want"); }  # tree was clean at start (checked above)
[ $DRY -eq 1 ] && { undo; echo "(dry run: nothing committed, tree restored)"; exit 0; }
read -r -p "Commit and push these to aic-dc.net? [y/N] " ok
[ "$ok" = y ] || { undo; echo "not published, tree restored"; exit 0; }
git commit -q -m "Publish aic-dc.net ($(date -u +%Y-%m-%dT%H:%MZ))"
git push -q origin main
git log -1 --oneline
