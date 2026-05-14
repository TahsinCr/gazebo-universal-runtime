#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

GPU_DIR=".gazebo"
GPU_COMPOSE_FILE="${GPU_DIR}/gpu.compose.yml"

load_env_file() {
  local key line value

  [[ -f .env ]] || return 0

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line//[[:space:]]/}" || "${line}" =~ ^[[:space:]]*# ]] && continue

    if [[ "${line}" == export\ * ]]; then
      line="${line#export }"
    fi

    key="${line%%=*}"
    value="${line#*=}"
    key="${key//[[:space:]]/}"
    [[ "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue

    if [[ -n "${!key+x}" ]]; then
      continue
    fi

    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [[ "${value}" == \"*\" && "${value}" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value}" == \'*\' && "${value}" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi

    export "${key}=${value}"
  done < .env
}

usage() {
  cat <<'EOF'
Usage:
  ./start-gazebo.sh [web|ui|x11|wayland] [world.sdf]

Modes:
  web      Browser UI at http://localhost:6080/
  ui       Native UI, auto-selects Wayland on Wayland sessions, otherwise X11
  x11      Force native X11
  wayland  Wayland session mode; uses XWayland by default for Gazebo 3D stability

GPU:
  Auto by default: NVIDIA runtime > WSL DXG > AMD DRI > Intel DRI > software.
  Override with GAZEBO_GPU_MODE=nvidia|dxg|dri|software.
  NVIDIA cards require the Docker NVIDIA runtime; raw NVIDIA DRI is skipped
  unless GAZEBO_DRI_ALLOW_NVIDIA=1 is set explicitly.
  Force experimental native Qt Wayland with GAZEBO_WAYLAND_NATIVE=1.

Web stream:
  GAZEBO_WEB_PROFILE=balanced|fast|quality

World:
  Starts worlds/default.sdf from this project by default.
  Override with GAZEBO_WORLD=worlds/my_world.sdf or a second argument.
  Legacy quick-start dialog: GAZEBO_QUICK_START=1 ./start-gazebo.sh web
EOF
}

compose_base() {
  docker compose -f docker-compose.yml "$@"
}

compose_runtime() {
  if [[ -f "${GPU_COMPOSE_FILE}" ]]; then
    docker compose -f docker-compose.yml -f "${GPU_COMPOSE_FILE}" "$@"
  else
    docker compose -f docker-compose.yml "$@"
  fi
}

ask_mode() {
  local answer

  if [[ ! -t 0 ]]; then
    printf 'web\n'
    return
  fi

  printf 'How should Gazebo start?\n'
  printf '  1) web  - browser UI, most portable\n'
  printf '  2) ui   - native Linux UI, lowest latency\n'
  printf 'Selection [web]: '
  read -r answer

  case "${answer:-web}" in
    1 | web | w)
      printf 'web\n'
      ;;
    2 | ui | u)
      printf 'ui\n'
      ;;
    *)
      printf 'Unknown selection: %s\n' "${answer}" >&2
      exit 1
      ;;
  esac
}

is_wsl() {
  [[ -r /proc/version ]] && grep -qiE 'microsoft|wsl' /proc/version
}

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

detect_xauthority() {
  local candidate

  if [[ -n "${XAUTHORITY:-}" && -f "${XAUTHORITY}" ]]; then
    printf '%s\n' "${XAUTHORITY}"
    return
  fi

  if [[ -f "${HOME}/.Xauthority" ]]; then
    printf '%s\n' "${HOME}/.Xauthority"
    return
  fi

  for candidate in "/run/user/$(id -u)"/xauth_*; do
    if [[ -f "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return
    fi
  done
}

x11_available() {
  local display_number="${DISPLAY:-}"

  [[ -n "${display_number}" ]] || return 1
  display_number="${display_number#*:}"
  display_number="${display_number%%.*}"

  [[ -S "/tmp/.X11-unix/X${display_number}" ]]
}

wayland_available() {
  local runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  local wayland_display="${WAYLAND_DISPLAY:-wayland-0}"

  [[ -S "${runtime_dir}/${wayland_display}" ]]
}

detect_ui_backend() {
  if [[ -n "${GAZEBO_UI_BACKEND:-}" ]]; then
    printf '%s\n' "${GAZEBO_UI_BACKEND}"
    return
  fi

  if [[ "${XDG_SESSION_TYPE:-}" == "wayland" ]] && wayland_available; then
    printf 'wayland\n'
    return
  fi

  if x11_available; then
    printf 'x11\n'
    return
  fi

  if wayland_available; then
    printf 'wayland\n'
    return
  fi

  printf 'No X11 or Wayland session was found for native UI. Use web mode instead: ./start-gazebo.sh web\n' >&2
  exit 1
}

ensure_host_dirs() {
  mkdir -p worlds models plugins data "${GPU_DIR}"

  if [[ ! -f gz-web-gui.config ]]; then
    printf '[gazebo] ERROR: gz-web-gui.config is missing. Restore it from the repository.\n' >&2
    exit 1
  fi

  if [[ ! -f index.html ]]; then
    printf '[gazebo] ERROR: index.html is missing. Restore it from the repository.\n' >&2
    exit 1
  fi

  if [[ "${GAZEBO_WORLD:-/sim/worlds/default.sdf}" == "/sim/worlds/default.sdf" && ! -f worlds/default.sdf ]]; then
    printf '[gazebo] ERROR: worlds/default.sdf is missing. Restore it or set GAZEBO_WORLD in .env.\n' >&2
    exit 1
  fi
}

apply_web_profile() {
  local profile="${GAZEBO_WEB_PROFILE:-balanced}"

  case "${profile}" in
    fast)
      export VNC_FRAME_RATE="${VNC_FRAME_RATE:-60}"
      export VNC_COMPARE_FB="${VNC_COMPARE_FB:-2}"
      export VNC_ZLIB_LEVEL="${VNC_ZLIB_LEVEL:-2}"
      ;;
    balanced)
      export VNC_FRAME_RATE="${VNC_FRAME_RATE:-60}"
      export VNC_COMPARE_FB="${VNC_COMPARE_FB:-2}"
      export VNC_ZLIB_LEVEL="${VNC_ZLIB_LEVEL:-1}"
      ;;
    quality)
      export VNC_FRAME_RATE="${VNC_FRAME_RATE:-60}"
      export VNC_COMPARE_FB="${VNC_COMPARE_FB:-2}"
      export VNC_ZLIB_LEVEL="${VNC_ZLIB_LEVEL:-1}"
      ;;
    *)
      printf 'Invalid GAZEBO_WEB_PROFILE=%s. Use: balanced, fast, quality\n' "${profile}" >&2
      exit 1
      ;;
  esac

  export GAZEBO_WEB_PROFILE="${profile}"
}

