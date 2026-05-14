[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]
[![LinkedIn][linkedin-shield]][linkedin-url]
[![Docker Compose][docker-shield]][docker-url]
[![Gazebo Sim][gazebo-shield]][gazebo-url]
[![Gazebo Jetty][gazebo-jetty-shield]][gazebo-url]
[![Gazebo Harmonic][gazebo-harmonic-shield]][gazebo-url]
[![Gazebo Ionic][gazebo-ionic-shield]][gazebo-url]
[![Ubuntu 24.04][ubuntu-shield]][ubuntu-url]

[English][lang-en-url] | [Türkçe][lang-tr-url] | [Русский][lang-ru-url]

<div align="center">

<h3 align="center">Gazebo Universal Runtime</h3>

<p align="center">
Universal, full-GUI Gazebo Sim runtime for robotics and autonomous systems projects.
</p>

<p align="center">
One image. One container. Browser UI by default. Native Linux UI when needed. Project files stay in your repository.
</p>

</div>

<br/>

## Quick Start

The only required dependency for normal use is Docker. Use a recent Docker installation with the modern `docker compose` command. Docker Desktop already includes Compose on Windows and macOS.

```bash
git clone https://github.com/TahsinCr/gazebo-universal-runtime.git
cd gazebo-universal-runtime
cp .env.example .env
./start-gazebo.sh web
```

Open:

```text
http://localhost:6080/
```

Stop:

```bash
./stop-gazebo.sh
```

Windows:

```bat
copy .env.example .env
start-gazebo.bat
```

macOS:

```bash
cp .env.example .env
./start-gazebo.sh web
```

## What It Is

Gazebo Universal Runtime is a reusable Docker base for running Gazebo Sim with a graphical interface. It is designed for robotics, autonomous systems, drones, mobile robots, manipulation, simulation demos, education, and research projects.

The image is intentionally a full Gazebo runtime:

```bash
gz sim ${GAZEBO_ARGS} <world>
```

The default world is included so a fresh clone can start immediately:

```text
worlds/default.sdf -> /sim/worlds/default.sdf
```

Project assets are not baked into the image. Worlds, models, plugins, GUI configuration, web UI, cache, and logs stay outside the image and are mounted at runtime.

## Scope

| Included | Not included |
| --- | --- |
| Full Gazebo package, default `gz-jetty` | ROS, PX4, ArduPilot, QGroundControl, Mission Planner |
| Browser-based Gazebo UI | Project-specific simulation servers |
| Optional native Linux UI | Split server-only and GUI-only container architecture |
| GPU-aware startup scripts | Hardcoded robot, world, model, or plugin assets |
| `.env` based configuration | Runtime logs or cache baked into the image |

This keeps the repository useful as a general Gazebo foundation instead of a one-project image.

## Choose A Mode

| Platform | Recommended mode | Notes |
| --- | --- | --- |
| Linux | `ui` or `web` | Use `ui` for the lowest local latency. Use `web` for the easiest portable path. X11 or Wayland access is only needed for native UI modes. |
| Windows | `web` | Web mode works through Docker Desktop. Native Linux UI is a WSL/Linux workflow, not a browser-mode requirement. |
| macOS | `web` | Docker Desktop on macOS does not expose native Linux OpenGL acceleration to Linux containers. Web mode is the portable path. |

| Mode | Command | Best for |
| --- | --- | --- |
| `web` | `./start-gazebo.sh web` | Browser access, demos, cross-platform use, easiest onboarding. |
| `ui` | `./start-gazebo.sh ui` | Native Linux UI with automatic X11 or Wayland session selection. |
| `x11` | `./start-gazebo.sh x11` | Force X11 on Linux. |
| `wayland` | `./start-gazebo.sh wayland` | Force Wayland session mode; XWayland is used by default for Gazebo 3D stability. |

Common examples:

```bash
./start-gazebo.sh web
./start-gazebo.sh ui
./start-gazebo.sh web worlds/my_world.sdf
./start-gazebo.sh x11 worlds/my_world.sdf
./start-gazebo.sh wayland worlds/my_world.sdf
GAZEBO_QUICK_START=1 ./start-gazebo.sh web
```

## Project Layout

```text
project/
├── .env.example
├── docker-compose.yml
├── gz.dockerfile
├── gz-entrypoint.sh
├── gz-web-gui.config
├── index.html
├── start-gazebo.sh
├── stop-gazebo.sh
├── start-gazebo.bat
├── stop-gazebo.bat
├── start-gazebo.command
├── stop-gazebo.command
├── worlds/
├── models/
├── plugins/
└── data/
```

| Host path | Container path | Purpose |
| --- | --- | --- |
| `./worlds` | `/sim/worlds` | SDF world files. |
| `./models` | `/sim/models` | Gazebo models, meshes, textures, materials, and `model.config` files. |
| `./plugins` | `/sim/plugins` | Custom Gazebo system or GUI plugin `.so` files. |
| `./gz-web-gui.config` | `/sim/gz-web-gui.config` | Gazebo GUI layout used by web mode. |
| `./index.html` | `/usr/share/novnc/index.html` | Browser console UI served by noVNC. |
| `./data` | `/data` | Gazebo cache, logs, Fuel downloads, and runtime data. |

