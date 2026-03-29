# Atlas Creation Workflows

You have brain parcellation data sitting on your computer. Maybe it’s a
FreeSurfer annotation file from a cortical atlas you want to visualize.
Maybe it’s a volumetric segmentation of subcortical structures. Maybe
it’s tractography streamlines defining white matter tracts. The question
is: how do you turn any of these into something you can actually plot
with ggseg?

The answer depends on what you’re starting with. Neuroimaging data comes
in a wild variety of formats, and each format tells you something
different about the brain. The common thread is that they all describe
regions or structures, and ggseg.extra knows how to extract that
information and turn it into atlas objects that work with both 2D and 3D
plotting.

## What you’re working with

Here’s the landscape. Different neuroimaging formats flow through
different creation functions, but they all converge on the same
destination: a `ggseg_atlas` object that contains everything needed for
visualization.

``` mermaid
flowchart TB
    A[Input Files] --> B[FreeSurfer .annot]
    A --> C[FreeSurfer .label]
    A --> D[GIFTI .label.gii]
    A --> E[CIFTI .dlabel.nii]
    A --> F[Neuromaps .func.gii/.nii]
    A --> G[Volume .mgz/.nii]
    A --> H[Tractography .trk/.tck]

    B --> B1[create_cortical_from_annotation]
    C --> C1[create_cortical_from_labels]
    D --> D1[create_cortical_from_gifti]
    E --> E1[create_cortical_from_cifti]
    F --> F1[create_cortical_from_neuromaps]
    G --> G1[create_subcortical_from_volume<br/>create_wholebrain_from_volume]
    H --> H1[create_tract_from_tractography]

    B1 --> I[ggseg_atlas]
    C1 --> I
    D1 --> I
    E1 --> I
    F1 --> I
    G1 --> I
    H1 --> I

    style I fill:#e1f5ff
```

Figure 1: All atlas creation pathways in ggseg.extra

## How cortical atlases get built

Every cortical creation function — whether you’re starting with
FreeSurfer annotations, GIFTI labels, CIFTI parcellations, or neuromaps
data — follows the same two-step pipeline.

Step 1 reads your input file and maps it to 3D vertices on the brain
surface. Step 2 projects the inflated mesh triangles directly to 2D
polygons via orthographic projection. Both steps complete in seconds and
require no external rendering dependencies — just FreeSurfer to read the
annotation files.

``` mermaid
flowchart LR
    A[Input File] --> S1["Step 1<br/>Read annotation<br/>& extract vertices"]
    S1 --> S2["Step 2<br/>Project mesh to<br/>2D polygons"]
    S2 --> F[Complete atlas<br/>3D + 2D ⚡]

    style S1 fill:#fff9c4
    style S2 fill:#c8e6c9
    style F fill:#e1f5ff
```

Figure 2: Cortical atlas creation pipeline

The projection uses orthographic cameras placed at standard viewpoints
(lateral, medial, superior, inferior), culls back-facing triangles, and
unions the front-facing triangles per region into sf polygons. Boundary
faces are assigned to the smallest neighbouring region so small parcels
stay visible. The `tolerance` parameter controls polygon simplification
— use 0 for maximum fidelity, higher values for smaller file sizes.

## Subcortical and volumetric atlases work differently

Cortical atlases are all about surface vertices — mapping regions to
points on the brain’s outer layer. Subcortical structures live inside
the brain, so the approach changes. Instead of vertex indices, you’re
extracting 3D meshes directly from volumetric segmentations.

The pipeline reads your volume file (typically a `.mgz` or `.nii`
segmentation) along with its color table, identifies each unique
structure, and generates a mesh for it. Each mesh becomes a distinct 3D
object you can visualize, but there’s no 2D equivalent here —
subcortical atlases are 3D-only.

You have two functions to choose from:
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
if you only want subcortical structures, or
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
if your segmentation includes both cortical and subcortical regions and
you want everything in one atlas.

``` mermaid
flowchart TB
    A[Volume .mgz/.nii<br/>+ Color Table] --> B[Read segmentation<br/>Extract unique labels]
    B --> C{Atlas type?}
    C -->|Subcortical only| D[create_subcortical_from_volume]
    C -->|Whole brain| E[create_wholebrain_from_volume]

    D --> F[For each structure:<br/>Extract voxels<br/>Generate mesh<br/>Calculate vertices]
    E --> F

    F --> G[Combine meshes<br/>Add metadata<br/>Apply color palette]
    G --> H[ggseg_atlas<br/>3D meshes only<br/>No 2D]

    style H fill:#e1f5ff
```

