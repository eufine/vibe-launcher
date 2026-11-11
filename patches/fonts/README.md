# Fonts

`ui_body.ttf` and `ui_heading.ttf` are static instances of
[Roboto Condensed](https://fonts.google.com/specimen/Roboto+Condensed), from the
[Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/robotocondensed):

| File | Role | Instance | `usWeightClass` |
|---|---|---|---|
| `ui_body.ttf` | `font_regular` — body text | Roboto Condensed Thin | 250 |
| `ui_heading.ttf` | `font_medium` — headings | Roboto Condensed SemiBold | 600 |

They are static fonts (no `fvar` table), so Android picks the named weight
directly instead of falling back to the variable font's Thin default.

To change a role, download the desired static `.ttf` from Google Fonts,
overwrite the matching file here, commit, and run the manual rebuild workflow
(see the top-level `README-fork.md`). No Java or layout change is needed:
`fonts.xml` names `@font/ui_body` and `@font/ui_heading`, and
`apply-patches.sh` copies both files into the app.

Roboto Condensed is licensed under the SIL Open Font License 1.1; the full
text is in `OFL-RobotoCondensed.txt` in this directory. The upstream launcher
also ships `vibe-launcher/FONT-LICENSE-OFL.txt` for Outfit.
