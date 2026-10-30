ARG R_VERSION=4.6.1
ARG FS_VERSION=7.4.1

FROM ubuntu:22.04 AS freesurfer
ARG FS_VERSION
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl zstd \
    && rm -rf /var/lib/apt/lists/*
COPY include.txt require.txt /tmp/
# Streaming extraction: only the whitelisted members ever touch disk, so the
# full install (16 GB for 7.4.1, 9.6 GB compressed for 8.2.0) never exists on
# the builder. include.txt holds paths relative to FREESURFER_HOME, because
# the two source formats disagree about what comes before them, and `tar -T`
# has no comment syntax -- every line is a pattern -- so notes belong here.
# The one entry that is not obvious is trctrain/hcp/mgh_1017/mni: the single
# training subject the tract tutorial builds from, 42 MB of a 1.3 GB tree.
# lib/ is pulled in whole only so ldd can say which shared objects the
# retained binaries resolve from it; the next step keeps those and drops the
# rest.
#
# 7.x ships a tarball whose members are ./freesurfer/<path>. 8.x ships no
# tarball at all, only .deb and .rpm, so 8.x reads the .deb: an ar archive
# whose data.tar.zst is an ordinary tar, under ./usr/local/freesurfer/<ver>/.
# Finding that member means walking the ar headers, each fetched as its own
# 60-byte range request before the body is streamed from the offset they
# work out to. Prefetching one block instead does not work: control.tar.zst
# is 1.5 MB in 8.2.0, so the header that matters sits at byte 1541120, and
# any fixed window small enough to be worth prefetching misses it.
#
# tar exits 2 when a pattern matches nothing, which is not fatal here:
# build-stamp.txt exists in 7.x and not in every later release. Only 2 is
# tolerated, never any other status, and require.txt is then checked path by
# path -- so a whitelist entry that silently stops matching fails the build
# rather than quietly shrinking the image.
RUN set -euo pipefail; \
    base="https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/${FS_VERSION}"; \
    mkdir -p /tmp/stage; \
    case "$FS_VERSION" in \
      7.*) \
        sed 's|^|*freesurfer/|' /tmp/include.txt > /tmp/patterns.txt; \
        url="${base}/freesurfer-linux-ubuntu22_amd64-${FS_VERSION}.tar.gz"; \
        decomp="--gzip"; \
        home="/tmp/stage/freesurfer"; \
        skip=0; \
        ;; \
      *) \
        sed "s|^|*freesurfer/${FS_VERSION}/|" /tmp/include.txt > /tmp/patterns.txt; \
        url="${base}/freesurfer_ubuntu22-${FS_VERSION}_amd64.deb"; \
        decomp="--zstd"; \
        home="/tmp/stage/usr/local/freesurfer/${FS_VERSION}"; \
        off=8; \
        while :; do \
          name="$(curl -sSf -r "${off}-$((off + 15))" "$url" | tr -d ' ')"; \
          size="$(curl -sSf -r "$((off + 48))-$((off + 57))" "$url" | tr -d ' ')"; \
          data="$((off + 60))"; \
          if [ -z "$name" ]; then echo "no data member in $url" >&2; exit 1; fi; \
          echo "ar member ${name} size=${size}"; \
          case "$name" in data.tar*) skip="$data"; break;; esac; \
          off="$((data + size + size % 2))"; \
        done; \
        echo "data member starts at byte $skip"; \
        ;; \
    esac; \
    status=0; \
    curl -sSL -r "${skip}-" "$url" \
      | tar -x $decomp --no-same-owner --wildcards -C /tmp/stage -T /tmp/patterns.txt \
      || status=$?; \
    if [ "$status" -ne 0 ] && [ "$status" -ne 2 ]; then exit "$status"; fi; \
    test -d "$home" || { echo "nothing extracted to $home" >&2; exit 1; }; \
    mv "$home" /opt/freesurfer; \
    missing=0; \
    while read -r path; do \
      [ -n "$path" ] || continue; \
      if [ ! -e "/opt/freesurfer/$path" ]; then \
        echo "missing required path: $path" >&2; missing=1; \
      fi; \
    done < /tmp/require.txt; \
    [ "$missing" -eq 0 ] || exit 1
RUN set -euo pipefail; \
    mv /opt/freesurfer/lib /tmp/lib && mkdir /opt/freesurfer/lib; \
    libdirs="$(find /tmp/lib -name '*.so*' -printf '%h\n' | sort -u | paste -sd:)"; \
    LD_LIBRARY_PATH="$libdirs" ldd /opt/freesurfer/bin/* 2>/dev/null \
      | awk '$3 ~ /^\/tmp\/lib\// {print $3}' | sort -u \
      | xargs -r cp -a -t /opt/freesurfer/lib; \
    rm -rf /tmp/lib \
    && du -sh /opt/freesurfer

FROM rocker/r-ver:${R_VERSION}
ARG FS_VERSION
ARG R_VERSION
ENV DEBIAN_FRONTEND=noninteractive
# curl, wget, jq, zstd and sudo are what r-lib/actions/setup-r-dependencies
# shells out to inside a container job; the -dev libraries are what sf, terra
# and rgl compile against when P3M has no binary. The rule for that list is
# that some package in the dependency tree names the library in its
# SystemRequirements, optional or not - which is why libpng and FreeType stay
# (rgl names both) and ImageMagick, harfbuzz, fribidi, fontconfig, tiff and
# jpeg are gone with the font and raster packages that used to pull them.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git pandoc curl wget jq zstd sudo \
        libgomp1 libopenblas0-openmp libglu1-mesa libgl1 \
        libxt6 libxmu6 libxext6 libxrender1 libxi6 libxss1 \
        libgdal-dev libproj-dev libgeos-dev libudunits2-dev \
        libglpk-dev libcurl4-openssl-dev libssl-dev libxml2-dev \
        libfreetype6-dev libpng-dev \
    && rm -rf /var/lib/apt/lists/*
# rocker pins CRAN to the snapshot current at its R release, which strands
# packages published since; track the rolling snapshot like the other runners.
# ggsegverse packages come from the org's r-universe. pak prefers binaries
# over source regardless of repository order, and P3M serves Linux binaries,
# so the universe's own noble binary tree is used rather than its source root.
ENV CRAN=https://p3m.dev/cran/__linux__/noble/latest
RUN GGSEGVERSE="https://ggsegverse.r-universe.dev/bin/linux/noble-x86_64/${R_VERSION%.*}" \
    && curl -sSf -o /dev/null "${GGSEGVERSE}/src/contrib/PACKAGES" \
    && echo "options(repos = c(ggsegverse = '${GGSEGVERSE}', CRAN = '${CRAN}'))" \
         >> /usr/local/lib/R/etc/Rprofile.site
COPY --from=freesurfer /opt/freesurfer /opt/freesurfer
ENV OS=Linux \
    FS_OVERRIDE=0 \
    FSF_OUTPUT_FORMAT=nii.gz \
    FREESURFER_HOME=/opt/freesurfer \
    SUBJECTS_DIR=/opt/freesurfer/subjects \
    LD_LIBRARY_PATH=/opt/freesurfer/lib \
    PATH=/opt/freesurfer/bin:$PATH \
    RGL_USE_NULL=true
RUN set -e; \
    for b in /opt/freesurfer/bin/*; do \
      if ldd "$b" | grep -q 'not found'; then \
        echo "unresolved libraries in $b:"; ldd "$b" | grep 'not found'; exit 1; \
      fi; \
    done \
    && test -f /opt/freesurfer/subjects/fsaverage5/surf/lh.white \
    && test -f /opt/freesurfer/average/mni152.register.dat
LABEL org.opencontainers.image.source="https://github.com/ggsegverse/ggseg.extra" \
      org.opencontainers.image.description="rocker/r-ver plus the FreeSurfer ${FS_VERSION} subset ggseg.extra shells out to" \
      org.opencontainers.image.licenses="MIT AND LicenseRef-FreeSurfer"
CMD ["bash"]