Figure 3: Subcortical and whole-brain volumetric atlas pipeline

## Tracts are a special case

White matter tracts don’t fit neatly into the cortical or subcortical
categories. They’re defined by tractography — streamlines that trace the
paths of white matter fibers through the brain. Your input is a
tractography file (`.trk` or `.tck`), which contains a collection of 3D
curves representing fiber bundles.

The pipeline reads those streamlines and converts them into tube-like
meshes that can be rendered in 3D. There’s an optional resampling step
(step 2) that normalizes the point spacing along each streamline, which
can make the resulting meshes cleaner and more consistent. Like
subcortical atlases, tract atlases are 3D-only — there’s no meaningful
2D representation of a white matter pathway.

``` mermaid
flowchart TB
    A[Tractography<br/>.trk or .tck] --> B[Read streamlines<br/>Parse header]
    B --> C{steps parameter}
    C -->|steps = 1| D[Keep original<br/>streamlines]
    C -->|steps = 1:2| E[Step 2:<br/>Resample streamlines<br/>Uniform point spacing]

    D --> F[Convert to meshes<br/>Create tubes<br/>from streamlines]
    E --> F

    F --> G[Add metadata<br/>Color palette<br/>Hemisphere labels]
    G --> H[ggseg_atlas<br/>3D tract meshes<br/>No 2D]

    style H fill:#e1f5ff
```

Figure 4: White matter tract atlas pipeline

## Where your atlas can go

Every `ggseg_atlas` object, regardless of how it was created, works with
the ggseg plotting ecosystem. But what you can do with it depends on
whether it contains 2D polygon data.

If your atlas has 2D geometries (which only cortical atlases can have,
and only if you ran the full pipeline), you can plot it with both ggseg
for flat 2D ggplot2-based visualizations and ggseg3d for interactive 3D
rotation and exploration. If it’s 3D-only — because it’s subcortical, a
tract atlas, or a cortical atlas you stopped at step 1 — then ggseg3d is
your only option, but that’s often all you need.

``` mermaid
flowchart LR
    A[ggseg_atlas] --> B{Contains 2D?}
    B -->|Yes| C[ggseg<br/>Flat 2D plots]
    B -->|Yes| D[ggseg3d<br/>Interactive 3D]
    B -->|No<br/>3D only| D

    C --> E[ggplot2-based<br/>Static visualizations]
    D --> F[plotly-based<br/>Rotate & explore]

    style A fill:#e1f5ff
    style C fill:#c8e6c9
    style D fill:#c8e6c9
```

Figure 5: Atlas compatibility with ggseg plotting packages

## Performance

Cortical atlas creation is fast — the full pipeline (read + project)
completes in seconds because the mesh projection is pure geometry with
no external rendering. The `tolerance` parameter is the main tuning
knob: 0 gives maximum fidelity, 0.5 (the default) is a good balance, and
higher values trade detail for smaller file sizes.

For subcortical and tract pipelines, the `steps` parameter lets you
control how much of the pipeline runs. Use a low step count for fast
3D-only iteration, then run the full pipeline when you need 2D geometry.

## Where to go from here

If you’re new to ggseg.extra, start with the [Getting
Started](https://ggsegverse.github.io/ggseg.extra/articles/ggseg.extra.md)
guide for installation and basic usage. The cortical pipeline has no
system dependencies — it only needs the `freesurferformats` R package to
read annotation files. Subcortical and whole-brain pipelines need
FreeSurfer and ImageMagick; see [System
Setup](https://ggsegverse.github.io/ggseg.extra/articles/system-setup.md)
for details.

The [Pipeline
Configuration](https://ggsegverse.github.io/ggseg.extra/articles/pipeline-configuration.md)
article covers how to customize the creation process, including options
for controlling smoothing, contour extraction, and other pipeline
parameters. When you’re ready to build a specific atlas type, the
individual tutorials under “Tutorials: Creating Atlases” walk through
complete examples with real data.
