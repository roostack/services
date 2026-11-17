#!/usr/bin/env bash
# Says whether a package version needs the lab's own sign-in (sso:
# required: true, as Outline does): it has no sign-in of its own, so
# Roostack installs it only on a lab with an address. Exits 0 when it does,
# 1 when it doesn't. The update test's lab gets a test address
# (`roostack test-address`), but a Roostack from before that command can't
# give it one: drive.py then asks this, and such an update isn't tested and
# never merges by itself (.github/workflows/update-test.yml).
#
#   .github/update-test/needs-address.sh <package> <version>
set -euo pipefail
pkg=${1:?package} version=${2:?version}
awk '/^sso:/ { s = 1; next } /^[^ #]/ { s = 0 } s && /^  required: *true *$/ { found = 1 } END { exit !found }' \
	"packages/$pkg/$version.yaml"
