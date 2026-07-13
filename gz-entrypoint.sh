#!/usr/bin/env bash
set -euo pipefail

die() {
  printf '[gazebo] ERROR: %s\n' "$*" >&2
  exit 1
}

load_runtime_release() {
  local release_file="/usr/local/share/gazebo/runtime-release"
  local existing_render_path="${GZ_RENDERING_PLUGIN_PATH:-}"
  local render_plugin
  local render_plugin_dir

  [[ -r "${release_file}" ]] || die "Runtime release metadata is missing: ${release_file}"

  # This file is generated inside the image and contains only fixed key/value
  # pairs describing the Gazebo collection installed in that image.
  # shellcheck disable=SC1090
  source "${release_file}"

  case "${IMAGE_GAZEBO_PACKAGE:-}" in
    gz-harmonic | gz-ionic | gz-jetty)
      ;;
    *)
      die "Unsupported image Gazebo package: ${IMAGE_GAZEBO_PACKAGE:-unknown}"
      ;;
  esac

  if [[ -n "${GAZEBO_EXPECTED_PACKAGE:-}" && "${GAZEBO_EXPECTED_PACKAGE}" != "${IMAGE_GAZEBO_PACKAGE}" ]]; then
    die "Image/package mismatch: image contains ${IMAGE_GAZEBO_PACKAGE}, but ${GAZEBO_EXPECTED_PACKAGE} was requested. Rebuild the image."
  fi

  render_plugin="$(find /usr/lib -path "*/gz-rendering-${GZ_RENDERING_MAJOR}/engine-plugins/libgz-rendering-ogre2.so" -print -quit)"
  [[ -r "${render_plugin}" ]] || die "Gazebo Rendering ${GZ_RENDERING_MAJOR} Ogre2 plugin was not found."
  render_plugin_dir="$(dirname "${render_plugin}")"

  # Debian packages may install several Gazebo majors side-by-side. The
  # unversioned library symlink then points to the newest one, which makes an
  # older Sim load an incompatible renderer and leaves the 3D panel blank.
  export GZ_RENDERING_PLUGIN_PATH="${render_plugin_dir}${existing_render_path:+:${existing_render_path}}"
  export GAZEBO_PACKAGE="${IMAGE_GAZEBO_PACKAGE}"
  export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/data/.cache/${IMAGE_GAZEBO_PACKAGE}}"

  mkdir -p "${XDG_CACHE_HOME}"

  printf '[gazebo] release: %s (sim=%s gui=%s rendering=%s)\n' \
    "${IMAGE_GAZEBO_PACKAGE}" "${GZ_SIM_MAJOR}" "${GZ_GUI_MAJOR}" "${GZ_RENDERING_MAJOR}"
  printf '[gazebo] rendering plugin path: %s\n' "${render_plugin_dir}"
}

healthcheck() {
  local gazebo_log="/data/logs/gazebo.log"
  local loaded_libraries=""
  local release_file="/usr/local/share/gazebo/runtime-release"

  pgrep -f 'gz([ -]sim| sim)' >/dev/null 2>&1 || return 1

  if [[ -r "${gazebo_log}" ]] && grep -qiE \
    'Found no render engine plugins|Failed to load plugin \[gz-rendering|Unable to load the rendering engine|corrupted size|Segmentation fault|Aborted' \
    "${gazebo_log}"; then
    return 1
  fi

  if [[ "${GAZEBO_REQUIRE_3D_VIEW:-1}" == "1" && "${GAZEBO_QUICK_START:-0}" != "1" ]]; then
    if [[ ! -r "${gazebo_log}" ]] \
      || ! grep -q 'Added plugin .*3D View' "${gazebo_log}" \
      || ! grep -q 'Loaded plugin .*MinimalScene' "${gazebo_log}"; then
      [[ -r "${release_file}" ]] || return 1
      # shellcheck disable=SC1090
      source "${release_file}"
      loaded_libraries="$(grep -hE 'libMinimalScene\.so|libgz-rendering([0-9]+)?-ogre2\.so' /proc/[0-9]*/maps 2>/dev/null || true)"
      grep -q "/gz-gui-${GZ_GUI_MAJOR}/plugins/libMinimalScene.so" <<< "${loaded_libraries}" || return 1
      if ! grep -q "/gz-rendering-${GZ_RENDERING_MAJOR}/engine-plugins/libgz-rendering${GZ_RENDERING_MAJOR}-ogre2.so" \
        <<< "${loaded_libraries}"; then
        grep -q "/libgz-rendering-ogre2.so.${GZ_RENDERING_MAJOR}" <<< "${loaded_libraries}" || return 1
      fi
    fi
  fi

  case "${GAZEBO_DISPLAY_BACKEND:-web}" in
    web | novnc)
      pgrep -x Xtigervnc >/dev/null 2>&1 || return 1
      pgrep -f 'websockify' >/dev/null 2>&1 || return 1
      curl -fsS --max-time 1 "http://127.0.0.1:${WEB_PORT:-6080}/" >/dev/null 2>&1 || return 1
      ;;
  esac
}

