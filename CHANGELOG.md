# Changelog

All notable changes to this project are documented in this file.

## [v1.0] - 2026-05-14

### Added

- Added a universal full-GUI Gazebo Sim Docker runtime designed for robotics, autonomous systems, simulation demos, education, and research projects.
- Added a single-container runtime model that always launches Gazebo with `gz sim` instead of server-only, GUI-only, or split-container modes.
- Added build-time support for full Gazebo packages: `gz-jetty` by default, plus `gz-harmonic` and `gz-ionic`.
- Added Ubuntu base image configuration with `UBUNTU_VERSION=24.04` as the recommended default.
- Added browser-based web mode using TigerVNC, websockify, noVNC, Openbox, and a custom fullscreen web interface.
- Added configurable web stream profiles and VNC settings for balancing latency, visual quality, and FPS.
- Added native Linux UI support through X11 and Wayland backends.
- Added GPU selection logic for NVIDIA Container Toolkit/CDI, WSLg/DXG, Intel/AMD DRI devices, and safe software fallback paths.
- Added cross-platform launcher and stop scripts for Linux, macOS, and Windows.
- Added a standard project volume layout for `worlds`, `models`, `plugins`, and `data` so project assets remain outside the image.
- Added a valid default world file so a fresh clone can start immediately.
- Added `.env.example` for quick configuration of Gazebo package, Ubuntu version, world path, web settings, GPU mode, and runtime paths.
- Added Docker Compose configuration with web mode as the default and a native UI profile for Linux systems.
- Added English, Turkish, and Russian README files with usage paths, platform notes, configuration details, troubleshooting, and contact links.
- Added MIT License metadata and GitHub badges for repository status, Docker Compose, Gazebo Sim versions, and Ubuntu 24.04.

[v1.0]: https://github.com/TahsinCr/gazebo-universal-runtime/releases/tag/v1.0
