[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT Lisansı][license-shield]][license-url]
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
Robotik ve otonom sistem projeleri için evrensel, tam arayüzlü Gazebo Sim Docker çalışma altyapısı.
</p>

<p align="center">
Tek image. Tek container. Varsayılan olarak tarayıcı arayüzü. Gerektiğinde Linux native UI. Proje dosyaları repoda kalır.
</p>

</div>

<br/>

## Hızlı Başlangıç

Normal kullanım için tek zorunlu bağımlılık Docker’dır. Modern `docker compose` komutunu içeren güncel bir Docker kurulumu yeterlidir. Windows ve macOS üzerinde Docker Desktop Compose desteğini zaten içerir.

```bash
git clone https://github.com/TahsinCr/gazebo-universal-runtime.git
cd gazebo-universal-runtime
cp .env.example .env
./start-gazebo.sh web
```

Aç:

```text
http://localhost:6080/
```

Durdur:

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

## Nedir?

Gazebo Universal Runtime, Gazebo Sim’i grafik arayüzle çalıştırmak için tekrar kullanılabilir bir Docker temelidir. Robotik, otonom sistemler, drone, mobil robot, manipülasyon, simülasyon demoları, eğitim ve araştırma projeleri için tasarlanmıştır.

Image bilinçli olarak full Gazebo runtime’dır:

```bash
gz sim ${GAZEBO_ARGS} <world>
```

Repo yeni indirildiğinde hemen çalışabilmesi için varsayılan world bulunur:

```text
worlds/default.sdf -> /sim/worlds/default.sdf
```

Proje varlıkları image içine gömülmez. World, model, plugin, GUI config, web UI, cache ve log dosyaları image dışında kalır ve runtime sırasında mount edilir.

## Kapsam

| Dahil | Dahil değil |
| --- | --- |
| Full Gazebo paketi, varsayılan `gz-jetty` | ROS, PX4, ArduPilot, QGroundControl, Mission Planner |
| Tarayıcı tabanlı Gazebo UI | Projeye özel simülasyon sunucuları |
| Opsiyonel Linux native UI | Ayrı server-only ve GUI-only container mimarisi |
| GPU-aware başlangıç scriptleri | Sabitlenmiş robot, world, model veya plugin dosyaları |
| `.env` tabanlı ayar | Runtime log veya cache dosyalarının image içine gömülmesi |

Bu sınır, repoyu tek projeye özel bir image yerine genel bir Gazebo temeli olarak kullanılabilir tutar.

## Mod Seçimi

| Platform | Önerilen mod | Not |
| --- | --- | --- |
| Linux | `ui` veya `web` | En düşük lokal gecikme için `ui`, en kolay taşınabilir yol için `web`. X11 veya Wayland erişimi yalnızca native UI modlarında gerekir. |
| Windows | `web` | Web modu Docker Desktop ile çalışır. Native Linux UI tarayıcı modu için zorunlu değildir; WSL/Linux workflow’udur. |
| macOS | `web` | Docker Desktop, macOS üzerinde Linux container içine native Linux OpenGL hızlandırması vermez. Taşınabilir yol web modudur. |

| Mod | Komut | En uygun kullanım |
| --- | --- | --- |
| `web` | `./start-gazebo.sh web` | Tarayıcı erişimi, demo, platformlar arası kullanım, kolay başlangıç. |
| `ui` | `./start-gazebo.sh ui` | Otomatik X11 veya Wayland session seçimiyle Linux native UI. |
| `x11` | `./start-gazebo.sh x11` | Linux üzerinde X11’i zorlamak. |
| `wayland` | `./start-gazebo.sh wayland` | Wayland session mode’u zorlamak; Gazebo 3B stabilitesi için varsayılan olarak XWayland kullanılır. |

Yaygın örnekler:

```bash
./start-gazebo.sh web
./start-gazebo.sh ui
./start-gazebo.sh web worlds/my_world.sdf
./start-gazebo.sh x11 worlds/my_world.sdf
./start-gazebo.sh wayland worlds/my_world.sdf
GAZEBO_QUICK_START=1 ./start-gazebo.sh web
```

## Proje Yapısı

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