web_url() {
  printf 'http://localhost:%s/?profile=%s\n' "${WEB_PORT:-6080}" "${GAZEBO_WEB_PROFILE:-balanced}"
}

repair_data_permissions() {
  printf '[gazebo] Preparing writable data directories...\n'
  compose_base run --rm --no-deps --entrypoint sh -u 0 gazebo \
    -lc "mkdir -p /data/.gz /data/logs /data/.cache && chown -R ${HOST_UID}:${HOST_GID} /data"
}

allow_x11_access() {
  if [[ -n "${XAUTHORITY:-}" && -f "${XAUTHORITY}" ]]; then
    return
  fi

  if command -v xhost >/dev/null 2>&1; then
    xhost +SI:localuser:"$(id -un)" >/dev/null 2>&1 || true
    xhost +local:docker >/dev/null 2>&1 || true
  fi
}

host_has_nvidia() {
  command -v nvidia-smi >/dev/null 2>&1 || [[ -x /usr/lib/wsl/lib/nvidia-smi ]]
}

docker_nvidia_works() {
  local image_id="$1"

  docker run --rm --gpus all --entrypoint sh "${image_id}" -lc 'true' >/dev/null 2>&1
}

host_has_dri() {
  compgen -G "/dev/dri/renderD*" >/dev/null
}

