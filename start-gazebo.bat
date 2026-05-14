@echo off
setlocal EnableExtensions

cd /d "%~dp0"

if exist ".env" (
  for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
    if not "%%A"=="" (
      set "ENV_KEY=%%A"
      set "ENV_VALUE=%%B"
      call :set_env_value
    )
  )
)

set "MODE=%~1"
set "WORLD=%~2"
if "%MODE%"=="" set "MODE=web"

if /I "%MODE%"=="ui" (
  echo [gazebo] Windows launcher supports web mode only. Use WSL/Linux for native UI.
  exit /b 1
) else if /I "%MODE%"=="x11" (
  echo [gazebo] Windows launcher supports web mode only. Use WSL/Linux for native UI.
  exit /b 1
) else if /I "%MODE%"=="wayland" (
  echo [gazebo] Windows launcher supports web mode only. Use WSL/Linux for native UI.
  exit /b 1
) else if /I not "%MODE%"=="web" (
  if "%WORLD%"=="" (
    set "WORLD=%MODE%"
    set "MODE=web"
  ) else (
    echo [gazebo] Windows launcher supports web mode only. Use WSL/Linux for native UI.
    exit /b 1
  )
)

if not "%WORLD%"=="" set "GAZEBO_WORLD=%WORLD%"

if "%GAZEBO_IMAGE%"=="" set "GAZEBO_IMAGE=gazebo-universal-runtime:local"
if "%WEB_PORT%"=="" set "WEB_PORT=6080"
if "%GAZEBO_WEB_PROFILE%"=="" set "GAZEBO_WEB_PROFILE=balanced"

if /I "%GAZEBO_WEB_PROFILE%"=="fast" (
  if "%VNC_ZLIB_LEVEL%"=="" set "VNC_ZLIB_LEVEL=2"
) else if /I "%GAZEBO_WEB_PROFILE%"=="balanced" (
  if "%VNC_ZLIB_LEVEL%"=="" set "VNC_ZLIB_LEVEL=1"
) else if /I "%GAZEBO_WEB_PROFILE%"=="quality" (
  if "%VNC_ZLIB_LEVEL%"=="" set "VNC_ZLIB_LEVEL=1"
) else (
  echo [gazebo] Invalid GAZEBO_WEB_PROFILE=%GAZEBO_WEB_PROFILE%. Use balanced, fast, or quality.
  exit /b 1
)

if "%VNC_FRAME_RATE%"=="" set "VNC_FRAME_RATE=60"
if "%VNC_COMPARE_FB%"=="" set "VNC_COMPARE_FB=2"

if not exist worlds mkdir worlds
if not exist models mkdir models
if not exist plugins mkdir plugins
if not exist data mkdir data
if not exist .gazebo mkdir .gazebo

if not exist "gz-web-gui.config" (
  echo [gazebo] ERROR: gz-web-gui.config is missing. Restore it from the repository.
  exit /b 1
)

if not exist "index.html" (
  echo [gazebo] ERROR: index.html is missing. Restore it from the repository.
  exit /b 1
)

set "GPU_FILE=.gazebo\gpu.compose.yml"
if exist "%GPU_FILE%" del "%GPU_FILE%"

echo [gazebo] Cleaning old containers...
docker compose -f docker-compose.yml --profile ui down --remove-orphans
if errorlevel 1 exit /b 1

echo [gazebo] Building image...
docker compose -f docker-compose.yml build gazebo
if errorlevel 1 exit /b 1

echo [gazebo] Detecting GPU support...
if /I "%GAZEBO_GPU_MODE%"=="software" goto no_gpu
if /I "%GAZEBO_GPU_MODE%"=="dri" goto no_gpu
if /I "%GAZEBO_GPU_MODE%"=="dxg" goto no_gpu

docker run --rm --gpus all --entrypoint sh "%GAZEBO_IMAGE%" -lc "true" >nul 2>&1
if errorlevel 1 goto no_gpu

> "%GPU_FILE%" echo services:
>> "%GPU_FILE%" echo   gazebo: ^&gpu-nvidia
>> "%GPU_FILE%" echo     gpus: all
>> "%GPU_FILE%" echo     environment:
>> "%GPU_FILE%" echo       GAZEBO_GPU_MODE: "nvidia"
>> "%GPU_FILE%" echo       NVIDIA_VISIBLE_DEVICES: "all"
>> "%GPU_FILE%" echo       NVIDIA_DRIVER_CAPABILITIES: "graphics,utility,compute,display"
>> "%GPU_FILE%" echo       __GLX_VENDOR_LIBRARY_NAME: "nvidia"
>> "%GPU_FILE%" echo       __NV_PRIME_RENDER_OFFLOAD: "1"
>> "%GPU_FILE%" echo       __GL_SYNC_TO_VBLANK: "0"
>> "%GPU_FILE%" echo       __GL_THREADED_OPTIMIZATIONS: "1"
>> "%GPU_FILE%" echo       LIBGL_ALWAYS_SOFTWARE: "0"
>> "%GPU_FILE%" echo   gazebo-ui:
>> "%GPU_FILE%" echo     ^<^<: *gpu-nvidia

echo [gazebo] GPU: NVIDIA runtime
goto start

:no_gpu
echo [gazebo] GPU: Docker GPU runtime not available; using portable fallback.

:start
echo [gazebo] Starting web mode...
if exist "%GPU_FILE%" (
  docker compose -f docker-compose.yml -f "%GPU_FILE%" up -d --no-build gazebo
) else (
  docker compose -f docker-compose.yml up -d --no-build gazebo
)
if errorlevel 1 exit /b 1

set "WEB_URL=http://localhost:%WEB_PORT%/?profile=%GAZEBO_WEB_PROFILE%"
echo [gazebo] Ready: %WEB_URL%
start "" "%WEB_URL%"

if exist "%GPU_FILE%" (
  docker compose -f docker-compose.yml -f "%GPU_FILE%" ps
) else (
  docker compose -f docker-compose.yml ps
)
exit /b %ERRORLEVEL%

:set_env_value
for /f "tokens=* delims= " %%K in ("%ENV_KEY%") do set "ENV_KEY=%%K"
if "%ENV_KEY:~0,7%"=="export " set "ENV_KEY=%ENV_KEY:~7%"
if "%ENV_KEY%"=="" exit /b 0
if defined %ENV_KEY% exit /b 0
if "%ENV_VALUE:~0,1%"=="""" if "%ENV_VALUE:~-1%"=="""" set "ENV_VALUE=%ENV_VALUE:~1,-1%"
if "%ENV_VALUE:~0,1%"=="'" if "%ENV_VALUE:~-1%"=="'" set "ENV_VALUE=%ENV_VALUE:~1,-1%"
set "%ENV_KEY%=%ENV_VALUE%"
exit /b 0
