#!/bin/bash
# Builds Chaka Zulu for Google Play, signed with the 2019 Haiz Studio key (so it updates the existing
# Play listing), and checks the signature.
#
#   tools/build_android.sh            build/android/chakazulu-<version>.aab   (upload this one)
#   tools/build_android.sh --apk      the same, plus a signed release APK to try on a phone
#   tools/build_android.sh --debug    only a debug APK (Google test ads), no key needed
#
# The key comes from signing/keystore.properties (storeFile, storePassword, keyAlias, keyPassword),
# or from the file named by KEY_PROPS. Passwords are passed through the environment, never printed.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
KEY_PROPS=${KEY_PROPS:-signing/keystore.properties}
# Fingerprint of the 2019 key (alias key0, CN=Haiz Studio): the one Play knows for this app.
EXPECTED_SHA256="08:BE:42:CB:BD:82:2E:05:F0:75:0B:F7:06:58:E7:70:9E:F0:4B:D8:6A:76:7C:51:E0:2C:BE:75:E8:3C:85:B2"
JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}
export JAVA_HOME
KEYTOOL="$JAVA_HOME/bin/keytool"

VERSION=$(sed -n 's/^config\/version="\(.*\)"$/\1/p' project.godot)
CODE=$(sed -n 's/^version\/code=//p' export_presets.cfg | head -1)
mkdir -p build/android && touch build/.gdignore  # Godot must not import what is built here

# Optional services follow config/: Firebase when its files exist, extras when switched on.
python3 tools/firebase.py auto
python3 tools/extras.py

if [[ "${1:-}" == "--debug" ]]; then
	"$GODOT" --headless --path . --export-debug "Android" build/android/chakazulu-debug.apk
	echo "Debug APK: build/android/chakazulu-debug.apk"
	exit 0
fi

prop() { sed -n "s/^$1=//p" "$KEY_PROPS" | tr -d '\r'; }
[[ -f "$KEY_PROPS" ]] || { echo "Missing $KEY_PROPS (see docs/RELEASE.md)"; exit 1; }
STORE_FILE=$(prop storeFile)
[[ "$STORE_FILE" == /* ]] || STORE_FILE="$(cd "$(dirname "$KEY_PROPS")" && pwd)/$STORE_FILE"
[[ -f "$STORE_FILE" ]] || { echo "The keystore named in $KEY_PROPS was not found"; exit 1; }
STORE_PASS=$(prop storePassword)
KEY_PASS=$(prop keyPassword)
ALIAS=$(prop keyAlias)
export STORE_PASS KEY_PASS

# Godot signs with one password for the keystore and the key. When they differ, sign with a
# temporary copy whose key password is set to the keystore one (same key, same certificate).
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if [[ "$STORE_PASS" != "$KEY_PASS" ]]; then
	cp "$STORE_FILE" "$TMP/release.keystore"
	"$KEYTOOL" -keypasswd -keystore "$TMP/release.keystore" -alias "$ALIAS" \
		-storepass:env STORE_PASS -keypass:env KEY_PASS -new:env STORE_PASS
	STORE_FILE="$TMP/release.keystore"
fi
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$STORE_FILE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$STORE_PASS"

APKSIGNER="$(ls -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}"/build-tools/* | sort -V | tail -1)/apksigner"

check_signature() {
	local sha
	if [[ "$1" == *.apk ]]; then  # APK signature scheme v2+: apksigner prints the digest in hex
		sha=$("$APKSIGNER" verify --print-certs "$1" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p' \
			| tr 'a-f' 'A-F' | sed 's/../&:/g; s/:$//')
	else  # bundles are jar-signed
		sha=$("$KEYTOOL" -printcert -jarfile "$1" | sed -n 's/^[[:space:]]*SHA256: //p' | head -1)
	fi
	if [[ "$sha" != "$EXPECTED_SHA256" ]]; then
		echo "WRONG KEY for $1: $sha"
		exit 1
	fi
	echo "Signed with the Play Store key: $1"
}

AAB="build/android/chakazulu-$VERSION.aab"
rm -f "$AAB"
"$GODOT" --headless --path . --export-release "Google Play" "$AAB"
[[ -f "$AAB" ]] || { echo "Export failed"; exit 1; }
check_signature "$AAB"

if [[ "${1:-}" == "--apk" ]]; then
	APK="build/android/chakazulu-$VERSION-release.apk"
	rm -f "$APK"
	"$GODOT" --headless --path . --export-release "Android" "$APK"
	check_signature "$APK"
fi
echo "Chaka Zulu $VERSION (version code $CODE) is ready: $AAB"
