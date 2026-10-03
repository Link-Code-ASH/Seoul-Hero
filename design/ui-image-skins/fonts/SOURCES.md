# Game fonts

These font files were supplied by the project owner on 2026-09-24. The originals remain in the owner's Downloads folder; the game stores only the faces it uses.

| In-game family | Files | Use |
| --- | --- | --- |
| Paperlogy | `Paperlogy-4Regular.ttf`, `Paperlogy-8ExtraBold.ttf` from `Paperlogy-1.001.zip` | Korean UI text and headings |
| SF Ssaraknun | `SFSsaraknun.ttf` from `SF싸락눈 배포판/SF싸락눈-TTF.ttf` | Wave completion and supply reward headings |
| Sungkok Serif | `KMU80SungkokSerif.woff2` from `KMU80SungkokHaeong_01/WebFonts` | Records and association titles |
| Haeong Sans | `KMU80HaeongSans.woff2` from `KMU80SungkokHaeong_01/WebFonts` | Gate and facility headings |
| BMJUA | `BMJUA.ttf` from `BMJUA_ttf.ttf` | Reward headings |

Existing Barlow Condensed remains for numbers and instrument labels; Pretendard remains as a local fallback.


## Godot native font inputs (2026-10-02)

- `KMU80HaeongSans.ttf` is the matching owner-supplied native TTF from `KMU80SungkokHaeong_01/TTF/KMU80TTFHaeongSans.ttf`. Its original KMU copyright remains embedded.
- `BarlowCondensed-SemiBold.ttf` and `BarlowCondensed-Bold.ttf` are lossless decompressions of the existing WOFF2 files using fontTools 4.66.1 and Brotli 1.2.0. Glyph outlines and metrics are unchanged; `BarlowCondensed-OFL.txt` applies to both formats.
- Original WOFF2 files remain in source assets. Godot uses the TTF copies to avoid the WOFF2 importer failure. Hashes and format provenance are in `font-import-provenance.json`.
