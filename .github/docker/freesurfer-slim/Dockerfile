ARG R_VERSION=4.5.3
ARG FS_VERSION=7.4.1

FROM ubuntu:22.04 AS freesurfer
ARG FS_VERSION
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
COPY include.txt /tmp/include.txt
# Streaming extraction: only the whitelisted members ever touch disk, so the
# 16 GB full install never exists on the builder.
RUN curl -sSL "https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/${FS_VERSION}/freesurfer-linux-ubuntu22_amd64-${FS_VERSION}.tar.gz" \
    | tar -xz --no-same-owner -C /opt -T /tmp/include.txt \
    && du -sh /opt/freesurfer /opt/freesurfer/lib /opt/freesurfer/subjects
# lib/ is pulled in whole only so ldd can tell us which shared objects the
# retained binaries resolve from it; keep those and drop the rest.
RUN set -e; \
    libdirs="$(find /opt/freesurfer/lib -name '*.so*' -printf '%h\n' | sort -u | paste -sd:)"; \
    mkdir -p /opt/fs-keep; \
    for b in /opt/freesurfer/bin/*; do \
      LD_LIBRARY_PATH="$libdirs" ldd "$b" 2>/dev/null || true; \
    done | awk '$3 ~ /^\/opt\/freesurfer\/lib\// {print $3}' | sort -u | tee /opt/fs-keep/manifest.txt \
    | xargs -r -I{} cp -a {} /opt/fs-keep/; \
    rm -rf /opt/freesurfer/lib && mkdir /opt/freesurfer/lib \
    && cp -a /opt/fs-keep/. /opt/freesurfer/lib/ && rm -rf /opt/fs-keep \
    && du -sh /opt/freesurfer

FROM rocker/r-ver:${R_VERSION}
ARG FS_VERSION
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bc tcsh perl git pandoc \
        libgomp1 libopenblas0-openmp libglu1-mesa libgl1 \
        libxt6 libxmu6 libxext6 libxrender1 libxi6 libxss1 \
        libgdal-dev libproj-dev libgeos-dev libudunits2-dev \
        libmagick++-dev libglpk-dev libharfbuzz-dev libfribidi-dev \
        libcurl4-openssl-dev libssl-dev libxml2-dev \
        libfontconfig1-dev libfreetype6-dev libpng-dev libtiff-dev libjpeg-dev \
    && rm -rf /var/lib/apt/lists/*
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
    && mri_info --version && mri_convert --version \
    && test -f /opt/freesurfer/subjects/fsaverage5/surf/lh.white \
    && test -f /opt/freesurfer/average/mni152.register.dat \
    && du -sh /opt/freesurfer
LABEL org.opencontainers.image.source="https://github.com/ggsegverse/ggseg.extra" \
      org.opencontainers.image.description="rocker/r-ver plus the FreeSurfer ${FS_VERSION} subset ggseg.extra shells out to" \
      org.opencontainers.image.licenses="MIT AND LicenseRef-FreeSurfer"
CMD ["bash"]
