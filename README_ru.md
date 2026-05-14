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
Универсальная среда выполнения Gazebo Sim с полноценным графическим интерфейсом для робототехники и автономных систем.
</p>

<p align="center">
Один image. Один container. По умолчанию браузерный интерфейс. При необходимости native Linux UI. Файлы проекта остаются в репозитории.
</p>

</div>

<br/>

## Быстрый старт

Для обычного использования требуется только Docker. Нужна актуальная установка Docker с современной командой `docker compose`. Docker Desktop уже включает Compose на Windows и macOS.

```bash
git clone https://github.com/TahsinCr/gazebo-universal-runtime.git
cd gazebo-universal-runtime
cp .env.example .env
./start-gazebo.sh web
```

Открой:

```text
http://localhost:6080/
```

Остановить:

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

## Что это такое

Gazebo Universal Runtime — это переиспользуемая Docker-основа для запуска Gazebo Sim с графическим интерфейсом. Она предназначена для проектов в робототехнике, автономных системах, дронах, мобильных роботах, манипуляторах, симуляционных демо, образовании и исследованиях.

Image намеренно является full Gazebo runtime:

```bash
gz sim ${GAZEBO_ARGS} <world>
```

В репозитории есть world по умолчанию, поэтому свежий clone может запуститься сразу:

```text
worlds/default.sdf -> /sim/worlds/default.sdf
```

Файлы проекта не встраиваются в image. Worlds, models, plugins, GUI configuration, web UI, cache и logs остаются вне image и подключаются во время запуска через mount.

## Область применения

| Включено | Не включено |
| --- | --- |
| Полный пакет Gazebo, по умолчанию `gz-jetty` | ROS, PX4, ArduPilot, QGroundControl, Mission Planner |
| Браузерный Gazebo UI | Специфичные для проекта simulation servers |
| Опциональный native Linux UI | Архитектура с отдельными server-only и GUI-only containers |
| GPU-aware startup scripts | Жёстко заданные robot, world, model или plugin assets |
| Настройка через `.env` | Runtime logs или cache, встроенные в image |

Такой подход сохраняет репозиторий как универсальную основу для Gazebo, а не как image для одного конкретного проекта.

## Выбор режима

| Платформа | Рекомендуемый режим | Примечание |
| --- | --- | --- |
| Linux | `ui` или `web` | Используй `ui` для минимальной локальной задержки. Используй `web` для самого простого переносимого пути. Доступ к X11 или Wayland нужен только для native UI modes. |
| Windows | `web` | Web mode работает через Docker Desktop. Native Linux UI — это workflow через WSL/Linux, он не требуется для browser mode. |
| macOS | `web` | Docker Desktop на macOS не предоставляет Linux containers native Linux OpenGL acceleration. Переносимый путь — web mode. |

| Режим | Команда | Лучше всего подходит для |
| --- | --- | --- |
| `web` | `./start-gazebo.sh web` | Browser access, demos, cross-platform use, самый простой старт. |
| `ui` | `./start-gazebo.sh ui` | Native Linux UI с автоматическим выбором X11 или Wayland session. |
| `x11` | `./start-gazebo.sh x11` | Принудительное использование X11 на Linux. |
| `wayland` | `./start-gazebo.sh wayland` | Принудительный Wayland session mode; по умолчанию используется XWayland для стабильности Gazebo 3D. |

Частые примеры:

```bash
./start-gazebo.sh web
./start-gazebo.sh ui
./start-gazebo.sh web worlds/my_world.sdf
./start-gazebo.sh x11 worlds/my_world.sdf
./start-gazebo.sh wayland worlds/my_world.sdf
GAZEBO_QUICK_START=1 ./start-gazebo.sh web
```

## Структура проекта

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

