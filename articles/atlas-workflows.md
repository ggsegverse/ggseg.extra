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
data — follows the same underlying pipeline. The trick is the `steps`
parameter, which lets you bail out early or run the full gauntlet
depending on what you need.

Step 1 reads your input file and maps it to 3D vertices on the brain
surface. That’s fast, takes about five seconds, and gives you enough to
visualize in 3D. If that’s all you need, you’re done.

The full pipeline — steps 1 through 8 — adds 2D polygon extraction. This
is where things get slower (think minutes, not seconds) because it
requires FreeSurfer and Chrome to render contours from the inflated
brain surface and flatten them into plottable geometries. The payoff is
that you get both 2D flat plots and 3D interactive visualizations from
the same atlas object.

Here’s what that fork in the road looks like:

``` mermaid
flowchart LR
    A[Input File] --> B["Step 1<br/>Read annotation<br/>&<br/>Extract vertices"]
    B --> C{Full pipeline?}
    C -->|steps = 1| D[Return 3D atlas<br/>Fast ⚡]
    C -->|steps = 1:8| E["Step 2-8<br/>Extract 2D polygons<br/>Requires FreeSurfer<br/>+ Chrome"]
    E --> F[Complete atlas<br/>3D + 2D]

    style D fill:#c8e6c9
    style F fill:#e1f5ff
```

Figure 2: Decision point in cortical atlas creation

### What happens in the full pipeline

When you run `steps = 1:8`, you’re committing to the full eight-step
process. Each step builds on the previous one, transforming your
annotation file into a complete atlas with both 3D vertex mappings and
2D polygon outlines.

Steps 1-2 handle the initial read and surface projection, making sure
your parcellation is mapped to the standard fsaverage template. Step 3
scrubs the region labels — cleaning up names, handling duplicates,
making everything consistent. Steps 4-5 extract and smooth contours on
the inflated surface, which is where the actual polygon boundaries get
defined. Step 6 flattens those 3D contours into 2D coordinates. Steps
7-8 add the medial wall (background regions) and combine everything into
the final atlas object.

The whole sequence looks like this:

``` mermaid
flowchart TB
    Start[Input annotation] --> S1["Step 1: Read & Extract<br/>Read annotation labels<br/>Map to brain vertices"]
    S1 --> S2["Step 2: Project to Surface<br/>mri_surf2surf reregistration<br/>Map to fsaverage"]
    S2 --> S3["Step 3: Scrub Labels<br/>Clean region names<br/>Handle duplicates"]
    S3 --> S4["Step 4: Create Contours<br/>Extract region boundaries<br/>on inflated surface"]
    S4 --> S5["Step 5: Smooth Contours<br/>Simplify polygon geometry<br/>Reduce vertices"]
    S5 --> S6["Step 6: Convert to 2D<br/>Flatten 3D coordinates<br/>to x-y plane"]
    S6 --> S7["Step 7: Medial Wall<br/>Add background regions<br/>for complete coverage"]
    S7 --> S8["Step 8: Finalize<br/>Combine hemispheres<br/>Add metadata"]
    S8 --> Output[ggseg_atlas<br/>3D + 2D]

    style S1 fill:#fff9c4
    style S2 fill:#fff9c4
    style S3 fill:#ffe0b2
    style S4 fill:#ffe0b2
    style S5 fill:#ffe0b2
    style S6 fill:#c8e6c9
    style S7 fill:#c8e6c9
    style S8 fill:#e1f5ff
    style Output fill:#e1f5ff
```

Figure 3: Complete eight-step cortical atlas pipeline

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

Figure 4: Subcortical and whole-brain volumetric atlas pipeline

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

Figure 5: White matter tract atlas pipeline

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

Figure 6: Atlas compatibility with ggseg plotting packages

## The speed-versus-completeness tradeoff

The neat thing about the `steps` parameter is you get to pick how much
work the pipeline does. The annoying thing about the `steps` parameter
is you get to pick.

If you only need 3D visualization, running `steps = 1` gets you there in
seconds. The atlas object you get back is complete for 3D purposes — it
has all the vertex mappings, all the region labels, all the metadata. It
just doesn’t have 2D polygon outlines, which means ggseg can’t use it
for flat brain plots.

If you need 2D plots, you have to run the full `steps = 1:8` pipeline,
which means you need FreeSurfer and Chrome installed, and you need to
wait a couple of minutes while the pipeline extracts, smooths, and
flattens contours. It’s slower because it’s doing real geometric
computation — tracing region boundaries on a 3D surface and projecting
them onto a 2D plane.

Most of the time, you’ll know which one you need. If you’re prototyping
or exploring data interactively, start with step 1. If you’re preparing
publication-quality figures that need flat brain diagrams, bite the
bullet and run the full pipeline.

``` mermaid
flowchart TB
    A{Need 2D plots?} -->|No| B["Use steps = 1<br/>⚡ Fast: ~5 seconds<br/>✓ 3D visualization only"]
    A -->|Yes| C{Have FreeSurfer<br/>+ Chrome?}
    C -->|No| D[Install dependencies<br/>See system-setup vignette]
    C -->|Yes| E["Use steps = 1:8<br/>⏱️ Slow: ~2-5 minutes<br/>✓ Full 2D + 3D"]

    D --> E

    style B fill:#c8e6c9
    style E fill:#fff9c4
```

Figure 7: Performance decision tree for cortical atlases

## Where to go from here

If you’re new to ggseg.extra, start with the [Getting
Started](https://ggsegverse.github.io/ggseg.extra/articles/ggseg.extra.md)
guide for installation and basic usage. Before running the full pipeline
for any cortical atlas, check [System
Setup](https://ggsegverse.github.io/ggseg.extra/articles/system-setup.md)
to make sure you have FreeSurfer and Chrome configured correctly — those
dependencies are required for 2D polygon extraction.

The [Pipeline
Configuration](https://ggsegverse.github.io/ggseg.extra/articles/pipeline-configuration.md)
article covers how to customize the creation process, including options
for controlling smoothing, contour extraction, and other pipeline
parameters. When you’re ready to build a specific atlas type, the
individual tutorials under “Tutorials: Creating Atlases” walk through
complete examples with real data.
