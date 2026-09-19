# Atlas manipulation verbs, re-exported from ggseg.formats

The vocabulary for reshaping a finished atlas – dropping regions,
gathering views, boolean geometry between labels – lives in
ggseg.formats, because it belongs to the atlas format rather than to any
one builder. Every atlas build reaches for both packages, so ggseg.extra
re-exports the verbs and
[`library(ggseg.extra)`](https://github.com/ggsegverse/ggseg.extra) is
enough.

Only the `atlas_*` verbs are re-exported. ggseg.formats also ships
atlases named `dk`, `aseg`, `tracula` and `suit`, and so does ggseg;
attaching the whole namespace would mask one set with the other
depending on load order, which is a silently wrong atlas rather than an
error.

Four more verbs - `atlas_centerlines()`, `atlas_plot_palette()`,
`atlas_structure_reorder()` and `atlas_view_select()` - exist only in
ggseg.formats' development build, so re-exporting them here would stop
this package building against the release its DESCRIPTION asks for. They
can come across once ggseg.formats releases them and the floor here
moves up.
