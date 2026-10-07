#!/usr/bin/env bash
# Headless Godot screenshot on a GPU-less NixOS host.
# Path: weston (headless Wayland compositor) + lavapipe (software Vulkan) + Godot wayland/vulkan.
# Xvfb/GLX and EGL-on-X11 are DEAD ENDS on this host — see docs/rendering.md before "fixing" this.
#
# Usage:
#   render_shot.sh <project-dir> <out.png> [--scene res://foo.tscn] [--width N] [--height N] [-- godot-extra-args...]
#
# The project is responsible for saving its own frame (await RenderingServer.frame_post_draw;
# get_viewport().get_texture().get_image().save_png(...)). This script guarantees a display,
# asserts the render backend, and fails loudly if the expected PNG is missing.
set -euo pipefail

PROJ="${1:?usage: render_shot.sh <project-dir> <out.png> [opts]}"; shift
OUT="${1:?usage: render_shot.sh <project-dir> <out.png> [opts]}"; shift

SCENE=""; WIDTH=640; HEIGHT=360; TIMEOUT=180
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scene)   SCENE="$2"; shift 2;;
    --width)   WIDTH="$2"; shift 2;;
    --height)  HEIGHT="$2"; shift 2;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --) shift; break;;
    *) echo "unknown option: $1" >&2; exit 2;;
  esac
done

ICD="${MESA_ICD:-${VK_DRIVER_FILES:-}}"
if [[ -z "$ICD" ]]; then
  ICD=$(ls /nix/store/*-mesa-*/share/vulkan/icd.d/lvp_icd.x86_64.json 2>/dev/null | head -1 || true)
fi
[[ -n "$ICD" && -f "$ICD" ]] || { echo "ERROR: lavapipe ICD not found (set MESA_ICD)" >&2; exit 1; }

RUNTIME=$(mktemp -d /tmp/weston-factory.XXXXXX); chmod 700 "$RUNTIME"
export XDG_RUNTIME_DIR="$RUNTIME"   # weston creates its socket under $XDG_RUNTIME_DIR
SOCKET="wl-factory-$$"
cleanup() { [[ -n "${WPID:-}" ]] && kill "$WPID" 2>/dev/null || true; rm -rf "$RUNTIME"; }
trap cleanup EXIT

weston --backend=headless --socket="$SOCKET" --width="$WIDTH" --height="$HEIGHT" > "$RUNTIME/weston.log" 2>&1 &
WPID=$!
sleep 2
kill -0 "$WPID" || { echo "ERROR: weston failed to start:"; tail -5 "$RUNTIME/weston.log"; exit 1; }

rm -f "$OUT"
# Convention: the project reads SHOT_OUT and saves its frame there.
# --quit-after guarantees termination even if the project forgets to quit().
SHOT_OUT="$OUT" WAYLAND_DISPLAY="$SOCKET" XDG_RUNTIME_DIR="$RUNTIME" VK_DRIVER_FILES="$ICD" timeout "$TIMEOUT" \
  godot --path "$PROJ" --display-driver wayland --rendering-driver vulkan \
  --quit-after 3600 "$@" ${SCENE:+"$SCENE"} \
  > "$RUNTIME/godot.log" 2>&1 || true

if grep -q "llvmpipe" "$RUNTIME/godot.log"; then
  echo "backend: Vulkan/llvmpipe (software) OK"
else
  echo "WARNING: render backend not asserted as llvmpipe; godot log tail:"
  grep -viE 'cursor|ALSA|alsa' "$RUNTIME/godot.log" | tail -8
fi

if [[ -f "$OUT" ]]; then
  echo "OK: $OUT ($(stat -c%s "$OUT") bytes)"
else
  echo "FAIL: no screenshot at $OUT; godot log tail:"
  grep -viE 'cursor|ALSA|alsa' "$RUNTIME/godot.log" | tail -20
  exit 1
fi