| Host path | Container path | Amaç |
| --- | --- | --- |
| `./worlds` | `/sim/worlds` | SDF world dosyaları. |
| `./models` | `/sim/models` | Gazebo modelleri, mesh, texture, material ve `model.config` dosyaları. |
| `./plugins` | `/sim/plugins` | Özel Gazebo system veya GUI plugin `.so` dosyaları. |
| `./gz-web-gui.config` | `/sim/gz-web-gui.config` | Web modunda kullanılan Gazebo GUI yerleşimi. |
| `./index.html` | `/usr/share/novnc/index.html` | noVNC tarafından sunulan tarayıcı konsolu. |
| `./data` | `/data` | Gazebo cache, log, Fuel indirmeleri ve runtime data. |

Kök dizindeki `gz-web-gui.config` ve `index.html` dosyaları doğrudan container içine mount edilir. Bu sayede Dockerfile değiştirmeden arayüz ve GUI yerleşimi düzenlenebilir.

## World, Model ve Plugin

World dosyalarını `worlds/` altına koy:

```bash
./start-gazebo.sh web worlds/my_world.sdf
```

World içinde normal Gazebo model URI kullan:

```xml
<include>
  <uri>model://my_robot</uri>
</include>
```

Model dosyalarını `models/` altında tut:

```text
models/my_robot/
├── model.config
├── model.sdf
└── meshes/
```

Özel plugin binary dosyalarını `plugins/` altına koy. Bu dosyalar image içinde kullanılan Gazebo paketi ve Ubuntu sürümüyle uyumlu derlenmelidir.

Varsayılan runtime path değerleri:

```text
GZ_SIM_RESOURCE_PATH=/sim/worlds:/sim/models
GZ_SIM_SYSTEM_PLUGIN_PATH=/sim/plugins
GZ_GUI_PLUGIN_PATH=/sim/plugins
GZ_GUI_RESOURCE_PATH=/sim/worlds:/sim/models
GAZEBO_WEB_GUI_TEMPLATE=/sim/gz-web-gui.config
```

## Konfigürasyon

`.env.example` dosyasını `.env` olarak kopyala ve yalnızca ihtiyacın olan değerleri değiştir:

```bash
cp .env.example .env
```

Çoğu kullanıcı için önemli değerler:

| Değişken | Varsayılan | Kullanım |
| --- | --- | --- |
| `GAZEBO_PACKAGE` | `gz-jetty` | Full Gazebo paketi. Desteklenen seçenekler: `gz-jetty`, `gz-harmonic`, `gz-ionic`. |
| `UBUNTU_VERSION` | `24.04` | Önerilen Ubuntu base image sürümü. |
| `GAZEBO_WORLD` | `/sim/worlds/default.sdf` | Başlangıç world dosyası. |
| `GAZEBO_ARGS` | `-v 2` | `gz sim` komutuna gönderilen basit flagler. |
| `WEB_PORT` | `6080` | Tarayıcı arayüz portu. |
| `WEB_BIND_ADDRESS` | `127.0.0.1` | Web modu host bind adresi. |
| `VNC_GEOMETRY` | `1920x1080` | Web modu sanal masaüstü çözünürlüğü. |
| `GAZEBO_WEB_PROFILE` | `balanced` | Web stream profili: `fast`, `balanced`, `quality`. |
| `GAZEBO_GPU_MODE` | `auto` | GPU yolu: `auto`, `nvidia`, `dxg`, `dri`, `software`. |
| `GAZEBO_VERIFY_RENDERER` | `0` | OpenGL software rendering’e düşerse başlangıcı durdurur. |

Önerilen varsayılan: `GAZEBO_PACKAGE=gz-jetty` ve `UBUNTU_VERSION=24.04`.

Build-time seçenekler:

```bash
GAZEBO_PACKAGE=gz-jetty docker compose build gazebo
GAZEBO_PACKAGE=gz-harmonic docker compose build gazebo
GAZEBO_PACKAGE=gz-ionic docker compose build gazebo
UBUNTU_VERSION=24.04 docker compose build gazebo
```

## Web UI ve Performans

Web modu şu zincirle çalışır:

```text
Gazebo GUI -> TigerVNC -> websockify -> noVNC -> Browser
```

En taşınabilir mod web modudur; fakat bu mod stream edilen bir masaüstüdür. Aynı makinede çalışsa bile Linux native UI daha akıcı hissedebilir, çünkü web modunda frame yakalama, encode, websocket aktarımı, decode ve tarayıcıda çizim adımları vardır.

Web stream ayarları:

