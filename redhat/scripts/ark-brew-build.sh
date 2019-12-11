#!/bin/bash
#
# Take an ARK release branch, import it into dist-git and build it in brew.
# This script expects to start on the release branch to import into dist-git.
#
# Arguments:
#   1) Optional; a local clone of the dist-git repository to use as a cache.

set -e

DISTGIT_CACHE=$1

# Assert we're on a release branch before proceeding.
git status | head -n1 | grep -E "On branch ark/v[0-9]\.[0-9]+(-rc[0-9]+)?"

TMPDIR=$(mktemp -d /tmp/ARK.XXXXXXXX)
trap 'echo "Cleaning up $TMPDIR" && rm -rf "$TMPDIR"' exit SIGTERM SIGINT

rm -f localversion
touch localversion
make RHDISTGIT_TMP="$TMPDIR" RHDISTGIT_CACHE="$DISTGIT_CACHE" rh-dist-git
pushd "$TMPDIR"/RHEL*/kernel
git commit -a -s -F ../changelog
rhpkg tag -F ../changelog
rhpkg push
git push origin "$(git describe --exact-match)"
rhpkg build --target temp-ark-rhel-8-test --skip-nvr-check
popd
rm -f localversion
