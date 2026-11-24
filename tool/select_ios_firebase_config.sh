#!/bin/sh

set -eu

project_root="$(cd "${SRCROOT}/.." && pwd)"
backend="server"

old_ifs="$IFS"
IFS=','
for encoded in ${DART_DEFINES:-}; do
  decoded="$(printf '%s' "$encoded" | /usr/bin/base64 -D 2>/dev/null || true)"
  case "$decoded" in
    MOSIGAME_BACKEND=*) backend="${decoded#MOSIGAME_BACKEND=}" ;;
  esac
done
IFS="$old_ifs"

case "$backend" in
  server) config_name="server" ;;
  test|local) config_name="test" ;;
  *)
    echo "error: MOSIGAME_BACKEND must be server, test or local." >&2
    exit 1
    ;;
esac

source_plist="${project_root}/ios/Firebase/GoogleService-Info-${config_name}.plist"
destination_plist="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

/usr/bin/plutil -lint "$source_plist" >/dev/null
/bin/cp "$source_plist" "$destination_plist"
echo "Mosigame Firebase native backend: ${backend} (${config_name})"
