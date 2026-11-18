# Read a brain surface mesh

Reads a surface file into a mesh that describes itself: vertices, faces,
and a
[`ggseg.formats::mesh_space()`](https://ggsegverse.github.io/ggseg.formats/reference/mesh_space.html)
recording the vertex space, hemisphere and relationship to a standard
space.

## Usage

``` r
read_surface_mesh(
  path,
  space,
  face_index_base = 0L,
  format = c("auto", "freesurfer", "gifti")
)
```

## Arguments

- path:

  Path to a FreeSurfer binary surface or a GIFTI surface file.

- space:

  A
  [`ggseg.formats::mesh_space()`](https://ggsegverse.github.io/ggseg.formats/reference/mesh_space.html)
  describing what the mesh's coordinates mean.

- face_index_base:

  `0L` or `1L` – what the returned face indices should count from.

- format:

  Source format. `"auto"` reads the extension, which is why it can be
  overridden: a FreeSurfer surface is often named `lh.inflated`, with no
  extension to go on.

## Value

A mesh from
[`ggseg.formats::brain_mesh()`](https://ggsegverse.github.io/ggseg.formats/reference/brain_mesh.html),
carrying `mesh_space` and `face_index_base` attributes.

## Details

Meshes are independent of atlases. An atlas defines regions – labels and
the vertex indices they cover – while a mesh is a surface to draw them
on. The two meet only at `vertex_space`: an atlas's indices mean
something on a mesh in the space the atlas was built against, and
nothing on any other. This function therefore produces a mesh, never an
atlas, and nothing here feeds the `create_*_from_*()` pipelines.

`face_index_base` chooses what the returned faces count from. FreeSurfer
surfaces are read as 1-based and GIFTI as 0-based, so a base is always
converted to rather than assumed, and
[`ggseg.formats::brain_mesh()`](https://ggsegverse.github.io/ggseg.formats/reference/brain_mesh.html)
checks the result. The ecosystem genuinely holds both conventions –
`ggseg.formats` inflated surfaces are 0-based, `ggseg.meshes` cortical
surfaces are 1-based – because four build scripts each chose
independently. Choosing here, once, is the point.

FreeSurfer surfaces are read through `mris_convert` where it is
available, which handles the QUAD surfaces `mri_tessellate` writes,
falling back to `freesurferformats`.

## Examples

``` r
if (FALSE) {
space <- ggseg.formats::mesh_space(
  vertex_space = "fsaverage5",
  hemi = "left",
  anatomical = FALSE,
  surface = "inflated"
)
read_surface_mesh(
  file.path(Sys.getenv("FREESURFER_HOME"), "subjects", "fsaverage5",
            "surf", "lh.inflated"),
  space = space
)
}
```
