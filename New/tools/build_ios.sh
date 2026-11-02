#!/bin/bash
# Builds Chaka Zulu for iPhone and iPad.
#
#   tools/build_ios.sh               Xcode project for the App Store in build/ios/ (needs the Apple
#                                    Team ID in the "iOS" export preset). Open ChakaZulu.xcodeproj,
#                                    then Product > Archive > Distribute App.
#   tools/build_ios.sh --check       the same, then compiles it for iPhone without signing (no Team ID
#                                    needed), to catch build problems early
#   tools/build_ios.sh --simulator ["iPhone 18 Pro Max"] [--tour]
#                                    builds and starts the game in the iOS Simulator. With --tour the
#                                    bot plays and screenshots go to build/ios-sim/shots/.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
MODE=${1:-}

# Home screen name ("Chaka Zulu", as on Android) and Apple's tracking prompt in
# the player's language, in the en/fr InfoPlist.strings that Godot writes.
localize_plist() {
	local app="$1/ChakaZulu"
	/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Chaka Zulu" "$app/ChakaZulu-Info.plist"
	local lang text
	for lang in en fr; do
		[[ -f "$app/$lang.lproj/InfoPlist.strings" ]] || continue
		text="This lets us show you ads that are more relevant to you. Ads keep the game free."
		[[ $lang == fr ]] && text="Cela nous permet de te montrer des pubs plus adaptées à tes goûts. Les pubs gardent le jeu gratuit."
		sed -i '' '/^CFBundleDisplayName = /d' "$app/$lang.lproj/InfoPlist.strings"
		printf 'CFBundleDisplayName = "Chaka Zulu";\nNSUserTrackingUsageDescription = "%s";\n' "$text" \
			>> "$app/$lang.lproj/InfoPlist.strings"
	done
}

mkdir -p build && touch build/.gdignore  # Godot must not import what is built here
# Optional services follow config/: Firebase when its files exist, extras when switched on.
python3 tools/firebase.py auto
python3 tools/extras.py

