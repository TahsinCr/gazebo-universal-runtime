@echo off
setlocal EnableExtensions

cd /d "%~dp0"

echo [gazebo] Stopping containers...
if exist ".gazebo\gpu.compose.yml" (
  docker compose -f docker-compose.yml -f ".gazebo\gpu.compose.yml" --profile ui down --remove-orphans %*
) else (
  docker compose -f docker-compose.yml --profile ui down --remove-orphans %*
)
if errorlevel 1 exit /b 1

echo [gazebo] Stopped.