split_gazebo_args() {
  GAZEBO_EXTRA_ARGS=()

  if [[ -n "${GAZEBO_ARGS:-}" ]]; then
    read -r -a GAZEBO_EXTRA_ARGS <<< "${GAZEBO_ARGS}"
  fi

  if [[ -n "${GAZEBO_GUI_CONFIG:-}" ]]; then
    GAZEBO_EXTRA_ARGS+=(--gui-config "${GAZEBO_GUI_CONFIG}")
  fi
}

normalize_world_path() {
  local world="$1"

  world="${world//\\//}"

  case "${world}" in
    ./worlds/*)
      printf '/sim/worlds/%s\n' "${world#./worlds/}"
      ;;
    worlds/*)
      printf '/sim/worlds/%s\n' "${world#worlds/}"
      ;;
    ./models/*)
      printf '/sim/models/%s\n' "${world#./models/}"
      ;;
    models/*)
      printf '/sim/models/%s\n' "${world#models/}"
      ;;
    *)
      printf '%s\n' "${world}"
      ;;
  esac
}

build_world_args() {
  GAZEBO_WORLD_ARGS=("$@")

  if [[ "${GAZEBO_QUICK_START:-0}" == "1" ]]; then
    return
  fi

  if [[ "${#GAZEBO_WORLD_ARGS[@]}" -eq 0 ]]; then
    GAZEBO_WORLD_ARGS=("$(normalize_world_path "${GAZEBO_WORLD:-/sim/worlds/default.sdf}")")
    return
  fi

  if [[ "${#GAZEBO_WORLD_ARGS[@]}" -eq 1 ]]; then
    GAZEBO_WORLD_ARGS=("$(normalize_world_path "${GAZEBO_WORLD_ARGS[0]}")")
  fi
}

display_number() {
  local value="${DISPLAY#*:}"

  printf '%s\n' "${value%%.*}"
}

cleanup_x_display() {
  local number

  number="$(display_number)"
  mkdir -p /tmp/.X11-unix
  chmod 1777 /tmp/.X11-unix 2>/dev/null || true
  rm -f "/tmp/.X${number}-lock" "/tmp/.X11-unix/X${number}"
}

wait_for_x_display() {
  local pid="$1"
  local log_path="$2"
  local number
  local socket_path

  number="$(display_number)"
  socket_path="/tmp/.X11-unix/X${number}"

  for _ in {1..80}; do
    if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1 || [[ -S "${socket_path}" ]]; then
      return 0
    fi

    if ! kill -0 "${pid}" 2>/dev/null; then
      die "Xvnc exited before display ${DISPLAY} was ready. See ${log_path}."
    fi

    sleep 0.1
  done

  die "Timed out waiting for Xvnc display ${DISPLAY}. See ${log_path}."
}

wait_for_tcp() {
  local host="$1"
  local port="$2"
  local pid="$3"
  local name="$4"
  local probe_host="${host}"

  if [[ "${probe_host}" == "0.0.0.0" ]]; then
    probe_host="127.0.0.1"
  fi

  for _ in {1..80}; do
    if (echo >"/dev/tcp/${probe_host}/${port}") >/dev/null 2>&1; then
      return 0
    fi

    if ! kill -0 "${pid}" 2>/dev/null; then
      die "${name} exited before ${probe_host}:${port} was ready. See /data/logs/${name}.log."
    fi

    sleep 0.1
  done

  die "Timed out waiting for ${name} on ${probe_host}:${port}. See /data/logs/${name}.log."
}

start_xvnc() {
  local passwd_file
  local xvnc_pid
  local args=(
    "${DISPLAY}"
    -geometry "${VNC_GEOMETRY}"
    -depth "${VNC_DEPTH}"
    -rfbport "${VNC_PORT}"
    -FrameRate "${VNC_FRAME_RATE:-60}"
    -CompareFB "${VNC_COMPARE_FB:-0}"
    -ZlibLevel "${VNC_ZLIB_LEVEL:-0}"
    -ImprovedHextile="${VNC_IMPROVED_HEXTILE:-0}"
    -AlwaysShared=1
    -DisconnectClients=0
    -AcceptKeyEvents=1
    -AcceptPointerEvents=1
    -AcceptCutText=1
    -SendCutText=1
    -noreset
  )

  if [[ "${VNC_LISTEN_ADDRESS}" == "127.0.0.1" || "${VNC_LISTEN_ADDRESS}" == "localhost" ]]; then
    args+=(-localhost=1)
  else
    args+=(-localhost=0 -interface "${VNC_LISTEN_ADDRESS}")
  fi

  if [[ -n "${VNC_PIXEL_FORMAT:-}" ]]; then
    args+=(-pixelformat "${VNC_PIXEL_FORMAT}")
  fi

  if [[ -n "${VNC_PASSWORD:-}" ]]; then
    mkdir -p /tmp/vnc
    passwd_file=/tmp/vnc/passwd
    printf '%s\n' "${VNC_PASSWORD}" | vncpasswd -f >"${passwd_file}"
    chmod 600 "${passwd_file}"
    args+=(-SecurityTypes VncAuth -PasswordFile "${passwd_file}")
  else
    args+=(-SecurityTypes None)
  fi

  Xtigervnc "${args[@]}" >/data/logs/xvnc.log 2>&1 &
  xvnc_pid="$!"

  wait_for_x_display "${xvnc_pid}" "/data/logs/xvnc.log"
  wait_for_tcp "${VNC_LISTEN_ADDRESS}" "${VNC_PORT}" "${xvnc_pid}" "xvnc"
}

start_websockify() {
  local web_dir=/usr/share/novnc
  local websockify_pid

  [[ -d "${web_dir}" ]] || die "noVNC web directory not found: ${web_dir}"

  websockify \
    --web="${web_dir}" \
    --heartbeat="${WEB_HEARTBEAT:-30}" \
    "${WEB_LISTEN_ADDRESS}:${WEB_PORT}" \
    "${VNC_LISTEN_ADDRESS}:${VNC_PORT}" \
    >/data/logs/websockify.log 2>&1 &
  websockify_pid="$!"

  wait_for_tcp "${WEB_LISTEN_ADDRESS}" "${WEB_PORT}" "${websockify_pid}" "websockify"
}

prepare_web_gui_config() {
  local config_path="/data/.gz/sim/${GZ_SIM_MAJOR}/web-gui.config"
  local project_template_path="${GAZEBO_WEB_GUI_TEMPLATE:-/sim/gz-web-gui.config}"
  local template_path="/usr/local/share/gazebo/web-gui.config"

  if [[ -n "${GAZEBO_GUI_CONFIG:-}" ]]; then
    return
  fi

  if [[ -r "${project_template_path}" ]]; then
    template_path="${project_template_path}"
  fi

  [[ -r "${template_path}" ]] || die "web GUI config template not found: ${template_path}"

  mkdir -p "$(dirname "${config_path}")"
  cp "${template_path}" "${config_path}"
  chmod u+rw "${config_path}" 2>/dev/null || true
  export GAZEBO_GUI_CONFIG="${config_path}"
}

prepare_web() {
  export DISPLAY="${VNC_DISPLAY:-:1}"
  export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
  export QT_X11_NO_MITSHM="${GAZEBO_WEB_DISABLE_MITSHM:-0}"
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-gazebo}"
  export MESA_GLTHREAD="${MESA_GLTHREAD:-true}"
  export vblank_mode="${vblank_mode:-0}"

  mkdir -p /data/.gz /data/logs "${XDG_RUNTIME_DIR}"
  chmod 700 "${XDG_RUNTIME_DIR}" 2>/dev/null || true
  prepare_web_gui_config

  cleanup_x_display
  start_xvnc
  openbox >/data/logs/openbox.log 2>&1 &
  start_websockify

  printf '[gazebo] web: http://localhost:%s/\n' "${WEB_PORT}"
}

prepare_x11() {
  [[ -n "${DISPLAY:-}" ]] || die "x11 backend requires DISPLAY."

  export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
  export QT_X11_NO_MITSHM="${QT_X11_NO_MITSHM:-1}"
}

prepare_wayland() {
  [[ -n "${WAYLAND_DISPLAY:-}" ]] || die "wayland backend requires WAYLAND_DISPLAY."
  [[ -n "${XDG_RUNTIME_DIR:-}" ]] || die "wayland backend requires XDG_RUNTIME_DIR."

  if [[ "${GAZEBO_WAYLAND_NATIVE:-0}" == "1" ]]; then
    export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
    export QT_WAYLAND_DISABLE_WINDOWDECORATION="${QT_WAYLAND_DISABLE_WINDOWDECORATION:-1}"
    return
  fi

  [[ -n "${DISPLAY:-}" ]] || die "wayland session mode requires DISPLAY for XWayland. Set GAZEBO_WAYLAND_NATIVE=1 to force experimental native Wayland."

  # Gazebo / OGRE2 uses GLX for the 3D render window on Linux; XWayland is
  # more reliable than Qt's native Wayland path for the simulation viewport.
  export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
  export QT_X11_NO_MITSHM="${QT_X11_NO_MITSHM:-1}"
}

report_renderer() {
  local renderer=""

  if [[ -n "${DISPLAY:-}" ]] && command -v glxinfo >/dev/null 2>&1; then
    renderer="$(glxinfo -B 2>/dev/null | awk -F': ' '/OpenGL renderer string/ {print $2; exit}' || true)"
  fi

  if [[ -z "${renderer}" ]]; then
    printf '[gazebo] renderer: unknown\n'
    return
  fi

  printf '[gazebo] renderer: %s\n' "${renderer}"

  if [[ ("${GAZEBO_VERIFY_RENDERER:-0}" == "1" || "${GAZEBO_REQUIRE_GPU:-0}" == "1") && "${renderer}" =~ (llvmpipe|softpipe|swrast|Software|software) ]]; then
    die "GPU renderer verification failed; OpenGL is using software rendering (${renderer})."
  fi
}

require_gpu_device() {
  [[ "${GAZEBO_REQUIRE_GPU:-0}" == "1" ]] || return 0

  if compgen -G "/dev/dri/renderD*" >/dev/null || [[ -e /dev/dxg ]] || [[ -e /dev/nvidiactl ]]; then
    return 0
  fi

  die "GPU is required, but no GPU device is visible inside the container."
}

prepare_display() {
  case "${GAZEBO_DISPLAY_BACKEND:-web}" in
    web | novnc)
      prepare_web
      ;;
    x11)
      prepare_x11
      ;;
    wayland)
      prepare_wayland
      ;;
    *)
      die "Invalid GAZEBO_DISPLAY_BACKEND='${GAZEBO_DISPLAY_BACKEND}'. Use: web, x11, wayland."
      ;;
  esac
}

if [[ "${1:-}" == "--healthcheck" ]]; then
  healthcheck
  exit $?
fi

command -v gz >/dev/null 2>&1 || die "Gazebo CLI 'gz' not found. Use a full Gazebo package such as gz-jetty."

mkdir -p /data/.gz /data/logs
export LD_LIBRARY_PATH="${GZ_SIM_SYSTEM_PLUGIN_PATH:-/sim/plugins}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"

load_runtime_release
require_gpu_device
prepare_display
report_renderer
split_gazebo_args
build_world_args "$@"

# Keep a machine-readable startup log for the healthcheck while preserving
# normal `docker logs` output. Truncation prevents a previous successful run
# from making a broken restart look healthy.
: > /data/logs/gazebo.log
exec > >(tee -a /data/logs/gazebo.log) 2>&1
exec gz sim --force-version "${GZ_SIM_MAJOR}" "${GAZEBO_EXTRA_ARGS[@]}" "${GAZEBO_WORLD_ARGS[@]}"