if [[ "$MODE" != "--simulator" ]]; then
	team=$(python3 -c '
import re, sys
text = open("export_presets.cfg").read()
for m in re.finditer(r"^\[preset\.(\d+)\]\n(.*?)\n\[preset\.\1\.options\]\n(.*?)(?=^\[preset|\Z)", text, re.M | re.S):
    if "name=\"iOS\"" in m.group(2):
        print(re.search(r"^application/app_store_team_id=\"(.*)\"$", m.group(3), re.M).group(1))')
	if [[ "$MODE" == "--check" && -z "$team" ]]; then
		# Compiling without signing still needs a Team ID to export: use a stand-in, then restore.
		cp export_presets.cfg build/.export_presets.backup
		trap 'mv build/.export_presets.backup export_presets.cfg' EXIT
		python3 - <<'EOF'
import re
text = open("export_presets.cfg").read()
start = text.index('name="iOS"\n')
options = text.index("application/app_store_team_id=\"\"", start)
empty = 'application/app_store_team_id=""'
open("export_presets.cfg", "w").write(text[:options] + 'application/app_store_team_id="CHECKONLY0"' + text[options + len(empty):])
EOF
	elif [[ -z "$team" ]]; then
		echo "Set your Apple Team ID first (Project > Export > iOS > App Store Team ID, or"
		echo "application/app_store_team_id in export_presets.cfg). See docs/RELEASE.md."
		exit 1
	fi
	rm -rf build/ios && mkdir -p build/ios
	"$GODOT" --headless --path . --export-release "iOS" build/ios/ChakaZulu.ipa
	localize_plist build/ios
	# Automatic signing archives with the development identity and re-signs for the App Store when
	# distributing; Godot's fixed "Apple Distribution" in Release conflicts with it in Xcode.
	sed -i '' 's/CODE_SIGN_IDENTITY = "Apple Distribution";/CODE_SIGN_IDENTITY = "Apple Development";/' \
		build/ios/ChakaZulu.xcodeproj/project.pbxproj
	if [[ "$MODE" == "--check" ]]; then
		xcodebuild -project build/ios/ChakaZulu.xcodeproj -scheme ChakaZulu -configuration Release \
			-destination 'generic/platform=iOS' -derivedDataPath build/ios/dd CODE_SIGNING_ALLOWED=NO build \
			| grep -E "error:|BUILD (SUCCEEDED|FAILED)"
	else
		echo "Open build/ios/ChakaZulu.xcodeproj in Xcode, then Product > Archive > Distribute App."
	fi
	exit 0
fi

# ------------------------------------------------------------------ Simulator
DEVICE_NAME=${2:-iPhone 18 Pro Max}
[[ "$DEVICE_NAME" == "--tour" ]] && DEVICE_NAME="iPhone 18 Pro Max"
TOUR=false
for arg in "$@"; do [[ "$arg" == "--tour" ]] && TOUR=true; done
OUT=build/ios-sim
rm -rf "$OUT" && mkdir -p "$OUT"
"$GODOT" --headless --path . --export-debug "iOS Simulator" "$OUT/ChakaZulu.ipa"
localize_plist "$OUT"

# Godot's template has an Intel-only Simulator library: add an Apple Silicon one, made from the
# iPhone library (tools/ios_simulator_lib.py) plus two Metal names the Simulator lacks.
SIM_LIB="$OUT/ChakaZulu.xcframework/ios-arm64_x86_64-simulator/libgodot.a"
if ! xcrun lipo -archs "$SIM_LIB" | grep -qw arm64; then
	TMP=$(mktemp -d)
	trap 'rm -rf "$TMP"' EXIT
	cat > "$TMP/stubs.m" <<'EOF'
#import <Foundation/Foundation.h>
NSString *const MTLIOErrorDomain = @"MTLIOErrorDomain";
NSString *const MTLTensorDomain = @"MTLTensorDomain";
EOF
	xcrun -sdk iphonesimulator clang -arch arm64 -mios-simulator-version-min=16.0 -c "$TMP/stubs.m" -o "$TMP/stubs.o"
	python3 tools/ios_simulator_lib.py "$OUT/ChakaZulu.xcframework/ios-arm64/libgodot.a" "$TMP/arm64.a"
	xcrun libtool -static -no_warning_for_no_symbols -o "$TMP/arm64_stubs.a" "$TMP/arm64.a" "$TMP/stubs.o"
	xcrun lipo -thin x86_64 "$SIM_LIB" -output "$TMP/x86_64.a" 2>/dev/null || cp "$SIM_LIB" "$TMP/x86_64.a"
	xcrun lipo -create "$TMP/arm64_stubs.a" "$TMP/x86_64.a" -output "$SIM_LIB"
fi

xcodebuild -project "$OUT/ChakaZulu.xcodeproj" -scheme ChakaZulu -configuration Debug -sdk iphonesimulator \
	-destination 'generic/platform=iOS Simulator' -derivedDataPath "$OUT/dd" ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
	CODE_SIGNING_ALLOWED=NO build | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
APP="$OUT/dd/Build/Products/Debug-iphonesimulator/ChakaZulu.app"

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
for runtime, devices in json.load(sys.stdin)["devices"].items():
    for d in devices:
        if d["name"] == name and "iOS" in runtime:
            print(d["udid"]); sys.exit()
sys.exit("No Simulator named " + name)' "$DEVICE_NAME")
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
open -g -b com.apple.iphonesimulator 2>/dev/null || true  # the Simulator window, when installed
xcrun simctl terminate "$UDID" com.HaizStudio.ChakaZulu 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
if ! $TOUR; then
	xcrun simctl launch "$UDID" com.HaizStudio.ChakaZulu
	exit 0
fi

# Tour: the game writes "shot <name>" to user://tour.txt when a screen is ready (tests/device_tour.gd).
mkdir -p "$OUT/shots"
DATA=$(xcrun simctl get_app_container "$UDID" com.HaizStudio.ChakaZulu data)
rm -f "$DATA/Documents/tour.txt" "$DATA/Documents/tour_ack.txt"
SIMCTL_CHILD_CHAKAZULU_TOUR=1 SIMCTL_CHILD_CHAKAZULU_NOT_EEA=1 xcrun simctl launch "$UDID" com.HaizStudio.ChakaZulu
TAG=$(echo "$DEVICE_NAME" | tr ' ' '_')
taken=""
for _ in $(seq 1 600); do  # up to 4 minutes
	sleep 0.4
	status=$(cat "$DATA/Documents/tour.txt" 2>/dev/null || true)
	shot=${status#shot }
	if [[ "$status" == shot* && " $taken " != *" $shot "* ]]; then
		xcrun simctl io "$UDID" screenshot "$OUT/shots/${TAG}__$shot.png" >/dev/null 2>&1
		echo "$shot" > "$DATA/Documents/tour_ack.txt"  # the tour can go on
		taken="$taken $shot"
		echo "screenshot: $shot"
	fi
	[[ "$status" == "done" ]] && break
done
echo "Screenshots in $OUT/shots/"