host_has_dxg() {
  [[ -e /dev/dxg ]]
}

group_id_for() {
  local path="$1"

  if [[ -e "${path}" ]]; then
    stat -c '%g' "${path}"
  fi
}

device_group_add_block() {
  local gid path seen=" "
  local wrote=0

  for path in /dev/dri/card* /dev/dri/renderD*; do
    [[ -e "${path}" ]] || continue
    gid="$(group_id_for "${path}" || true)"
    [[ -n "${gid}" ]] || continue

    case "${seen}" in
      *" ${gid} "*)
        continue
        ;;
    esac

    if [[ "${wrote}" == "0" ]]; then
      printf '    group_add:\n'
      wrote=1
    fi

    printf '      - "%s"\n' "${gid}"
    seen="${seen}${gid} "
  done
}

dri_vendor() {
  local node="$1"
  local sys_path="/sys/class/drm/$(basename "${node}")/device/vendor"

  [[ -r "${sys_path}" ]] && tr '[:upper:]' '[:lower:]' <"${sys_path}"
}

dri_device() {
  local node="$1"
  local sys_path="/sys/class/drm/$(basename "${node}")/device/device"

  [[ -r "${sys_path}" ]] && tr '[:upper:]' '[:lower:]' <"${sys_path}"
}

dri_pci_id() {
  local node="$1"
  local sys_path="/sys/class/drm/$(basename "${node}")/device"

  basename "$(readlink -f "${sys_path}")" 2>/dev/null || true
}

dri_prime_name() {
  local pci_id="$1"

  [[ -n "${pci_id}" ]] || return 0
  printf 'pci-%s\n' "${pci_id//[:.]/_}"
}

dri_prime_value() {
  local vendor="$1"
  local pci_id="$2"

  case "${vendor}" in
    0x1002 | 0x1022)
      dri_prime_name "${pci_id}"
      ;;
    0x10de)
      printf '1'
      ;;
  esac
}

dri_vendor_name() {
  case "$1" in
    0x1002 | 0x1022)
      printf 'AMD'
      ;;
    0x10de)
      printf 'NVIDIA'
      ;;
    0x8086)
      printf 'Intel'
      ;;
    *)
      printf 'DRI'
      ;;
  esac
}

select_dri_render_node() {
  local node vendor

  if [[ -n "${GAZEBO_DRI_RENDER_NODE:-}" ]]; then
    [[ -e "${GAZEBO_DRI_RENDER_NODE}" ]] || die_gpu_unavailable "GAZEBO_DRI_RENDER_NODE was not found: ${GAZEBO_DRI_RENDER_NODE}"
    printf '%s\n' "${GAZEBO_DRI_RENDER_NODE}"
    return
  fi

  for node in /dev/dri/renderD*; do
    [[ -e "${node}" ]] || continue
    vendor="$(dri_vendor "${node}")"
    if [[ "${vendor}" == "0x1002" || "${vendor}" == "0x1022" ]]; then
      printf '%s\n' "${node}"
      return
    fi
  done

  for node in /dev/dri/renderD*; do
    [[ -e "${node}" ]] || continue
    vendor="$(dri_vendor "${node}")"
    if [[ "${vendor}" != "0x10de" ]]; then
      printf '%s\n' "${node}"
      return
    fi
  done

  if [[ "${GAZEBO_DRI_ALLOW_NVIDIA:-0}" == "1" ]]; then
    for node in /dev/dri/renderD*; do
      [[ -e "${node}" ]] || continue
      vendor="$(dri_vendor "${node}")"
      if [[ "${vendor}" == "0x10de" ]]; then
        printf '%s\n' "${node}"
        return
      fi
    done
  fi

  return 1
}