| Host path | Container path | Назначение |
| --- | --- | --- |
| `./worlds` | `/sim/worlds` | SDF world files. |
| `./models` | `/sim/models` | Gazebo models, meshes, textures, materials и `model.config` files. |
| `./plugins` | `/sim/plugins` | Custom Gazebo system или GUI plugin `.so` files. |
| `./gz-web-gui.config` | `/sim/gz-web-gui.config` | Gazebo GUI layout для web mode. |
| `./index.html` | `/usr/share/novnc/index.html` | Browser console UI, обслуживаемый noVNC. |
| `./data` | `/data` | Gazebo cache, logs, Fuel downloads и runtime data. |

Файлы `gz-web-gui.config` и `index.html` из корня репозитория монтируются напрямую в container, поэтому их можно менять без rebuild image.

## Worlds, Models и Plugins

Помещай world files в `worlds/`:

```bash
./start-gazebo.sh web worlds/my_world.sdf
```

Внутри world можно использовать обычные Gazebo model URI:

```xml
<include>
  <uri>model://my_robot</uri>
</include>
```

Помещай models в `models/`:

```text
models/my_robot/
├── model.config
├── model.sdf
└── meshes/
```

Помещай custom plugin binaries в `plugins/`. Они должны быть собраны под пакет Gazebo и версию Ubuntu, используемые этим image.

Runtime paths по умолчанию:

```text
GZ_SIM_RESOURCE_PATH=/sim/worlds:/sim/models
GZ_SIM_SYSTEM_PLUGIN_PATH=/sim/plugins
GZ_GUI_PLUGIN_PATH=/sim/plugins
GZ_GUI_RESOURCE_PATH=/sim/worlds:/sim/models
GAZEBO_WEB_GUI_TEMPLATE=/sim/gz-web-gui.config
```

## Конфигурация

Скопируй `.env.example` в `.env` и меняй только нужные значения:

```bash
cp .env.example .env
```

Большинству пользователей нужны только эти параметры:

| Variable | Default | Use |
| --- | --- | --- |
| `GAZEBO_PACKAGE` | `gz-jetty` | Full Gazebo package. Поддерживаемые варианты: `gz-jetty`, `gz-harmonic`, `gz-ionic`. |
| `UBUNTU_VERSION` | `24.04` | Рекомендуемая версия Ubuntu base image. |
| `GAZEBO_WORLD` | `/sim/worlds/default.sdf` | World, который открывается при старте. |
| `GAZEBO_ARGS` | `-v 2` | Простые flags, передаваемые в `gz sim`. |
| `WEB_PORT` | `6080` | Port браузерного UI. |
| `WEB_BIND_ADDRESS` | `127.0.0.1` | Host bind address для web mode. |
| `VNC_GEOMETRY` | `1920x1080` | Разрешение виртуального desktop в web mode. |
| `GAZEBO_WEB_PROFILE` | `balanced` | Web stream profile: `fast`, `balanced` или `quality`. |
| `GAZEBO_GPU_MODE` | `auto` | GPU path: `auto`, `nvidia`, `dxg`, `dri` или `software`. |
| `GAZEBO_VERIFY_RENDERER` | `0` | Остановить запуск, если OpenGL перешёл на software rendering. |

Рекомендуемое значение по умолчанию: `GAZEBO_PACKAGE=gz-jetty` и `UBUNTU_VERSION=24.04`.

Build-time options:

```bash
GAZEBO_PACKAGE=gz-jetty docker compose build gazebo
GAZEBO_PACKAGE=gz-harmonic docker compose build gazebo
GAZEBO_PACKAGE=gz-ionic docker compose build gazebo
UBUNTU_VERSION=24.04 docker compose build gazebo
```

## Web UI и производительность

Web mode запускает Gazebo через цепочку:

```text
Gazebo GUI -> TigerVNC -> websockify -> noVNC -> Browser
```

Это самый переносимый режим, но всё равно streamed desktop. Даже на той же машине native Linux UI может ощущаться плавнее, потому что web mode захватывает frames, кодирует, передаёт, декодирует и отрисовывает их в браузере.

Настройка web stream:

```bash
GAZEBO_WEB_PROFILE=fast ./start-gazebo.sh web
GAZEBO_WEB_PROFILE=quality ./start-gazebo.sh web
VNC_GEOMETRY=1600x900 ./start-gazebo.sh web
```

