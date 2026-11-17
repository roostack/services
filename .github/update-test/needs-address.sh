#!/usr/bin/env bash
# Says whether a package version needs the lab's own sign-in (sso:
# required: true, as Outline does): it has no sign-in of its own, so
# Roostack installs it only on a lab with an address, which the update
# test's throwaway lab hasn't got. Exits 0 when it does, 1 when it
# doesn't. Such updates aren't tested and never merge by themselves
# (.github/workflows/update-test.yml) until the test's lab can have an
# address of its own (the maintainer, 2026-11-17).
#
#   .github/update-test/needs-address.sh <package> <version>
set -euo pipefail
pkg=${1:?package} version=${2:?version}
awk '/^sso:/ { s = 1; next } /^[^ #]/ { s = 0 } s && /^  required: *true *$/ { found = 1 } END { exit !found }' \
	"packages/$pkg/$version.yaml"