The root `gz-web-gui.config` and `index.html` files are mounted directly into the container, so they can be edited without rebuilding the image.

## Worlds, Models, And Plugins

Put world files under `worlds/`:

```bash
./start-gazebo.sh web worlds/my_world.sdf
```

Use normal Gazebo model URIs inside worlds:

```xml
<include>
  <uri>model://my_robot</uri>
</include>
```

Put models under `models/`:

```text
models/my_robot/
├── model.config
├── model.sdf
└── meshes/
```

Put custom plugin binaries under `plugins/`. They must be compiled for the Gazebo package and Ubuntu version used by this image.

Default runtime paths:

```text
GZ_SIM_RESOURCE_PATH=/sim/worlds:/sim/models
GZ_SIM_SYSTEM_PLUGIN_PATH=/sim/plugins
GZ_GUI_PLUGIN_PATH=/sim/plugins
GZ_GUI_RESOURCE_PATH=/sim/worlds:/sim/models
GAZEBO_WEB_GUI_TEMPLATE=/sim/gz-web-gui.config
```

## Configuration

Copy `.env.example` to `.env` and edit only what you need:

```bash
cp .env.example .env
```

Most users only touch these values:

| Variable | Default | Use |
| --- | --- | --- |
| `GAZEBO_PACKAGE` | `gz-jetty` | Full Gazebo package. Supported options: `gz-jetty`, `gz-harmonic`, `gz-ionic`. |
| `UBUNTU_VERSION` | `24.04` | Recommended Ubuntu base image version. |
| `GAZEBO_WORLD` | `/sim/worlds/default.sdf` | Startup world. |
| `GAZEBO_ARGS` | `-v 2` | Simple flags passed to `gz sim`. |
| `WEB_PORT` | `6080` | Browser UI port. |
| `WEB_BIND_ADDRESS` | `127.0.0.1` | Host bind address for web mode. |
| `VNC_GEOMETRY` | `1920x1080` | Web-mode virtual desktop resolution. |
| `GAZEBO_WEB_PROFILE` | `balanced` | Web stream profile: `fast`, `balanced`, or `quality`. |
| `GAZEBO_GPU_MODE` | `auto` | GPU path: `auto`, `nvidia`, `dxg`, `dri`, or `software`. |
| `GAZEBO_VERIFY_RENDERER` | `0` | Fail startup if OpenGL falls back to software rendering. |

Recommended default: `GAZEBO_PACKAGE=gz-jetty` with `UBUNTU_VERSION=24.04`.

Build-time options:

```bash
GAZEBO_PACKAGE=gz-jetty docker compose build gazebo
GAZEBO_PACKAGE=gz-harmonic docker compose build gazebo
GAZEBO_PACKAGE=gz-ionic docker compose build gazebo
UBUNTU_VERSION=24.04 docker compose build gazebo
```

## Web UI And Performance

Web mode runs Gazebo through:

```text
Gazebo GUI -> TigerVNC -> websockify -> noVNC -> Browser
```

It is the most portable mode, but it is still a streamed desktop. Even on the same machine, native Linux UI can feel smoother because web mode captures, encodes, transports, decodes, and paints frames in the browser.

Tune the web stream:

```bash
GAZEBO_WEB_PROFILE=fast ./start-gazebo.sh web
GAZEBO_WEB_PROFILE=quality ./start-gazebo.sh web
VNC_GEOMETRY=1600x900 ./start-gazebo.sh web
```

Security note:

```env
WEB_BIND_ADDRESS=127.0.0.1
```

Keep localhost binding unless you intentionally want other machines on the network to access the web UI.

## GPU Support

The launcher tries to use the strongest supported GPU path exposed by Docker:

```text
NVIDIA Docker runtime
WSL /dev/dxg
AMD / Intel DRI render node
software fallback
```

In native Linux UI modes, NVIDIA is preferred when Docker exposes a working NVIDIA runtime. In web mode, `auto` avoids forcing NVIDIA under VNC because some hosts cannot create a stable NVIDIA GLX context inside the virtual display. If your host supports it reliably, force it with `GAZEBO_GPU_MODE=nvidia`.

When a GPU path is found, `start-gazebo.sh` writes a local override file:

```text
.gazebo/gpu.compose.yml
```

This file is machine-specific and ignored by git.

Force a mode:

```bash
GAZEBO_GPU_MODE=nvidia ./start-gazebo.sh web
GAZEBO_GPU_MODE=dri ./start-gazebo.sh ui
GAZEBO_GPU_MODE=dxg ./start-gazebo.sh web
GAZEBO_GPU_MODE=software ./start-gazebo.sh web
```

Verify NVIDIA Docker support:

```bash
docker run --rm --gpus all ubuntu nvidia-smi
```

Verify renderer selection:

```bash
GAZEBO_VERIFY_RENDERER=1 ./start-gazebo.sh ui
```

## Technical Architecture

