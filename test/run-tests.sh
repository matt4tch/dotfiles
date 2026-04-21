#!/usr/bin/env bash
#
# Build and run the dotfiles install script inside a clean container for each
# supported Linux distro, then execute test/verify.sh inside the image. A
# build failure for any distro is a test failure.
#
# Usage:
#   ./test/run-tests.sh                 # run all three (ubuntu, fedora, arch)
#   ./test/run-tests.sh ubuntu          # run only one distro
#
# Pass --no-cache to docker build manually if you suspect a stale layer is
# masking a real failure, e.g.:
#   docker build --no-cache -f test/Dockerfile.ubuntu -t dotfiles-test-ubuntu .

set -euo pipefail

# Preflight: confirm docker daemon is reachable.
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon not running. Start Docker Desktop and retry." >&2
  exit 2
fi

supported=(ubuntu fedora arch)

distros=("${supported[@]}")
if [ $# -gt 0 ]; then
  chosen="$1"
  found=0
  for d in "${supported[@]}"; do
    if [ "$d" = "$chosen" ]; then
      found=1
      break
    fi
  done
  if [ "$found" -ne 1 ]; then
    echo "ERROR: unknown distro '$chosen'. Valid options: ${supported[*]}" >&2
    exit 1
  fi
  distros=("$chosen")
fi

declare -a passed=() failed=()
for d in "${distros[@]}"; do
  echo "==> Building $d"
  if docker build --progress=plain -f "test/Dockerfile.$d" -t "dotfiles-test-$d" . ; then
    passed+=("$d")
  else
    failed+=("$d")
  fi
done

echo
echo "Summary:"
if ((${#passed[@]})); then
  printf '  PASS %s\n' "${passed[@]}"
fi
if ((${#failed[@]})); then
  printf '  FAIL %s\n' "${failed[@]}"
fi

((${#failed[@]} == 0))
