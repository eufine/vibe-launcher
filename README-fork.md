# Fork setup

This fork rebuilds upstream [maydings/vibe-launcher](https://github.com/maydings/vibe-launcher)
releases with two changes:

- **UI font:** Roboto Condensed — Light for body text and SemiBold for
  headings — instead of the variable Outfit whose default instance is Thin.
- **Updater:** the in-app updater checks this fork's GitHub releases and
  accepts APKs signed with my certificate.

`apply-patches.sh` makes both edits in an upstream checkout. The GitHub
Actions workflow in `.github/workflows/build.yml` does this daily, builds the
`adb` release, signs it, and publishes it here with upstream's tag and release
notes.

## Current status of this fork

- A dedicated signing key was generated on 2026-11-10, and the
  `KEYSTORE_B64`, `KEYSTORE_PASSWORD` and `KEY_ALIAS` Actions secrets are set.
  The store and key passwords are the same, so `KEY_PASSWORD` is not needed.
- The keystore is `release.jks` in the repository root and the credentials are
  in `.release-credentials.txt`. Both are gitignored. **Back them up now**:
  without this exact key, no later release can update an installed copy.
- `v4.0.8` was built and published by the workflow. `v4.0.8-r1` was then
  built manually with Roboto Condensed Thin, and `v4.0.8-r2` with Roboto
  Condensed Light for body text; both were installed over it. Further runs
  skip while upstream stays on the same base tag.

The setup below is what a fresh fork needs.

## One-time setup

### 1. Generate a signing key (once, and keep it forever)

APKs signed with a different key cannot update an installed copy. Back up the
keystore and its passwords.

```sh
keytool -genkeypair -v -keystore release.jks -alias vibe-launcher \
  -keyalg RSA -keysize 4096 -validity 10000
```

The certificate fingerprint (lowercase, no colons) is what the patched updater
expects. The workflow computes it automatically, but you can print it with:

```sh
keytool -list -v -keystore release.jks -alias vibe-launcher | grep SHA256
```

### 2. Add the repository secrets

Base64-encode the keystore as one line (`-w0` is GNU; on macOS use
`base64 -i release.jks | tr -d '\n'`):

```sh
base64 -w0 release.jks > release.jks.b64
```

Then in **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `KEYSTORE_B64` | the contents of `release.jks.b64` |
| `KEYSTORE_PASSWORD` | the keystore (store) password |
| `KEY_ALIAS` | `vibe-launcher` (the alias you chose) |
| `KEY_PASSWORD` | only if the key password differs from the store password |

Do not commit `release.jks` or `release.jks.b64`; `*.jks` and `*.keystore`
are ignored.

### 3. Enable Actions and release permissions

- **Settings → Actions → General**: allow Actions to run.
- Under **Workflow permissions**, choose **Read and write permissions**. The
  workflow requests `contents: write` to create releases.

### 4. Put the workflow on the default branch

Scheduled workflows only run from the repository's **default branch**
(`main`). Merge/cherry-pick these files there (or run the workflow manually
from this branch with **Actions → Fork release → Run workflow**).

### 5. First run

Run **Actions → Fork release → Run workflow** once. It clones upstream's
latest release tag, patches it, builds and signs it, and publishes
`vibe-launcher.apk` on a release with the same tag as upstream.

### 6. Install on the TV

Because the signature differs from upstream's, the original app must be
uninstalled before the first install of this fork's APK. That also clears its
settings.

```sh
adb uninstall com.maydings.vibelauncher
adb install -r -g vibe-launcher.apk
```

After that, later fork releases install over it normally, and the in-app
updater works.

## How the automatic workflow behaves

- Runs daily at 04:23 UTC and on demand.
- Reads upstream's `/releases/latest`; skips when this fork's latest release
  has the same base tag (ignoring any `-rN` suffix) **and** the
  `vibe-launcher.apk` asset.
- Builds the `adb` flavor: `assembleAdbRelease` (JDK 17, AGP 8.7.3, Gradle 8.9).
- Signs unsigned output with `apksigner`, verifies the certificate matches the
  one baked into the updater, and names the asset exactly `vibe-launcher.apk`.
- Releases use upstream's tag unchanged (e.g. `v4.0.8`) and upstream's release
  notes as the body. The updater strips a leading `v` and compares versions.

The tag and asset name are requirements, not cosmetics: `Updater.java` reads
`tag_name`, looks for an asset named `vibe-launcher.apk`, and verifies the
asset's GitHub `sha256:` digest.

## Manual rebuild (font or other fork-only change)

The automatic workflow skips a tag it has already published. To rebuild the
current source without waiting for an upstream release, use the manual
workflow on this branch:

```sh
# after committing the change to fontpatch
gh workflow run manual-rebuild.yml --repo eufine/vibe-launcher --ref fontpatch
```

It checks out the branch, patches it, builds and signs it, and publishes the
APK under an auto-bumped tag: the first run makes `v4.0.8-r1`, the next
`v4.0.8-r2`, and so on. Pass `-f custom_tag=v4.0.8-r7` to choose the tag.

```sh
gh release download v4.0.8-r1 --repo eufine/vibe-launcher \
  --pattern vibe-launcher.apk --clobber
adb install -r -g vibe-launcher.apk
```

A `-rN` tag is **not** offered by the in-app updater: the APK still reports
`versionName=4.0.8`, so the updater sees it as the same version. Install a
manual rebuild over ADB; this preserves app data because the signing key is
unchanged. In-app updates continue to work normally for new upstream versions.

## Patching a checkout by hand

```sh
cd /path/to/upstream-checkout
REPO=owner/fork CERT=<64-lowercase-hex> sh /path/to/apply-patches.sh
```

Run it from the checkout root (the directory containing `vibe-launcher/`).
It is safe to run twice, and exits non-zero without changing anything if
upstream's text no longer matches what it expects.

## Fonts

The bundled files are static instances of
[Roboto Condensed](https://fonts.google.com/specimen/Roboto+Condensed)
(from the [Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/robotocondensed)):

- `patches/fonts/ui_body.ttf` — Roboto Condensed **Light**, used for body text
- `patches/fonts/ui_heading.ttf` — Roboto Condensed **SemiBold**, used for headings

Roboto Condensed is under the SIL Open Font License 1.1. To swap either role,
replace the corresponding `.ttf`, commit, and run the manual rebuild workflow
above; `apply-patches.sh` copies both files and repoints `fonts.xml`, so no
Java or layout change is needed. See `patches/fonts/README.md`.

## What still needs a human

- Back up `release.jks` and `.release-credentials.txt` somewhere safe.
- Install the first fork APK, uninstalling upstream first because the
  signatures differ.