card_for_render_node() {
  local render_node="$1"
  local render_device card card_device

  render_device="$(readlink -f "/sys/class/drm/$(basename "${render_node}")/device")"

  for card in /dev/dri/card*; do
    [[ -e "${card}" ]] || continue
    card_device="$(readlink -f "/sys/class/drm/$(basename "${card}")/device")"
    if [[ "${card_device}" == "${render_device}" ]]; then
      printf '%s\n' "${card}"
      return
    fi
  done
}

write_nvidia_gpu_override() {
  local group_add_block

  group_add_block="$(device_group_add_block)"

  cat >"${GPU_COMPOSE_FILE}" <<EOF
services:
  gazebo: &gpu-nvidia
    gpus: all
${group_add_block}
    environment:
      GAZEBO_GPU_MODE: "nvidia"
      NVIDIA_VISIBLE_DEVICES: "all"
      NVIDIA_DRIVER_CAPABILITIES: "graphics,utility,compute,display"
      __GLX_VENDOR_LIBRARY_NAME: "nvidia"
      __NV_PRIME_RENDER_OFFLOAD: "1"
      __GL_SYNC_TO_VBLANK: "0"
      __GL_THREADED_OPTIMIZATIONS: "1"
      LIBGL_ALWAYS_SOFTWARE: "0"
  gazebo-ui:
    <<: *gpu-nvidia
EOF
}

write_dri_gpu_override() {
  local card_device_entry card_node device_id dri_prime dri_prime_env mesa_select pci_id render_gid render_node vendor vendor_name video_gid

  render_node="$(select_dri_render_node)" || return 1
  card_node="$(card_for_render_node "${render_node}")"
  render_gid="$(group_id_for "${render_node}" || true)"
  video_gid="$(group_id_for "${card_node}" || true)"
  vendor="$(dri_vendor "${render_node}")"
  device_id="$(dri_device "${render_node}")"
  pci_id="$(dri_pci_id "${render_node}")"
  dri_prime="$(dri_prime_value "${vendor}" "${pci_id}")"
  vendor_name="$(dri_vendor_name "${vendor}")"
  mesa_select="${vendor#0x}:${device_id#0x}"
  if [[ -n "${dri_prime}" ]]; then
    dri_prime_env="      DRI_PRIME: \"${dri_prime}\""
  else
    dri_prime_env=""
  fi
  if [[ -n "${card_node}" ]]; then
    card_device_entry="      - ${card_node}:${card_node}"
  else
    card_device_entry=""
  fi
  DRI_GPU_LABEL="${vendor_name} ${render_node}"

  cat >"${GPU_COMPOSE_FILE}" <<EOF
services:
  gazebo: &gpu-dri
    devices:
      - ${render_node}:${render_node}
${card_device_entry}
    group_add:
      - "${render_gid:-render}"
      - "${video_gid:-video}"
    environment:
      GAZEBO_GPU_MODE: "dri"
      GAZEBO_DRI_RENDER_NODE: "${render_node}"
      GAZEBO_DRI_VENDOR: "${vendor:-unknown}"
      GAZEBO_DRI_DEVICE: "${device_id:-unknown}"
${dri_prime_env}
      MESA_VK_DEVICE_SELECT: "${mesa_select}"
      LIBGL_ALWAYS_SOFTWARE: "0"
      vblank_mode: "0"
  gazebo-ui:
    <<: *gpu-dri
EOF
}

write_dxg_gpu_override() {
  cat >"${GPU_COMPOSE_FILE}" <<'EOF'
services:
  gazebo: &gpu-dxg
    devices:
      - /dev/dxg:/dev/dxg
    volumes:
      - /usr/lib/wsl/lib:/usr/lib/wsl/lib:ro
    environment:
      GAZEBO_GPU_MODE: "dxg"
      LD_LIBRARY_PATH: "/usr/lib/wsl/lib"
      LIBGL_ALWAYS_SOFTWARE: "0"
  gazebo-ui:
    <<: *gpu-dxg
    volumes:
      - /usr/lib/wsl/lib:/usr/lib/wsl/lib:ro
      - /mnt/wslg:/mnt/wslg:rw
EOF
}

