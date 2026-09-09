#!/bin/zsh

set -eu

script_dir=${0:A:h}
skill_dir=${script_dir:h}
target_app=${CODEX_CALENDAR_HELPER_APP:-"${HOME}/Applications/Codex Calendar Helper.app"}
target_parent=${target_app:h}
build_root=$(mktemp -d "${TMPDIR:-/tmp}/codex-calendar-helper.XXXXXX")
staged_app="${build_root}/Codex Calendar Helper.app"
backup_app="${build_root}/previous.app"

cleanup() {
  rm -rf "${build_root}"
}
trap cleanup EXIT

mkdir -p "${staged_app}/Contents/MacOS" "${build_root}/module-cache" "${target_parent}"
cp "${skill_dir}/assets/CalendarHelper-Info.plist" "${staged_app}/Contents/Info.plist"

xcrun swiftc \
  -O \
  -module-cache-path "${build_root}/module-cache" \
  "${script_dir}/calendar.swift" \
  -o "${staged_app}/Contents/MacOS/calendar-helper"

plutil -lint "${staged_app}/Contents/Info.plist"
codesign --force --sign - --identifier com.matthew4tch.CodexCalendarHelper "${staged_app}"
codesign --verify --strict "${staged_app}"

if [[ -e "${target_app}" ]]; then
  mv "${target_app}" "${backup_app}"
fi

if ! mv "${staged_app}" "${target_app}"; then
  if [[ -e "${backup_app}" ]]; then
    mv "${backup_app}" "${target_app}"
  fi
  exit 1
fi

print -r -- "Installed ${target_app}"
print -r -- "Run '${script_dir}/calendar calendars' to request or verify Calendar access."
