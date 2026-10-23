#!/usr/bin/env bash
# Makes a bill of materials for each image of each package's newest
# version that hasn't one yet (Roostack's docs/REGISTRY-WATCH.md): Syft's
# findings, cut down to each library's name, version, type and package
# URL, as boms/<package>/<version>/<image>.json. The watcher asks OSV
# about those exact versions, and roostack registry bom-check compares
# them with each package's built_with. Images are scanned for
# linux/amd64; their arm64 builds hold the same libraries.
#
#   .github/scan-boms.sh ROOSTACK SYFT
#
# ROOSTACK and SYFT are the binaries. Run from the repository's root.
# Prints each package version it scanned (ntfy@2.31.1-roostack.2), one a
# line, for roostack registry bom-check -only.
set -euo pipefail

roostack=$1
syft=$2
version=$("$syft" version -o json | jq -r .version)

summary=${GITHUB_STEP_SUMMARY:-/dev/stderr}

"$roostack" registry images -repo . -missing -newest | while read -r pkg ver image file; do
    echo "Scanning $image ($pkg $ver)" >&2
    mkdir -p "$(dirname "$file")"
    # One image that can't be scanned (its registry down, or the pinned
    # image gone) doesn't stop the rest: it's said, and the next run tries
    # it again.
    if ! "$syft" scan -q --platform linux/amd64 "registry:$image" -o syft-json > "$file.syft" ||
        ! jq -c --arg image "$image" --arg syft "$version" \
            '{image: $image, syft: $syft, artifacts: ([.artifacts[] | {name, version, type, purl}] | sort_by(.purl))}' "$file.syft" > "$file.tmp"; then
        echo "- **$pkg $ver**: Syft couldn't scan \`$image\`; check the image can still be pulled." >> "$summary"
        rm -f "$file.syft" "$file.tmp"
        continue
    fi
    rm "$file.syft"
    mv "$file.tmp" "$file"
    echo "$pkg@$ver"
done | sort -u