select_gpu_mode() {
  local image_id="$1"
  local nvidia_available=0
  local requested="${GAZEBO_GPU_MODE:-auto}"

  rm -f "${GPU_COMPOSE_FILE}"

  if [[ "${GAZEBO_ALLOW_SOFTWARE:-0}" == "1" ]]; then
    export GAZEBO_REQUIRE_GPU=0
    printf '[gazebo] GPU: software override enabled\n'
    return
  fi

  case "${requested}" in
    auto)
      if host_has_nvidia && docker_nvidia_works "${image_id}"; then
        nvidia_available=1
      fi

      if [[ "${nvidia_available}" == "1" && "${mode:-}" != "web" ]]; then
        write_nvidia_gpu_override
        export GAZEBO_REQUIRE_GPU=1
        printf '[gazebo] GPU: NVIDIA runtime\n'
        return
      fi

      if [[ "${nvidia_available}" == "1" && "${mode:-}" == "web" ]]; then
        printf '[gazebo] GPU: NVIDIA runtime found, but web mode auto prefers the stable VNC-compatible path. Use GAZEBO_GPU_MODE=nvidia to force NVIDIA.\n' >&2
      elif host_has_nvidia; then
        printf '[gazebo] Warning: NVIDIA was found, but Docker GPU runtime is not available. Trying another GPU path.\n' >&2
      fi

      if is_wsl && host_has_dxg; then
        write_dxg_gpu_override
        export GAZEBO_REQUIRE_GPU=1
        printf '[gazebo] GPU: WSL /dev/dxg\n'
        return
      fi

      if host_has_dri; then
        if write_dri_gpu_override; then
          export GAZEBO_REQUIRE_GPU=1
          printf '[gazebo] GPU: Linux DRI render device (%s)\n' "${DRI_GPU_LABEL:-auto}"
          return
        fi

        printf '[gazebo] Warning: no suitable AMD/Intel DRI render device was found. NVIDIA requires the Docker NVIDIA runtime.\n' >&2
      fi
      ;;
    nvidia)
      docker_nvidia_works "${image_id}" || die_gpu_unavailable "NVIDIA Docker runtime is not available."
      write_nvidia_gpu_override
      export GAZEBO_REQUIRE_GPU=1
      printf '[gazebo] GPU: NVIDIA runtime\n'
      return
      ;;
    dri)
      host_has_dri || die_gpu_unavailable "/dev/dri render device was not found."
      write_dri_gpu_override || die_gpu_unavailable "No suitable AMD/Intel DRI render device was found. You can force raw NVIDIA DRI with GAZEBO_DRI_ALLOW_NVIDIA=1, but NVIDIA Container Toolkit is recommended."
      export GAZEBO_REQUIRE_GPU=1
      printf '[gazebo] GPU: Linux DRI render device (%s)\n' "${DRI_GPU_LABEL:-auto}"
      return
      ;;
    dxg)
      host_has_dxg || die_gpu_unavailable "/dev/dxg was not found."
      write_dxg_gpu_override
      export GAZEBO_REQUIRE_GPU=1
      printf '[gazebo] GPU: WSL /dev/dxg\n'
      return
      ;;
    software)
      export GAZEBO_REQUIRE_GPU=0
      printf '[gazebo] GPU: software fallback selected\n'
      return
      ;;
    *)
      printf 'Invalid GAZEBO_GPU_MODE=%s. Use: auto, nvidia, dxg, dri, software\n' "${requested}" >&2
      exit 1
      ;;
  esac

  export GAZEBO_REQUIRE_GPU=0
  printf '[gazebo] GPU: no supported GPU path was found; using software fallback for portability.\n' >&2
}

die_gpu_unavailable() {
  local reason="$1"

  printf '[gazebo] ERROR: GPU is required but is not available. %s\n' "${reason}" >&2

  if is_macos; then
    printf '[gazebo] macOS Docker Desktop does not expose native Linux OpenGL acceleration to Linux containers. Use web mode or a Linux GPU host.\n' >&2
  elif is_wsl; then
    printf '[gazebo] On Windows, check Docker Desktop WSL2 GPU support and NVIDIA runtime or WSLg devices.\n' >&2
  else
    printf '[gazebo] On Linux, NVIDIA Container Toolkit/CDI or a /dev/dri render device is required.\n' >&2
  fi

  printf '[gazebo] For debugging with software rendering: GAZEBO_ALLOW_SOFTWARE=1 ./start-gazebo.sh web\n' >&2
  exit 1
}

