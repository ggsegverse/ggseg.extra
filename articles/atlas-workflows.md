# Atlas Creation Workflows

Five pipelines, each shaped by the kind of data it reads. This article
is the map: what flows where, what each pipeline does to get from a file
to a `ggseg_atlas`, and where the result can be plotted.

For a runnable first atlas see [Getting
Started](https://ggsegverse.github.io/ggseg.extra/articles/ggseg.extra.md);
for a worked example of any one pipeline, see its tutorial.

## What you’re working with

Every format converges on one object.

``` mermaid
flowchart TB
    A[Input Files] --> B[FreeSurfer .annot]
    A --> C[FreeSurfer .label]
    A --> D[GIFTI .label.gii]
    A --> E[CIFTI .dlabel.nii]
    A --> F[Neuromaps .func.gii/.nii]
    A --> G[Volume .mgz/.nii]
    A --> H[Tractography .trk/.tck]
    A --> J[SUIT .label.gii/.annot]

    B --> B1[create_cortical_from_annotation]
    C --> C1[create_cortical_from_labels]
    D --> D1[create_cortical_from_gifti]
    E --> E1[create_cortical_from_cifti]
    F --> F1[create_cortical_from_neuromaps]
    G --> G1[create_subcortical_from_volume<br/>create_wholebrain_from_volume<br/>create_tract_from_volume]
    H --> H1[create_tract_from_tractography]
    J --> J1[create_cerebellar_from_gifti<br/>create_cerebellar_from_annotation<br/>create_cerebellar_from_volume]

    B1 --> I[ggseg_atlas]
    C1 --> I
    D1 --> I
    E1 --> I
    F1 --> I
    G1 --> I
    H1 --> I
    J1 --> I

    style I fill:#e1f5ff
```

Figure 1: All atlas creation pathways in ggseg.extra

## How cortical atlases get built

Every cortical creation function follows the same two steps, whatever
the input format. Neither needs a FreeSurfer installation — reading the
files needs the `freesurferformats` R package.

``` mermaid
flowchart LR
    A[Input File] --> S1["Read annotation<br/>& extract vertices"]
    S1 --> S2["Project mesh to<br/>2D polygons"]
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
stay visible. The pipeline returns the raw polygons; call
`atlas_simplify(keep = ...)` afterwards to balance fidelity against file
size.

## Subcortical and volumetric atlases work differently

A structure buried inside the brain has no outside to project, so these
pipelines read a volume — and its colour table, if it has one — and
tessellate a mesh per structure out of the voxels, rather than mapping
surface vertices.

2D comes from slices rather than from a surface: the pipeline takes
orthogonal cuts through the volume — the slabs you choose with
[`subcortical_slabs()`](https://ggsegverse.github.io/ggseg.extra/reference/subcortical_slabs.md)
— and traces each structure’s outline in each cut, giving a flat,
multi-panel view in the same `ggseg_atlas`. Stop at `steps = 1:3` if you
only want the meshes; the default runs all six and gives you both.

You have two functions to choose from:
[`create_subcortical_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_subcortical_from_volume.md)
if you only want subcortical structures, or
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
if your segmentation includes both cortical and subcortical regions and
you want everything in one atlas.

``` mermaid
flowchart TB
    A[Volume .mgz/.nii<br/>+ optional LUT] --> B[Read segmentation<br/>Extract unique labels]
    B --> C{Atlas type?}
    C -->|Subcortical only| D[create_subcortical_from_volume]
    C -->|Whole brain| E[create_wholebrain_from_volume]

    D --> F[For each structure:<br/>Extract voxels<br/>Generate mesh]
    E --> F

    F --> G["Steps 1-3<br/>3D meshes"]
    G --> S["Steps 4-6<br/>Slice the volume<br/>Trace contours"]
    S --> H[ggseg_atlas<br/>3D meshes + 2D slices]
    G -->|steps = 1:3| H2[ggseg_atlas<br/>3D meshes only]

    style H fill:#e1f5ff
    style H2 fill:#e1f5ff
```

Figure 3: Subcortical and whole-brain volumetric atlas pipeline

## Cerebellar atlases use the SUIT flatmap

