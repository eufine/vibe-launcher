# Task: patched, auto-rebuilding fork of maydings/vibe-launcher

## Context
This repo is my fork of https://github.com/maydings/vibe-launcher (an Android TV launcher, MIT licence). Repo root contains a Gradle project in `vibe-launcher/` (the Android app is `vibe-launcher/app`). I am on Windows; run shell scripts in Git Bash. Upstream is added as the `upstream` remote.

I want my own build of each upstream release with these changes, rebuilt automatically when upstream publishes a new release:
1. A heavier, more legible UI font.
2. The in-app updater pointed at MY fork's releases instead of upstream's.

## Facts already established (do not re-derive; verify only if something contradicts them)
- Fonts: `app/src/main/res/values/fonts.xml` defines `font_regular` = `@font/outfit` and `font_medium` = `@font/outfit_medium`. All layouts and Java code use only these two names (`UiFont.get(ctx, R.string.font_regular|font_medium)` and `android:fontFamily="@string/..."`), so repointing these two strings changes the whole UI. No Java changes are needed for the font.
- `res/font/outfit.ttf` is Outfit's VARIABLE font; its default instance is Thin (100), which is why text looks faint and jagged on 4K. `res/font/outfit_medium.xml` sets weight 500 on it, and the author notes that view-level fontVariationSettings is ignored on Android 9.
- I want STATIC Outfit fonts instead: body text SemiBold (600), headings Bold (700). If SemiBold looks too heavy on the TV, fall back to Medium (500) body and SemiBold (600) headings. The OFL licence allows bundling them. I will put the files at `patches/fonts/ui_body.ttf` and `patches/fonts/ui_heading.ttf`. If they are missing, tell me exactly what to download and from where; do not invent font files.
- Updater: `app/src/main/java/com/maydings/vibelauncher/Updater.java` has `LATEST` and `RECENT` constants hardcoded to `https://api.github.com/repos/maydings/vibe-launcher/...`, and `RELEASE_CERT` (SHA-256 of the author's signing cert). `isDevelopmentBuild()` returns true when the installed app's signing cert != `RELEASE_CERT`, and then `available()` returns null (no updates offered). So the patch must change BOTH the repo URLs and `RELEASE_CERT` (to the hash of MY signing certificate, lowercase hex, no colons).
- The updater reads the release's `tag_name` (strips a leading v), looks for an asset named `vibe-launcher.apk`, and uses GitHub's asset `digest` ("sha256:...") for verification. My releases must therefore use the SAME tag as upstream (e.g. v4.0.9, no suffix) and upload the APK named exactly `vibe-launcher.apk`.
- There are two build flavors, `adb` and `store` (`app/src/adb/...` and `app/src/store/...` each contain a `StoreUpdates.java`). I want the `adb` flavor. The exact Gradle task and APK output path are UNVERIFIED.
- `SettingsScreen.java` lines ~555-556 hardcode `GITHUB_USER = "maydings"` and `PROJECT = "maydings/vibe-launcher"`; their purpose is unknown. `CleanLists.java` fetches Gathin23/cleanyourtv lists, unrelated. Do not change either unless you find they break the updater.

## Deliverables
1. `apply-patches.sh` (POSIX sh, repo root). Run from inside an upstream checkout. Requires env vars `REPO` (owner/name of my fork) and `CERT` (my cert hash). It must:
   - copy `patches/fonts/ui_body.ttf` and `ui_heading.ttf` into `vibe-launcher/app/src/main/res/font/`;
   - repoint `fonts.xml` (`@font/outfit` -> `@font/ui_body`, `@font/outfit_medium` -> `@font/ui_heading`);
   - rewrite the two URLs in `Updater.java` to `repos/$REPO/` and set `RELEASE_CERT` to `$CERT`;
   - finish with `grep -q` assertions for every edit, so it exits non-zero if upstream changed something and an edit silently missed. Never produce a half-patched build.
   Use `sed -i` with care for byte-exact edits (no re-encoding, no BOM, keep line endings).
2. `.github/workflows/build.yml`:
   - triggers: daily `schedule` plus `workflow_dispatch`; `permissions: contents: write`;
   - compare upstream's latest release tag with my fork's latest release tag; skip if equal;
   - shallow-clone the upstream tag into `src/`, run `apply-patches.sh` with `REPO=${{ github.repository }}` and `CERT` computed from my keystore via keytool;
   - build the adb release variant with JDK 17, sign with apksigner (secrets `KEYSTORE_B64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`; ask me whether the key password differs), produce `vibe-launcher.apk`;
   - publish a release in my fork with upstream's tag, upstream's release notes as the body, and the APK as an asset.
3. A short `README-fork.md` explaining the one-time setup (generate keystore, add secrets, enable Actions on the fork, first manual run, uninstall the original app before first install because the signature differs).

## Things you must verify, not assume
- Read `vibe-launcher/README.md` ("Build it yourself") and `vibe-launcher/app/build.gradle` to find the real Gradle task, flavor names, signing config, minSdk, and the actual APK output path. Fix the workflow to match. If the release build requires a signing config or properties file, handle it in the workflow without committing secrets.
- Run the build locally if the Android SDK and JDK 17 are available (`./gradlew assembleAdbRelease` or the correct task) to prove the patched tree compiles. If the SDK is missing, say so rather than claiming success.
- Confirm the patch script is idempotent-safe on a fresh checkout and fails loudly on a mismatch (test by running it against a tree where one target line is altered).

## Constraints
- Do not modify upstream source beyond the edits above. Keep all custom material in `patches/`, `apply-patches.sh`, the workflow and the README.
- Never commit keystores, passwords or tokens. Add `*.jks` and `*.keystore` to `.gitignore` if missing.
- Ask before any destructive git operation (reset --hard, clean, force-push, history rewrite).
- Keep the diff small and explain each decision in your final message. List anything you could not verify.

Start by reading the files named above and reporting the Gradle task, flavors and signing setup before writing anything.