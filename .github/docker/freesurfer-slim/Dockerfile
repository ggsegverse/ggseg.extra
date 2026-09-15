ARG R_VERSION=4.6.1
ARG FS_VERSION=7.4.1

FROM ubuntu:22.04 AS freesurfer
ARG FS_VERSION
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
COPY include.txt /tmp/include.txt
# Streaming extraction: only the whitelisted members ever touch disk, so the
# 16 GB full install never exists on the builder. Members in the tarball are
# prefixed (./freesurfer/...), hence the leading wildcard in include.txt.
RUN curl -sSL "https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/${FS_VERSION}/freesurfer-linux-ubuntu22_amd64-${FS_VERSION}.tar.gz" \
    | tar -xz --no-same-owner --wildcards -C /opt -T /tmp/include.txt
# lib/ is pulled in whole only so ldd can tell us which shared objects the
# retained binaries resolve from it; keep those, flattened, and drop the rest.
RUN set -e; \
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
# and magick compile against when P3M has no binary.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git pandoc curl wget jq zstd sudo \
        libgomp1 libopenblas0-openmp libglu1-mesa libgl1 \
        libxt6 libxmu6 libxext6 libxrender1 libxi6 libxss1 \
        libgdal-dev libproj-dev libgeos-dev libudunits2-dev \
        libmagick++-dev libglpk-dev libharfbuzz-dev libfribidi-dev \
        libcurl4-openssl-dev libssl-dev libxml2-dev \
        libfontconfig1-dev libfreetype6-dev libpng-dev libtiff-dev libjpeg-dev \
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
# has_magick() probes the ImageMagick 7 `magick` binary; Ubuntu 24.04 ships
# version 6, so take the official portable build and unpack it without FUSE.
ARG IMAGEMAGICK_VERSION=7.1.2-31
ARG IMAGEMAGICK_SHA256=b22dee096a68e7eb6771a6f98c16490ea78d399ffa27f34ca2ec4f02e707fd9c
RUN curl -sSL -o /tmp/magick.AppImage \
      "https://github.com/ImageMagick/ImageMagick/releases/download/${IMAGEMAGICK_VERSION}/ImageMagick-${IMAGEMAGICK_VERSION}-gcc-x86_64.AppImage" \
    && echo "${IMAGEMAGICK_SHA256}  /tmp/magick.AppImage" | sha256sum -c - \
    && chmod +x /tmp/magick.AppImage \
    && cd /opt && /tmp/magick.AppImage --appimage-extract > /dev/null \
    && mv /opt/squashfs-root /opt/imagemagick \
    && ln -s /opt/imagemagick/AppRun /usr/local/bin/magick \
    && rm /tmp/magick.AppImage \
    && magick --version | grep -q "Version: ImageMagick 7"
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
