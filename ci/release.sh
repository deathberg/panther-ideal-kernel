#!/usr/bin/env bash
# Create GitHub release with auto-incremented tag and upload built kernel zips
# usage: release.sh <variant>
set -e
VARIANT="$1"

T=$(gh api "repos/${GITHUB_REPOSITORY}/tags" --jq '.[0].name' 2>/dev/null || true)
if [ -z "$T" ] || [ "$T" = "null" ]; then
  T="v1.0.0-r0"
fi
NEW=$(echo "$T" | awk -F'-r' '{s=$2; if(!s) s=0; s++; printf "%s-r%d",$1,s}')
echo "New tag: $NEW"

git tag "$NEW"
git push origin "$NEW"

C=$(git ls-remote https://github.com/kerneltoast/android_kernel_google_tensynos HEAD | awk '{print $1}')

gh release create "$NEW" \
  --title "panther-ideal kernel $NEW" \
  --notes "Sultan gs201 A16 + KernelSU-Next (built-in) + SUSFS. Variant: $VARIANT. Sultan base @ $C. Flash only on firmware matching the current monthly patch level. Pair with: sidex15/ksu_module_susfs, TrickyStore + valid keybox.xml, PlayIntegrityFork, ReZygisk / ZygiskNext."

for f in ./dl/kernel-*/*.zip; do
  [ -f "$f" ] || continue
  n="${f%.*}-${NEW}.zip"
  mv "$f" "$n"
  gh release upload "$NEW" "$n"
  echo "uploaded: $n"
done
