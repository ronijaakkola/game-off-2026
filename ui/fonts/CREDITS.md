# Font credits

| File | Source | Author | License |
|---|---|---|---|
| `baloo_2.ttf` | [Baloo 2](https://fonts.google.com/specimen/Baloo+2) (`ofl/baloo2/Baloo2[wght].ttf` in [google/fonts](https://github.com/google/fonts)), variable weight | The Baloo 2 Project Authors | SIL Open Font License 1.1 (`OFL.txt`) |
| `figtree.ttf` | [Figtree](https://fonts.google.com/specimen/Figtree) (`ofl/figtree/Figtree[wght].ttf` in [google/fonts](https://github.com/google/fonts)), variable weight | The Figtree Project Authors | SIL Open Font License 1.1 (`OFL_figtree.txt`) |

## Changes to the files

`baloo_2.ttf` has the overlap flag set on every glyph; its outlines are untouched. Baloo 2 builds letters from overlapping shapes (the stems and arches of "m"), and without the flag the rasteriser leaves notches where they cross. Figtree has no overlaps and is as downloaded.

After replacing `baloo_2.ttf` with a fresh download, set the flag again:

```sh
uv run --with fonttools python -c "
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import setMacOverlapFlags
font = TTFont('ui/fonts/baloo_2.ttf')
setMacOverlapFlags(font['glyf'])
font.save('ui/fonts/baloo_2.ttf')"
```
