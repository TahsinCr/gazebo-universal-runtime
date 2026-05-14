# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=24.04

FROM ubuntu:${UBUNTU_VERSION}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG GAZEBO_APT_REPOSITORY=https://packages.osrfoundation.org/gazebo/ubuntu-stable
ARG GAZEBO_PACKAGE=gz-jetty

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
        qt6-wayland \
    && install -d -m 0755 /usr/share/keyrings /etc/apt/sources.list.d \
    && curl -fsSL https://packages.osrfoundation.org/gazebo.gpg \
        -o /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
    && . /etc/os-release \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] ${GAZEBO_APT_REPOSITORY} ${VERSION_CODENAME} main" \
        > /etc/apt/sources.list.d/gazebo-stable.list \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ${GAZEBO_PACKAGE} \
    && sed -i 's/const MOUSE_MOVE_DELAY = 17;/const MOUSE_MOVE_DELAY = 8;/' /usr/share/novnc/core/rfb.js \
    && rm -rf /var/lib/apt/lists/*

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
    GAZEBO_REQUIRE_GPU=0 \
    GAZEBO_VERIFY_RENDERER=0 \
    WEB_LISTEN_ADDRESS=0.0.0.0 \
    WEB_PORT=6080 \
    VNC_LISTEN_ADDRESS=127.0.0.1 \
    VNC_PORT=5900 \
    VNC_DISPLAY=:1 \
    VNC_GEOMETRY=1920x1080 \
    VNC_DEPTH=24 \
    VNC_PASSWORD= \
    VNC_FRAME_RATE=60 \
    VNC_COMPARE_FB=2 \
    VNC_ZLIB_LEVEL=1 \
    VNC_PIXEL_FORMAT=rgb888 \
    LIBGL_ALWAYS_SOFTWARE=0 \
    QT_X11_NO_MITSHM=1 \
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

ENTRYPOINT ["tini", "--", "gazebo"]
