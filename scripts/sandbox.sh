#!/usr/bin/env bash
# Run an UNTRUSTED godot project command in a sandbox (review-round1 §5.1).
# Usage: sandbox.sh [--net] [--timeout SECS] [--cpu SECS] [--mem-mb MB] -- <cmd...>
#   sandbox.sh games/foo -- godot --headless --path /abs/proj --script res://x.gd
# The first arg may be a project dir: it is copied to a temp dir and bound
# read-write at the SAME path (so res:// mapping survives); everything else
# the host sees is read-only.
#
# Isolation (bwrap mode): no network (--unshare-net unless --net), PID + IPC
# namespaces, fresh tmpfs HOME (no ~/.ssh ~/.config leakage), clean env,
# host FS read-only, CPU/mem via ulimit inside, wall-clock via timeout.
# If bwrap is unavailable/refuses, falls back to DEGRADED mode (env -i +
# timeout + ulimit, NO namespaces) — clearly labeled, weaker: see docs/sandboxing.md.
set -uo pipefail
NET=0; TMO=120; CPU=90; MEM=1536
while [[ $# -gt 0 && "$1" == --* ]]; do
	case "$1" in
		--net) NET=1 ;;
		--timeout) TMO="$2"; shift ;;
		--cpu) CPU="$2"; shift ;;
		--mem-mb) MEM="$2"; shift ;;
		--) shift; break ;;
		*) echo "unknown option: $1" >&2; exit 2 ;;
	esac
	shift
done
[[ $# -gt 0 ]] || { echo "usage: sandbox.sh [--net] [--timeout S] [--cpu S] [--mem-mb MB] -- <cmd...>" >&2; exit 2; }

PROJ=""
if [[ -d "$1" && -f "$1/project.godot" ]]; then PROJ=$(cd "$1" && pwd); shift; fi
CMD=("$@")

# ulimits applied INSIDE the sandbox (bash builtin, inherited by the command).
LIMITS="ulimit -t $CPU -f 262144; ulimit -v $((MEM * 1024)) 2>/dev/null || true; exec"
GODOT_BIN=$(command -v godot)

TMP=""
cleanup() { [[ -n "$TMP" ]] && rm -rf "$TMP"; }
trap cleanup EXIT
BINDS=()
if [[ -n "$PROJ" ]]; then
	TMP=$(mktemp -d /tmp/sandbox-proj.XXXXXX)
	cp -r "$PROJ/." "$TMP/proj" 2>/dev/null || { echo "copy failed"; exit 1; }
	BINDS=(--bind "$TMP/proj" "$TMP/proj")
	CMD=("${CMD[@]/$PROJ/$TMP/proj}")   # rewrite project path to the copy
fi

if command -v bwrap >/dev/null && bwrap --ro-bind / / --dev /dev --proc /proc \
		--unshare-net --unshare-pid --unshare-ipc -- /bin/sh -c 'exit 0' 2>/dev/null; then
	echo "[sandbox] bwrap mode (net:off, clean env, tmpfs HOME)" >&2
	NETARG=(--unshare-net); [[ $NET -eq 1 ]] && NETARG=()
	exec timeout --kill-after=10 "$TMO" bwrap \
		--ro-bind / / --dev /dev --proc /proc "${BINDS[@]}" \
		--tmpfs "$HOME" --clearenv --setenv HOME "$HOME" \
		--setenv PATH "$(dirname "$GODOT_BIN"):/run/current-system/sw/bin:/usr/bin:/bin" \
		--setenv USER sandbox --setenv LOGNAME sandbox \
		"${NETARG[@]}" --unshare-pid --unshare-ipc --die-with-parent \
		-- /bin/sh -c "$LIMITS ${CMD[*]@Q}"
fi
# (bwrap probe failed) fall through to DEGRADED

echo "[sandbox] DEGRADED mode: no namespaces — env -i + timeout + ulimit only." >&2
echo "[sandbox] WEAKER: same user, full host FS visible, network NOT blocked." >&2
exec timeout --kill-after=10 "$TMO" /bin/sh -c \
	"ulimit -t $CPU -f 262144; ulimit -v $((MEM * 1024)) 2>/dev/null || true; exec env -i PATH=$(dirname "$GODOT_BIN"):/run/current-system/sw/bin:/usr/bin:/bin HOME=${TMP:-/tmp}/shome ${CMD[*]@Q}"
