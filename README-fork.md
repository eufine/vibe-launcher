# Fork setup

This fork rebuilds upstream [maydings/vibe-launcher](https://github.com/maydings/vibe-launcher)
releases with two changes:

- **UI font:** static Outfit SemiBold (body) and Bold (headings), instead of
  the variable Outfit whose default instance is Thin.
- **Updater:** the in-app updater checks this fork's GitHub releases and
  accepts APKs signed with my certificate.

`apply-patches.sh` makes both edits in an upstream checkout. The GitHub
Actions workflow in `.github/workflows/build.yml` does this daily, builds the
`adb` release, signs it, and publishes it here with upstream's tag and release
notes.

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

## How the workflow behaves

- Runs daily at 04:23 UTC and on demand.
- Reads upstream's `/releases/latest`; skips when this fork already has a
  release with the same tag **and** the `vibe-launcher.apk` asset.
- Builds the `adb` flavor: `assembleAdbRelease` (JDK 17, AGP 8.7.3, Gradle 8.9).
- Signs unsigned output with `apksigner`, verifies the certificate matches the
  one baked into the updater, and names the asset exactly `vibe-launcher.apk`.
- Releases use upstream's tag unchanged (e.g. `v4.0.8`) and upstream's release
  notes as the body. The updater strips a leading `v` and compares versions.

The tag and asset name are requirements, not cosmetics: `Updater.java` reads
`tag_name`, looks for an asset named `vibe-launcher.apk`, and verifies the
asset's GitHub `sha256:` digest.

## Patching a checkout by hand

```sh
cd /path/to/upstream-checkout
REPO=owner/fork CERT=<64-lowercase-hex> sh /path/to/apply-patches.sh
```

Run it from the checkout root (the directory containing `vibe-launcher/`).
It is safe to run twice, and exits non-zero without changing anything if
upstream's text no longer matches what it expects.

## Fonts

The bundled files are the official static Outfit instances:

- `patches/fonts/ui_body.ttf` — [Outfit-SemiBold.ttf](https://github.com/Outfitio/Outfit-Fonts/blob/main/fonts/ttf/Outfit-SemiBold.ttf), weight 600
- `patches/fonts/ui_heading.ttf` — [Outfit-Bold.ttf](https://github.com/Outfitio/Outfit-Fonts/blob/main/fonts/ttf/Outfit-Bold.ttf), weight 700

Outfit is under the SIL Open Font License 1.1; `vibe-launcher/FONT-LICENSE-OFL.txt`
already carries it. If SemiBold looks too heavy on the TV, replace `ui_body.ttf`
with `Outfit-Medium.ttf` (500) and rerun the workflow. See
`patches/fonts/README.md`.

## What still needs a human

- The signing key and secrets above.
- Deciding whether the key password differs from the store password.
- Installing the first fork APK (uninstall upstream first).
