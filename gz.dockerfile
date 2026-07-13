# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG GAZEBO_APT_REPOSITORY=https://packages.osrfoundation.org/gazebo/ubuntu-stable

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Etc/UTC

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        tzdata \
        tini \
        tigervnc-standalone-server \
        novnc \
        websockify \
        openbox \
        dbus-x11 \
        x11-utils \
        xauth \
        mesa-utils \
        procps \
    && install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d \
    && curl -fsSL https://packages.osrfoundation.org/gazebo.gpg \
        -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
    && . /etc/os-release \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] ${GAZEBO_APT_REPOSITORY} ${VERSION_CODENAME} main" \
        > /etc/apt/sources.list.d/gazebo-stable.list \
    && apt-get update

ARG GAZEBO_PACKAGE=gz-jetty

RUN case "${GAZEBO_PACKAGE}" in \
        gz-harmonic) \
            sim_major=8; rendering_major=8; gui_major=8; \
            qt_runtime="libqt5svg5 qtwayland5"; \
            ;; \
        gz-ionic) \
            sim_major=9; rendering_major=9; gui_major=9; \
            qt_runtime="libqt5svg5 qtwayland5"; \
            ;; \
        gz-jetty) \
            sim_major=10; rendering_major=10; gui_major=10; \
            qt_runtime="libqt6svg6 qt6-wayland"; \
            ;; \
        *) \
            printf 'Unsupported GAZEBO_PACKAGE=%s. Use gz-harmonic, gz-ionic, or gz-jetty.\n' "${GAZEBO_PACKAGE}" >&2; \
            exit 64; \
            ;; \
    esac \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        "${GAZEBO_PACKAGE}" \
        ${qt_runtime} \
    && dpkg-query -W -f='${Status}\n' "gz-sim${sim_major}-cli" | grep -qx 'install ok installed' \
    && render_plugin="$(find /usr/lib -path "*/gz-rendering-${rendering_major}/engine-plugins/libgz-rendering-ogre2.so" -print -quit)" \
    && test -n "${render_plugin}" \
    && install -d -m 0755 /usr/local/share/gazebo \
    && printf 'IMAGE_GAZEBO_PACKAGE=%s\nGZ_SIM_MAJOR=%s\nGZ_RENDERING_MAJOR=%s\nGZ_GUI_MAJOR=%s\n' \
        "${GAZEBO_PACKAGE}" "${sim_major}" "${rendering_major}" "${gui_major}" \
        > /usr/local/share/gazebo/runtime-release \
    && sed -Ei 's/const MOUSE_MOVE_DELAY = [0-9]+;/const MOUSE_MOVE_DELAY = 4;/' /usr/share/novnc/core/rfb.js \
    && grep -q 'const MOUSE_MOVE_DELAY = 4;' /usr/share/novnc/core/rfb.js \
    && rm -rf /var/lib/apt/lists/*

# Ionic's collection metapackage omits the standalone SDF command package,
# while Harmonic and Jetty expose the same diagnostic through their normal
# dependency sets. Install it explicitly so `gz sdf` works for all releases.
RUN if [[ "${GAZEBO_PACKAGE}" == "gz-ionic" ]]; then \
        apt-get update \
        && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends sdformat15-cli \
        && rm -rf /var/lib/apt/lists/*; \
    fi

LABEL io.gazebo.runtime.package="${GAZEBO_PACKAGE}"

ENV HOME=/data \
    GZ_PARTITION=gazebo \
    GZ_SIM_RESOURCE_PATH=/sim/worlds:/sim/models \
    GZ_SIM_SYSTEM_PLUGIN_PATH=/sim/plugins \
    GZ_GUI_PLUGIN_PATH=/sim/plugins \
    GZ_GUI_RESOURCE_PATH=/sim/worlds:/sim/models \
    GAZEBO_WEB_GUI_TEMPLATE=/sim/gz-web-gui.config \
    GAZEBO_DISPLAY_BACKEND=web \
    GAZEBO_ARGS= \
    GAZEBO_WORLD=/sim/worlds/default.sdf \
    GAZEBO_QUICK_START=0 \
    GAZEBO_REQUIRE_3D_VIEW=1 \
    GAZEBO_REQUIRE_GPU=0 \
    GAZEBO_VERIFY_RENDERER=0 \
    WEB_LISTEN_ADDRESS=0.0.0.0 \
    WEB_PORT=6080 \
    VNC_LISTEN_ADDRESS=127.0.0.1 \
    VNC_PORT=5900 \
    VNC_DISPLAY=:1 \
    VNC_GEOMETRY=1600x900 \
    VNC_DEPTH=24 \
    VNC_PASSWORD= \
    VNC_FRAME_RATE=60 \
    VNC_COMPARE_FB=0 \
    VNC_ZLIB_LEVEL=0 \
    VNC_IMPROVED_HEXTILE=0 \
    VNC_PIXEL_FORMAT=rgb888 \
    LIBGL_ALWAYS_SOFTWARE=0 \
    MESA_GLTHREAD=true \
    QSG_RHI_BACKEND=opengl

RUN mkdir -p \
    /sim/worlds \
    /sim/models \
    /sim/plugins \
    /data/.gz \
    /data/logs

COPY gz-entrypoint.sh /usr/local/bin/gazebo
COPY gz-web-gui.config /usr/local/share/gazebo/web-gui.config
COPY index.html /usr/share/novnc/index.html
RUN chmod +x /usr/local/bin/gazebo

WORKDIR /sim

HEALTHCHECK --interval=3s --timeout=2s --start-period=20s --retries=20 \
    CMD ["/usr/local/bin/gazebo", "--healthcheck"]

ENTRYPOINT ["tini", "--", "gazebo"]