```bash
GAZEBO_WEB_PROFILE=fast ./start-gazebo.sh web
GAZEBO_WEB_PROFILE=quality ./start-gazebo.sh web
VNC_GEOMETRY=1600x900 ./start-gazebo.sh web
```

Güvenlik notu:

```env
WEB_BIND_ADDRESS=127.0.0.1
```

Web UI’ın ağdaki diğer makinelerden açılmasını bilinçli olarak istemiyorsan localhost bind değerini koru.

## GPU Desteği

Launcher, Docker tarafından sunulan en güçlü desteklenen GPU yolunu kullanmaya çalışır:

```text
NVIDIA Docker runtime
WSL /dev/dxg
AMD / Intel DRI render node
software fallback
```

Native Linux UI modlarında Docker çalışan bir NVIDIA runtime sunuyorsa NVIDIA önceliklidir. Web modunda `auto`, NVIDIA’yı VNC altında zorlamaz; çünkü bazı hostlarda sanal display içinde stabil NVIDIA GLX context oluşturulamaz. Hostunda güvenilir çalıştığını biliyorsan `GAZEBO_GPU_MODE=nvidia` ile zorlayabilirsin.

GPU yolu bulunduğunda `start-gazebo.sh` lokal override dosyası üretir:

```text
.gazebo/gpu.compose.yml
```

Bu dosya makineye özeldir ve git tarafından ignore edilir.

Mod zorlamak için:

```bash
GAZEBO_GPU_MODE=nvidia ./start-gazebo.sh web
GAZEBO_GPU_MODE=dri ./start-gazebo.sh ui
GAZEBO_GPU_MODE=dxg ./start-gazebo.sh web
GAZEBO_GPU_MODE=software ./start-gazebo.sh web
```

NVIDIA Docker desteğini doğrula:

```bash
docker run --rm --gpus all ubuntu nvidia-smi
```

Renderer seçimini doğrula:

```bash
GAZEBO_VERIFY_RENDERER=1 ./start-gazebo.sh ui
```

## Teknik Mimari

| Dosya | Rol |
| --- | --- |
| `gz.dockerfile` | Ubuntu, full Gazebo, noVNC, TigerVNC, websockify, Qt/Wayland, Mesa araçları ve runtime yardımcılarını kurar. |
| `gz-entrypoint.sh` | Seçilen display backend’i hazırlar ve `gz sim` çalıştırır. |
| `docker-compose.yml` | Web servisi, native UI profili, mountlar, environment değerleri ve portları tanımlar. |
| `start-gazebo.sh` | `.env`, GPU tespiti, mod seçimi, izinler ve başlangıcı yönetir. |
| `start-gazebo.bat` | Windows web-mode launcher sağlar. |

Entrypoint davranışı:

```text
display backend hazırla
gerekiyorsa web GUI config hazırla
basit GAZEBO_ARGS flaglerini ayır
exec gz sim ${GAZEBO_ARGS} <world>
```

Server-only modu, GUI-only modu, `ign` fallback veya projeye özel komut otomasyonu yoktur.

## Sorun Giderme

| Sorun | İlk kontrol |
| --- | --- |
| Web UI açılmıyor | `docker compose logs --tail=200 gazebo` |
| World yüklenmiyor | `docker run --rm -v "$PWD/worlds:/sim/worlds:ro" --entrypoint gz gazebo-universal-runtime:local sdf -k /sim/worlds/default.sdf` |
| NVIDIA kullanılmıyor | `docker run --rm --gpus all ubuntu nvidia-smi` |
| Native UI açılmıyor | `DISPLAY`, `/tmp/.X11-unix`, `WAYLAND_DISPLAY` ve `XDG_RUNTIME_DIR` değerlerini kontrol et. |
| Web modu yavaş | `GAZEBO_WEB_PROFILE=fast` dene veya `VNC_GEOMETRY` değerini düşür. |
| Wayland 3B kararsız | Varsayılan XWayland yolunu koru veya `GAZEBO_WAYLAND_NATIVE=1` dene. |

Yararlı komutlar:

```bash
docker compose logs --tail=200 gazebo
docker compose --profile ui logs --tail=200 gazebo-ui
docker compose ps
./stop-gazebo.sh
```

## 📫 İletişim

X: [@TahsinCrs][x-url]

LinkedIn: [@TahsinCr][linkedin-url]

Email: TahsinCrs@gmail.com

## Lisans

MIT Lisansı ile dağıtılır. Ayrıntılar için [LICENSE](LICENSE) dosyasına bakın.

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
