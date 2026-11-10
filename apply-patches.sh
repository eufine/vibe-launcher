#!/bin/sh
# Patch an upstream vibe-launcher checkout: static UI fonts + self-updates from
# your own fork.
#
# Run from the root of the checkout (the directory holding README.md and
# vibe-launcher/), with REPO and CERT in the environment:
#
#   cd /path/to/vibe-launcher
#   REPO=owner/fork CERT=<64 lowercase hex> sh /path/to/apply-patches.sh
#
# REPO is the GitHub owner/name of your fork.
# CERT is the SHA-256 of your signing certificate, lowercase hex, no colons
# (keytool -list -v ... prints it; strip the colons).
#
# The script edits in place and exits non-zero if any expected upstream text is
# missing, so a half-patched tree can never be built silently.
set -eu

: "${REPO:?set REPO to owner/name of your fork, e.g. eufine/vibe-launcher}"
: "${CERT:?set CERT to the lowercase SHA-256 of your signing certificate}"

die() {
    printf 'apply-patches: %s\n' "$*" >&2
    exit 1
}

# Validate inputs before touching anything: they are interpolated into sed.
case $REPO in
    *[!A-Za-z0-9._/-]* | /* | */ | */*/*) die "REPO must be exactly owner/name, got '$REPO'" ;;
esac
printf '%s\n' "$CERT" | grep -Eq '^[0-9a-f]{64}$' ||
    die "CERT must be 64 lowercase hex characters, no colons or spaces"

# GNU sed on Windows (Git Bash) translates CRLF unless told not to; --binary
# keeps the checkout's line endings byte-for-byte. BSD/macOS sed has no such
# option, and needs none.
SEDI='sed -i'
if sed --binary --version >/dev/null 2>&1; then
    SEDI='sed --binary -i'
fi

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(pwd)
SRC=$ROOT/vibe-launcher/app/src/main
RES=$SRC/res
FONTS_XML=$RES/values/fonts.xml
FONT_DIR=$RES/font
UPD=$SRC/java/com/maydings/vibelauncher/Updater.java
BODY=$HERE/patches/fonts/ui_body.ttf
HEAD=$HERE/patches/fonts/ui_heading.ttf

for f in "$FONTS_XML" "$UPD" "$BODY" "$HEAD"; do
    [ -f "$f" ] || die "missing $f (run from the root of an upstream checkout?)"
done
[ -d "$FONT_DIR" ] || die "missing font directory $FONT_DIR"

# Preflight: accept either the pristine upstream text or an already patched
# tree, but refuse to continue if neither matches. Nothing is modified before
# every target has been found.
if ! grep -Fq '@font/outfit</string>' "$FONTS_XML" &&
   ! grep -Fq '@font/ui_body</string>' "$FONTS_XML"; then
    die "fonts.xml has neither @font/outfit nor @font/ui_body; upstream changed"
fi
if ! grep -Fq 'repos/maydings/vibe-launcher/' "$UPD" &&
   ! grep -Fq "repos/$REPO/" "$UPD"; then
    die "Updater.java has neither the upstream repo URLs nor repos/$REPO/; upstream changed"
fi
grep -Eq 'RELEASE_CERT = "[0-9a-f]{64}"' "$UPD" ||
    die "Updater.java has no 64-hex RELEASE_CERT line; upstream changed"

# 1. Static fonts: body SemiBold (600), headings Bold (700).
cp "$BODY" "$FONT_DIR/ui_body.ttf"
cp "$HEAD" "$FONT_DIR/ui_heading.ttf"

# 2. Point the two names every layout and view uses at the new files.
$SEDI \
    -e 's#@font/outfit</string>#@font/ui_body</string>#' \
    -e 's#@font/outfit_medium</string>#@font/ui_heading</string>#' \
    "$FONTS_XML"

# 3. Self-updates from the fork's releases, signed with my certificate.
$SEDI "s#repos/maydings/vibe-launcher/#repos/$REPO/#g" "$UPD"
$SEDI "s#RELEASE_CERT = \"[0-9a-f]\{64\}\"#RELEASE_CERT = \"$CERT\"#" "$UPD"

# 4. Assert every edit landed; a missed sed is a failed build, not a silent
#    upstream-coloured APK.
grep -Fq '@font/ui_body</string>' "$FONTS_XML" ||
    die "fonts.xml: font_regular was not repointed"
grep -Fq '@font/ui_heading</string>' "$FONTS_XML" ||
    die "fonts.xml: font_medium was not repointed"
grep -Fq "repos/$REPO/releases/latest" "$UPD" ||
    die "Updater.java: LATEST was not repointed to repos/$REPO"
grep -Fq "repos/$REPO/releases?per_page" "$UPD" ||
    die "Updater.java: RECENT was not repointed to repos/$REPO"
grep -Fq "RELEASE_CERT = \"$CERT\"" "$UPD" ||
    die "Updater.java: RELEASE_CERT was not replaced"
if grep -Fq 'repos/maydings/vibe-launcher/' "$UPD"; then
    die "Updater.java still points some URL at upstream"
fi
if grep -Fq '@font/outfit' "$FONTS_XML"; then
    die "fonts.xml still references the upstream Outfit resources"
fi

printf 'apply-patches: patched fonts and updater for %s\n' "$REPO"
