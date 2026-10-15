# Model credits

`building-small-b.glb` and `Textures/colormap.png` are from the
[Starter Kit City Builder](https://github.com/KenneyNL/starter-kit-city-builder) by
[Kenney](https://kenney.nl), released under
[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) (public domain; credit is not
required, but given). Copied unchanged from the kit's `models/` folder.

`building-small-b` is used by `styles/style_base.tscn`; the kit has more buildings to swap in.

The `.glb.import` sets `import_script/path` to `tools/single_mesh_import.gd`, which makes the
mesh the scene's root so style scenes can override its surface material by the instance's own
name. The code of the kit is MIT; only the models and the texture are used here.