print_renderer_note() {
  local service="$1"
  local renderer=""

  for _ in {1..50}; do
    renderer="$(compose_runtime logs --no-color --tail=80 "${service}" 2>/dev/null | awk -F'renderer: ' '/renderer: / {print $2; exit}')"
    [[ -n "${renderer}" ]] && break
    sleep 0.2
  done

  [[ -n "${renderer}" ]] || return 0

  printf '[gazebo] Renderer: %s\n' "${renderer}"

  if [[ "${renderer}" =~ (llvmpipe|softpipe|swrast|Software|software) ]]; then
    printf '[gazebo] Note: this session is using software OpenGL. For the smoothest local GPU experience, use ./start-gazebo.sh ui on Linux.\n'
  fi
}

load_env_file

mode="${1:-}"
world_arg=""

if [[ "${mode}" == "-h" || "${mode}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${mode}" ]]; then
  mode="$(ask_mode)"
else
  case "${mode}" in
    web | ui | x11 | wayland)
      shift
      world_arg="${1:-}"
      ;;
    *)
      world_arg="${mode}"
      mode="$(ask_mode)"
      ;;
  esac
fi

if [[ -n "${world_arg}" ]]; then
  export GAZEBO_WORLD="${world_arg}"
fi

export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/${HOST_UID}}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
export XAUTHORITY="$(detect_xauthority || true)"

if [[ "${mode}" == "ui" ]]; then
  mode="$(detect_ui_backend)"
fi

if [[ "${mode}" == "web" ]]; then
  apply_web_profile
fi

if [[ "${mode}" == "x11" ]]; then
  [[ -n "${DISPLAY:-}" ]] || {
    printf 'X11 mode requires DISPLAY.\n' >&2
    exit 1
  }
  export GAZEBO_DISPLAY_BACKEND=x11
  allow_x11_access
elif [[ "${mode}" == "wayland" ]]; then
  wayland_available || {
    printf 'Wayland socket was not found: %s/%s\n' "${XDG_RUNTIME_DIR}" "${WAYLAND_DISPLAY}" >&2
    exit 1
  }

  if [[ "${GAZEBO_WAYLAND_NATIVE:-0}" != "1" ]]; then
    x11_available || {
      printf 'Wayland session mode requires an XWayland DISPLAY for Gazebo 3D. To try native Wayland: GAZEBO_WAYLAND_NATIVE=1 ./start-gazebo.sh wayland\n' >&2
      exit 1
    }
    allow_x11_access
  fi

  export GAZEBO_DISPLAY_BACKEND=wayland
fi

printf '[gazebo] Cleaning previous containers...\n'
compose_runtime --profile ui down --remove-orphans

ensure_host_dirs

printf '[gazebo] Preparing image...\n'
compose_base build gazebo
repair_data_permissions

image_ref="${GAZEBO_IMAGE:-gazebo-universal-runtime:local}"
docker image inspect "${image_ref}" >/dev/null || {
  printf 'Gazebo image was not found.\n' >&2
  exit 1
}

select_gpu_mode "${image_ref}"

case "${mode}" in
  web)
    printf '[gazebo] Starting web mode...\n'
    compose_runtime up -d --no-build gazebo
    print_renderer_note gazebo
    printf '[gazebo] Ready: %s\n' "$(web_url)"
    ;;
  x11 | wayland)
    printf '[gazebo] Starting native UI mode: %s\n' "${mode}"
    compose_runtime --profile ui up -d --no-build gazebo-ui
    print_renderer_note gazebo-ui
    ;;
esac

printf '[gazebo] Status:\n'
compose_runtime --profile ui ps