Security note:

```env
WEB_BIND_ADDRESS=127.0.0.1
```

Оставляй localhost binding, если не хочешь намеренно открывать web UI другим машинам в сети.

## GPU support

Launcher пытается использовать самый сильный поддерживаемый GPU path, доступный через Docker:

```text
NVIDIA Docker runtime
WSL /dev/dxg
AMD / Intel DRI render node
software fallback
```

В native Linux UI modes NVIDIA имеет приоритет, если Docker предоставляет рабочий NVIDIA runtime. В web mode режим `auto` не форсирует NVIDIA под VNC, потому что на некоторых hosts невозможно стабильно создать NVIDIA GLX context внутри virtual display. Если на твоём host это работает надёжно, можно принудительно выбрать `GAZEBO_GPU_MODE=nvidia`.

Когда GPU path найден, `start-gazebo.sh` создаёт локальный override file:

```text
.gazebo/gpu.compose.yml
```

Этот файл зависит от конкретной машины и игнорируется git.

Принудительный выбор режима:

```bash
GAZEBO_GPU_MODE=nvidia ./start-gazebo.sh web
GAZEBO_GPU_MODE=dri ./start-gazebo.sh ui
GAZEBO_GPU_MODE=dxg ./start-gazebo.sh web
GAZEBO_GPU_MODE=software ./start-gazebo.sh web
```

Проверить NVIDIA Docker support:

```bash
docker run --rm --gpus all ubuntu nvidia-smi
```

Проверить renderer selection:

```bash
GAZEBO_VERIFY_RENDERER=1 ./start-gazebo.sh ui
```

## Техническая архитектура

| Файл | Роль |
| --- | --- |
| `gz.dockerfile` | Устанавливает Ubuntu, full Gazebo, noVNC, TigerVNC, websockify, Qt/Wayland, Mesa tools и runtime utilities. |
| `gz-entrypoint.sh` | Подготавливает выбранный display backend и выполняет `gz sim`. |
| `docker-compose.yml` | Описывает web service, native UI profile, mounts, environment и ports. |
| `start-gazebo.sh` | Управляет `.env`, GPU detection, mode selection, permissions и startup. |
| `start-gazebo.bat` | Предоставляет Windows web-mode launcher. |

Поведение entrypoint:

```text
prepare display backend
prepare web GUI config when needed
split simple GAZEBO_ARGS flags
exec gz sim ${GAZEBO_ARGS} <world>
```

Здесь нет server-only mode, GUI-only mode, `ign` fallback или project-specific command automation.

## Устранение неполадок

| Проблема | Первая проверка |
| --- | --- |
| Web UI не открывается | `docker compose logs --tail=200 gazebo` |
| World не загружается | `docker run --rm -v "$PWD/worlds:/sim/worlds:ro" --entrypoint gz gazebo-universal-runtime:local sdf -k /sim/worlds/default.sdf` |
| NVIDIA не используется | `docker run --rm --gpus all ubuntu nvidia-smi` |
| Native UI не открывается | Проверь `DISPLAY`, `/tmp/.X11-unix`, `WAYLAND_DISPLAY` и `XDG_RUNTIME_DIR`. |
| Web mode работает медленно | Попробуй `GAZEBO_WEB_PROFILE=fast` или уменьши `VNC_GEOMETRY`. |
| Wayland 3D нестабилен | Оставь default XWayland path или протестируй `GAZEBO_WAYLAND_NATIVE=1`. |

Полезные команды:

```bash
docker compose logs --tail=200 gazebo
docker compose --profile ui logs --tail=200 gazebo-ui
docker compose ps
./stop-gazebo.sh
```

## 📫 Контакты

X: [@TahsinCrs][x-url]

LinkedIn: [@TahsinCr][linkedin-url]

Email: TahsinCrs@gmail.com

## Лицензия

Распространяется по лицензии MIT. См. [LICENSE](LICENSE).

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
