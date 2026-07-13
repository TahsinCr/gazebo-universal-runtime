# Changelog

All notable changes to this project are documented in this file.

## [v1.1] - 2026-07-13

### Fixed

- Isolated Harmonic, Ionic, and Jetty into matching Sim / GUI / Rendering ABI families and forced the selected Sim major at runtime.
- Added image-package guards, version-specific renderer paths and caches, and 3D View readiness health checks to prevent blank central world panels.
- Installed the Qt 5 / Qt 6 SVG and Wayland runtime packages required by each collection and restored the missing Ionic SDF CLI diagnostic.

### Changed

- Made the low-latency web profile the default with a 1600x900 framebuffer, minimal VNC compression, faster noVNC pointer updates, fixed remote sizing, and Mesa threading.
- Reported Xvnc web rendering as software accurately and kept native Linux UI as the hardware-accelerated low-latency path.

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

[v1.1]: https://github.com/TahsinCr/gazebo-universal-runtime/compare/v1.0...v1.1
[v1.0]: https://github.com/TahsinCr/gazebo-universal-runtime/releases/tag/v1.0