| File | Role |
| --- | --- |
| `gz.dockerfile` | Builds Ubuntu plus full Gazebo, noVNC, TigerVNC, websockify, Qt/Wayland, Mesa tools, and runtime utilities. |
| `gz-entrypoint.sh` | Prepares the selected display backend and executes `gz sim`. |
| `docker-compose.yml` | Defines the web service, native UI profile, mounts, environment, and ports. |
| `start-gazebo.sh` | Handles `.env`, GPU detection, mode selection, permissions, and startup. |
| `start-gazebo.bat` | Provides the Windows web-mode launcher. |

Entrypoint behavior:

```text
prepare display backend
prepare web GUI config when needed
split simple GAZEBO_ARGS flags
exec gz sim ${GAZEBO_ARGS} <world>
```

There is no server-only mode, GUI-only mode, `ign` fallback, or project-specific command automation.

## Troubleshooting

| Problem | First check |
| --- | --- |
| Web UI does not open | `docker compose logs --tail=200 gazebo` |
| World fails to load | `docker run --rm -v "$PWD/worlds:/sim/worlds:ro" --entrypoint gz gazebo-universal-runtime:local sdf -k /sim/worlds/default.sdf` |
| NVIDIA is not used | `docker run --rm --gpus all ubuntu nvidia-smi` |
| Native UI does not open | Check `DISPLAY`, `/tmp/.X11-unix`, `WAYLAND_DISPLAY`, and `XDG_RUNTIME_DIR`. |
| Web mode feels slow | Try `GAZEBO_WEB_PROFILE=fast` or lower `VNC_GEOMETRY`. |
| Wayland 3D is unstable | Keep the default XWayland path, or test `GAZEBO_WAYLAND_NATIVE=1`. |

Useful commands:

```bash
docker compose logs --tail=200 gazebo
docker compose --profile ui logs --tail=200 gazebo-ui
docker compose ps
./stop-gazebo.sh
```


## 📫 Contact

X: [@TahsinCrs][x-url]

LinkedIn: [@TahsinCr][linkedin-url]

Email: TahsinCrs@gmail.com

## License

Distributed under the MIT License. See [LICENSE](LICENSE).

<!-- Images URL -->

[contributors-shield]: https://img.shields.io/github/contributors/TahsinCr/gazebo-universal-runtime.svg?style=for-the-badge
[forks-shield]: https://img.shields.io/github/forks/TahsinCr/gazebo-universal-runtime.svg?style=for-the-badge
[stars-shield]: https://img.shields.io/github/stars/TahsinCr/gazebo-universal-runtime.svg?style=for-the-badge
[issues-shield]: https://img.shields.io/github/issues/TahsinCr/gazebo-universal-runtime.svg?style=for-the-badge
[license-shield]: https://img.shields.io/github/license/TahsinCr/gazebo-universal-runtime.svg?style=for-the-badge
[linkedin-shield]: https://img.shields.io/badge/LinkedIn-TahsinCr-0A66C2.svg?style=for-the-badge&logo=linkedin&logoColor=white
[docker-shield]: https://img.shields.io/badge/Docker-Compose-2496ED.svg?style=for-the-badge&logo=docker&logoColor=white
[docker-url]: https://docs.docker.com/compose/
[gazebo-shield]: https://img.shields.io/badge/Gazebo-Sim-F58113.svg?style=for-the-badge
[gazebo-jetty-shield]: https://img.shields.io/badge/Gazebo-gz--jetty-F58113.svg?style=for-the-badge
[gazebo-harmonic-shield]: https://img.shields.io/badge/Gazebo-gz--harmonic-F58113.svg?style=for-the-badge
[gazebo-ionic-shield]: https://img.shields.io/badge/Gazebo-gz--ionic-F58113.svg?style=for-the-badge
[gazebo-url]: https://gazebosim.org/
[ubuntu-shield]: https://img.shields.io/badge/Ubuntu-24.04-E95420.svg?style=for-the-badge&logo=ubuntu&logoColor=white
[ubuntu-url]: https://ubuntu.com/

<!-- Github Project URL -->

[project-url]: https://github.com/TahsinCr/gazebo-universal-runtime
[contributors-url]: https://github.com/TahsinCr/gazebo-universal-runtime/graphs/contributors
[stars-url]: https://github.com/TahsinCr/gazebo-universal-runtime/stargazers
[forks-url]: https://github.com/TahsinCr/gazebo-universal-runtime/network/members
[issues-url]: https://github.com/TahsinCr/gazebo-universal-runtime/issues
[license-url]: https://github.com/TahsinCr/gazebo-universal-runtime/blob/main/LICENSE

<!-- Contacts URL -->

[linkedin-url]: https://linkedin.com/in/TahsinCr
[x-url]: https://twitter.com/TahsinCrs

<!-- File URL -->

[lang-tr-url]: https://github.com/TahsinCr/gazebo-universal-runtime/blob/main/README_tr.md
[lang-en-url]: https://github.com/TahsinCr/gazebo-universal-runtime/blob/main/README.md
[lang-ru-url]: https://github.com/TahsinCr/gazebo-universal-runtime/blob/main/README_ru.md
