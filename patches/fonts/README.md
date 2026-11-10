# Fonts

`ui_body.ttf` and `ui_heading.ttf` are static instances of **Outfit** taken
from the upstream font project, not generated or renamed:

| File | Source | Weight |
|---|---|---|
| `ui_body.ttf` | <https://github.com/Outfitio/Outfit-Fonts/blob/main/fonts/ttf/Outfit-SemiBold.ttf> | SemiBold 600 |
| `ui_heading.ttf` | <https://github.com/Outfitio/Outfit-Fonts/blob/main/fonts/ttf/Outfit-Bold.ttf> | Bold 700 |

Download (from this directory):

```sh
curl -L -o ui_body.ttf    https://raw.githubusercontent.com/Outfitio/Outfit-Fonts/main/fonts/ttf/Outfit-SemiBold.ttf
curl -L -o ui_heading.ttf https://raw.githubusercontent.com/Outfitio/Outfit-Fonts/main/fonts/ttf/Outfit-Bold.ttf
```

Check that a file is the expected static weight (and not the variable
`Outfit[wght].ttf`) with:

```sh
python - ui_body.ttf <<'EOF'
import struct, sys
for path in sys.argv[1:]:
    data = open(path, 'rb').read()
    tables = {}
    for i in range(struct.unpack('>H', data[4:6])[0]):
        o = 12 + 16 * i
        tables[data[o:o+4].decode('latin1')] = struct.unpack('>II', data[o+8:o+16])
    os2 = tables['OS/2'][0]
    print(path, 'weight',
          struct.unpack('>H', data[os2+4:os2+6])[0],
          'VARIABLE' if 'fvar' in tables else 'static')
EOF
```

Expected: `ui_body.ttf weight 600 static`, `ui_heading.ttf weight 700 static`.

Outfit is licensed under the SIL Open Font License 1.1; the upstream launcher
already ships `FONT-LICENSE-OFL.txt` at `vibe-launcher/FONT-LICENSE-OFL.txt`.
If SemiBold proves too heavy on a TV, replace `ui_body.ttf` with
`Outfit-Medium.ttf` (500) — no other change is needed.
