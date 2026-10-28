#!/usr/bin/env bash
# Puts Syft, the bill-of-materials tool, in ./syft-bin: a pinned release,
# checked by its SHA-256 so a changed download fails the run. Syft runs
# only in this repository's CI, never on labs (Roostack's
# docs/RED-BUTTON-PLAN.md §4.1, question 10). To move to a newer release,
# change both lines below from the release's syft_<version>_checksums.txt.
#
#   .github/get-syft.sh
set -euo pipefail

version=1.54.1
sha256=c069905b391cc4c20a5ba65ad5c10be2a7ba074f8ea6ad203e24d14e303dad47 # syft_1.54.1_linux_amd64.tar.gz

curl -fsSL --retry 3 -o syft.tgz "https://github.com/anchore/syft/releases/download/v$version/syft_${version}_linux_amd64.tar.gz"
echo "$sha256  syft.tgz" | sha256sum -c -
tar xzf syft.tgz syft
mv syft syft-bin
rm syft.tgz
./syft-bin version | head -2
