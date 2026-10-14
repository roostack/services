#!/usr/bin/env bash
# Shows reviewers what each package a pull request adds or changes would
# generate (Roostack's SPEC.md §8.3.7): the package rendered with its
# default settings in an example lab (`roostack render -package`), and the
# difference from the previous version of the same package, if there is
# one. Written to the run's summary; nothing is committed.
#
#   .github/render-changes.sh ROOSTACK BASE-REF
#
# ROOSTACK is the roostack binary; BASE-REF is what the pull request
# merges into (origin/main). Run from the repository's root. Writes to
# $GITHUB_STEP_SUMMARY (standard output when unset).
set -euo pipefail

roostack=$1
base=$2
summary=${GITHUB_STEP_SUMMARY:-/dev/stdout}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Package files the pull request adds or changes (not registry.yaml).
mapfile -t changed < <(git diff --name-only --diff-filter=AM "$base"...HEAD -- 'packages/*/*.yaml' |
    grep -v '/registry\.yaml$' || true)

{
    echo "## What the changed packages generate"
    echo
    if [[ ${#changed[@]} -eq 0 ]]; then
        echo "No package files changed."
    fi
} >>"$summary"

for file in "${changed[@]}"; do
    dir=$(dirname "$file")
    version=$(basename "$file" .yaml)
    out=$tmp/$(basename "$dir")-$version.txt
    if ! "$roostack" render -package "$file" >"$out" 2>"$out.err"; then
        { echo "### \`$file\`"; echo; echo "Couldn't render it:"; echo '```'; cat "$out.err"; echo '```'; } >>"$summary"
        exit 1
    fi
    # The previous version: the newest other file in the folder that
    # sorts before this one.
    previous=$(find "$dir" -maxdepth 1 -name '*.yaml' ! -name registry.yaml ! -name "$version.yaml" -printf '%f\n' |
        sed 's/\.yaml$//' | { cat; echo "$version"; } | sort -V | grep -B1 -x -F "$version" | grep -v -x -F "$version" || true)
    {
        echo "### \`$file\`"
        echo
        if [[ -n $previous ]]; then
            "$roostack" render -package "$dir/$previous.yaml" >"$tmp/previous.txt" 2>/dev/null || echo "(couldn't render $previous)" >"$tmp/previous.txt"
            if diff -q "$tmp/previous.txt" "$out" >/dev/null; then
                echo "Generates the same files as $previous."
            else
                echo "<details open><summary>Changes from $previous</summary>"
                echo
                echo '```diff'
                diff -u --label "$previous" --label "$version" "$tmp/previous.txt" "$out" || true
                echo '```'
                echo "</details>"
            fi
            echo
        else
            echo "A new package."
            echo
        fi
        echo "<details><summary>Everything it generates</summary>"
        echo
        echo '```'
        cat "$out"
        echo '```'
        echo "</details>"
        echo
    } >>"$summary"
done
