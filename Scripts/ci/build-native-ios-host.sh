#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-lobster_wda_host_ios}"
SCHEME="${SCHEME:-LobsterWDAHost}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
CONFIGURATION="${CONFIGURATION:-Debug}"
PRODUCTS_DIR="${PRODUCTS_DIR:-$DERIVED_DATA_PATH/Build/Products/${CONFIGURATION}-iphoneos}"
APP_NAME="${APP_NAME:-LobsterWDAHost.app}"
ZIP_PKG_NAME="${ZIP_PKG_NAME:-LobsterWDAHost.app.zip}"
IPA_PKG_NAME="${IPA_PKG_NAME:-LobsterWDAHost.unsigned.ipa}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR}"
EXPECTED_BUNDLE_ID="${EXPECTED_BUNDLE_ID:-app.honey4212.crystal5671}"
PLIST_BUDDY="${PLIST_BUDDY:-/usr/libexec/PlistBuddy}"

APP_PATH="$PRODUCTS_DIR/$APP_NAME"
IPA_WORK_DIR=""

cleanup() {
  if [[ -n "$IPA_WORK_DIR" && -d "$IPA_WORK_DIR" ]]; then
    rm -rf "$IPA_WORK_DIR"
  fi
}
trap cleanup EXIT

mkdir -p "$OUTPUT_DIR"

xcodebuild clean build \
  -project WebDriverAgent.xcodeproj \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "$DESTINATION" \
  CODE_SIGNING_ALLOWED=NO ARCHS=arm64

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected native host app was not found at: $APP_PATH" >&2
  exit 1
fi

actual_bundle_id="$("$PLIST_BUDDY" -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist")"
if [[ "$actual_bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "Native host bundle id mismatch: expected $EXPECTED_BUNDLE_ID, got $actual_bundle_id" >&2
  exit 1
fi

rm -f "$OUTPUT_DIR/$ZIP_PKG_NAME" "$OUTPUT_DIR/$IPA_PKG_NAME"

(
  cd "$PRODUCTS_DIR"
  zip -qry "$OUTPUT_DIR/$ZIP_PKG_NAME" "$APP_NAME"
)

IPA_WORK_DIR="$(mktemp -d)"
mkdir -p "$IPA_WORK_DIR/Payload"
cp -R "$APP_PATH" "$IPA_WORK_DIR/Payload/"
(
  cd "$IPA_WORK_DIR"
  zip -qry "$OUTPUT_DIR/$IPA_PKG_NAME" Payload
)

if ! unzip -l "$OUTPUT_DIR/$IPA_PKG_NAME" | grep -q "Payload/$APP_NAME/"; then
  echo "Unsigned IPA does not contain Payload/$APP_NAME" >&2
  exit 1
fi

if ! unzip -l "$OUTPUT_DIR/$IPA_PKG_NAME" | grep -q "Payload/$APP_NAME/Frameworks/WebDriverAgentLib.framework/"; then
  echo "Unsigned IPA does not contain WebDriverAgentLib.framework" >&2
  exit 1
fi

if unzip -l "$OUTPUT_DIR/$IPA_PKG_NAME" | grep -E "Payload/$APP_NAME/PlugIns/.*\.xctest" >/dev/null; then
  echo "Unsigned native host IPA must not contain XCTest plug-ins" >&2
  exit 1
fi

# Verify-Native-Host-Ipa-Bundle-Id
python3 - "$OUTPUT_DIR/$IPA_PKG_NAME" "$EXPECTED_BUNDLE_ID" "$APP_NAME" <<'PY'
import plistlib
import sys
import zipfile

ipa_path, expected_bundle_id, app_name = sys.argv[1:4]
info_plist_name = f"Payload/{app_name}/Info.plist"
with zipfile.ZipFile(ipa_path) as ipa:
    with ipa.open(info_plist_name) as info_plist:
        actual_bundle_id = plistlib.load(info_plist).get("CFBundleIdentifier")

if actual_bundle_id != expected_bundle_id:
    raise SystemExit(
        f"Unsigned IPA bundle id mismatch: expected {expected_bundle_id}, got {actual_bundle_id}"
    )
PY

# Verify-Native-Host-Ipa-Local-Network-Plist
python3 - "$OUTPUT_DIR/$IPA_PKG_NAME" "$APP_NAME" <<'PY'
import plistlib
import sys
import zipfile

ipa_path, app_name = sys.argv[1:3]
info_plist_name = f"Payload/{app_name}/Info.plist"
with zipfile.ZipFile(ipa_path) as ipa:
    with ipa.open(info_plist_name) as info_plist:
        plist = plistlib.load(info_plist)

if not plist.get("NSLocalNetworkUsageDescription"):
    raise SystemExit("Unsigned IPA Info.plist is missing NSLocalNetworkUsageDescription")

bonjour_services = plist.get("NSBonjourServices") or []
if isinstance(bonjour_services, str):
    bonjour_services = [bonjour_services]
if not bonjour_services:
    raise SystemExit("Unsigned IPA Info.plist is missing NSBonjourServices")
if "_wda._tcp" not in bonjour_services and "_wda._tcp." not in bonjour_services:
    raise SystemExit("Unsigned IPA Info.plist NSBonjourServices is missing _wda._tcp")
PY

# Verify-Native-Host-Ipa-Network-Route
python3 - "$OUTPUT_DIR/$IPA_PKG_NAME" "$APP_NAME" <<'PY'
import sys
import zipfile

ipa_path, app_name = sys.argv[1:3]
needle = b"/wda/network"
app_prefix = f"Payload/{app_name}/"

with zipfile.ZipFile(ipa_path) as ipa:
    for entry in ipa.infolist():
        if entry.is_dir() or not entry.filename.startswith(app_prefix):
            continue
        with ipa.open(entry) as entry_file:
            if needle in entry_file.read():
                break
    else:
        raise SystemExit("Native host IPA is missing /wda/network diagnostic route")
PY

# Verify-Native-Host-Ipa-Proxy-Routes
python3 - "$OUTPUT_DIR/$IPA_PKG_NAME" "$APP_NAME" <<'PY'
import sys
import zipfile

ipa_path, app_name = sys.argv[1:3]
required_routes = [
    b"/proxy/status",
    b"/proxy/screenshot",
    b"/proxy/source",
]
found = {route: False for route in required_routes}
app_prefix = f"Payload/{app_name}/"

with zipfile.ZipFile(ipa_path) as ipa:
    for entry in ipa.infolist():
        if entry.is_dir() or not entry.filename.startswith(app_prefix):
            continue
        with ipa.open(entry) as entry_file:
            entry_bytes = entry_file.read()
        for route in required_routes:
            if route in entry_bytes:
                found[route] = True

missing_routes = [route.decode("ascii") for route, present in found.items() if not present]
if missing_routes:
    raise SystemExit(
        "Native host IPA is missing proxy routes: " + ", ".join(missing_routes)
    )
PY

echo "Created $OUTPUT_DIR/$ZIP_PKG_NAME"
echo "Created $OUTPUT_DIR/$IPA_PKG_NAME"