The cerebellum needs its own pipeline because standard cortical surfaces
don’t cover it. Instead of projecting onto an inflated cortical mesh,
cerebellar atlases use the [SUIT
template](https://www.diedrichsenlab.org/imaging/suit.htm) — a dedicated
cerebellar surface with a 2D flatmap that unfolds the tightly folded
cerebellar cortex into a readable layout.

ggseg.extra ships both SUIT surfaces (flatmap and 3D pial) and provides
three entry points:
[`create_cerebellar_from_gifti()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_gifti.md)
for GIFTI label files,
[`create_cerebellar_from_annotation()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_annotation.md)
for FreeSurfer annotations on the SUIT surface, and
[`create_cerebellar_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_cerebellar_from_volume.md)
for NIfTI segmentation volumes.

``` mermaid
flowchart LR
    A[Input File] --> S1["Read parcellation<br/>Map to SUIT surface"]
    S1 --> S2["Project onto<br/>SUIT flatmap"]
    S2 --> F[Complete atlas<br/>2D flatmap + optional 3D]

    style S1 fill:#fff9c4
    style S2 fill:#c8e6c9
    style F fill:#e1f5ff
```

Figure 4: Cerebellar atlas creation pipeline

The flatmap projection converts mesh triangles directly into sf polygons
— no rendering or screenshots needed. Boundary triangles (where vertices
belong to different regions) are split at edge midpoints so region
borders stay clean. When the input is a volume, the pipeline also
tessellates per-region 3D meshes from the voxels, giving you both 2D and
3D in one call.

The
[`create_wholebrain_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_wholebrain_from_volume.md)
pipeline can also route cerebellar labels through this pipeline
automatically when it detects them in a combined volume.

## Tracts are a special case

White matter tracts don’t fit neatly into the cortical or subcortical
categories. They’re defined by tractography — streamlines that trace the
paths of white matter fibers through the brain.
[`create_tract_from_tractography()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_tractography.md)
takes those streamlines directly, from a `.trk` or `.tck` file.
[`create_tract_from_volume()`](https://ggsegverse.github.io/ggseg.extra/reference/create_tract_from_volume.md)
starts from a volumetric tract label map instead, reducing each label’s
voxel cloud to one ordered centerline before handing it to the same
pipeline — which is what a probabilistic tract atlas distributed as a
NIfTI needs.

The pipeline reads those streamlines and converts them into tube-like
meshes that can be rendered in 3D. Like subcortical atlases, the 2D view
comes from slicing rather than from a surface: the tubes are cut by the
slabs you choose, and each tract’s cross-section is traced into a
polygon. Stop at `steps = 1` if the meshes are all you want; the default
runs all four.

``` mermaid
flowchart TB
    A[Tractography<br/>.trk or .tck] --> B["Step 1<br/>Read streamlines<br/>Build tube meshes"]
    V[Volume<br/>tract labels] --> V1[Fit a centerline<br/>per label]
    V1 --> B
    B --> C{Stop here?}
    C -->|steps = 1| H2[ggseg_atlas<br/>3D tract meshes only]
    C -->|default| S["Steps 2-4<br/>Slice the tubes<br/>Trace contours<br/>Assemble"]
    S --> H[ggseg_atlas<br/>3D meshes + 2D slices]

    style H fill:#e1f5ff
    style H2 fill:#e1f5ff
```

Figure 5: White matter tract atlas pipeline

## Where your atlas can go

What you can plot depends on whether the atlas carries 2D geometry.
Stopping a pipeline before its 2D steps leaves a 3D-only atlas, which is
often all you need.

``` mermaid
flowchart LR
    A[ggseg_atlas] --> B{Contains 2D?}
    B -->|Yes| C[ggseg<br/>geom_brain]
    B -->|Yes| D[ggseg3d<br/>Interactive 3D]
    B -->|No<br/>3D only| D

    C --> E[ggplot2-based<br/>Static visualizations]
    D --> F[plotly-based<br/>Rotate & explore]

    style A fill:#e1f5ff
    style C fill:#c8e6c9
    style D fill:#c8e6c9
```

Figure 6: Atlas compatibility with ggseg plotting packages

## Performance

Cortical atlas creation is fast — the full pipeline (read + project)
completes in seconds because the mesh projection is pure geometry with
no external rendering. Every pipeline returns raw, unsmoothed polygons.
Shaping them is a separate step on the finished atlas:
[`atlas_polish()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_polish.md)
does the usual pair, or
[`atlas_simplify()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_simplify.md)
and
[`atlas_smooth()`](https://ggsegverse.github.io/ggseg.extra/reference/atlas_smooth.md)
separately. Because it runs on the returned object rather than during
the build, trying a different setting costs a second rather than another
pass through the pipeline.

For subcortical and tract pipelines, the `steps` argument controls how
much of the pipeline runs. Use `steps = 1:3` (subcortical) or
`steps = 1` (tract) for fast 3D-only iteration, then run the default
when you need the 2D slices.

## Where to go from here

If you’re new to ggseg.extra, start with the [Getting
Started](https://ggsegverse.github.io/ggseg.extra/articles/ggseg.extra.md)
guide, which has the shortest path from an annotation file to a plot and
a table of which pipeline reads which format. What each pipeline needs
installed is in [System
Setup](https://ggsegverse.github.io/ggseg.extra/articles/system-setup.md),
and
[`sitrep()`](https://ggsegverse.github.io/ggseg.extra/reference/sitrep.md)
reports what this machine actually has.

The [Pipeline
Configuration](https://ggsegverse.github.io/ggseg.extra/articles/pipeline-configuration.md)
article covers verbosity, intermediate files and resuming an interrupted
run.
[Post-processing](https://ggsegverse.github.io/ggseg.extra/articles/post-processing.md)
covers what to do with the atlas the pipeline hands back: dropping
regions you do not need, choosing views, and shaping the geometry. When
you’re ready to build a specific atlas type, the individual tutorials
under “Tutorials: Creating Atlases” walk through complete examples with
real data.
