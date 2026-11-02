#!/usr/bin/env python3
"""Turns Firebase (analytics, crash reports, push notifications) on or off for the next export.

Firebase needs the config files of the Firebase project (Firebase console > Project settings):
    config/google-services.json      the Android app com.HaizStudio.ChakaZulu
    config/GoogleService-Info.plist  the iOS app
When they are there, this installs the godot-x Firebase plugin (pinned version, about 270 MB,
kept out of git), enables it in the export presets and patches the Android Gradle build.
Without them it switches everything back off. The build scripts run it before each export.

Usage (from New/): python3 tools/firebase.py [auto|on|off]      (default: auto)
"""
import re
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path

from project_files import set_editor_plugin, set_preset_options

VERSION = "3.1.0"
URL = f"https://github.com/godot-x/firebase/releases/download/{VERSION}/godotx_firebase.zip"
NEW = Path(__file__).resolve().parents[1]
ANDROID_JSON = NEW / "config/google-services.json"
IOS_PLIST = NEW / "config/GoogleService-Info.plist"
PLUGIN_CFG = "res://addons/godotx_firebase/plugin.cfg"
MODULES = ["core", "analytics", "crashlytics", "messaging"]
GRADLE = NEW / "android/build/build.gradle"
GRADLE_HEAD = """// firebase-begin (added by tools/firebase.py)
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath 'com.google.gms:google-services:4.4.4'
        classpath 'com.google.firebase:firebase-crashlytics-gradle:3.0.6'
    }
}
// firebase-end
"""
GRADLE_TAIL = """
// firebase-begin (added by tools/firebase.py)
apply plugin: 'com.google.gms.google-services'
apply plugin: 'com.google.firebase.crashlytics'
// firebase-end
"""


def install_plugin() -> None:
    if (NEW / "addons/godotx_firebase/plugin.cfg").exists():
        return
    print(f"Downloading the Firebase plugin {VERSION} (about 75 MB)...")
    with tempfile.TemporaryDirectory() as tmp:
        archive = Path(tmp, "firebase.zip")
        urllib.request.urlretrieve(URL, archive)
        with zipfile.ZipFile(archive) as z:
            z.extractall(tmp)
        root = Path(tmp, "godotx_firebase")
        shutil.copytree(root / "addons/godotx_firebase", NEW / "addons/godotx_firebase")
        for module in (root / "android").iterdir():
            shutil.copytree(module, NEW / "android" / module.name, dirs_exist_ok=True)
        for module in (root / "ios/plugins").iterdir():
            dest = NEW / "ios/plugins" / module.name
            if module.is_dir():
                shutil.copytree(module, dest, dirs_exist_ok=True)
            else:
                shutil.copy2(module, dest)


def patch_gradle(on: bool) -> None:
    if not GRADLE.exists():
        return
    text = re.sub(r"\n?// firebase-begin.*?// firebase-end\n", "\n", GRADLE.read_text(), flags=re.S).lstrip("\n")
    if on:
        text = GRADLE_HEAD + text.rstrip("\n") + "\n" + GRADLE_TAIL
    GRADLE.write_text(text)


def switch(android: bool, ios: bool) -> None:
    if android or ios:
        install_plugin()
    for src, dest, on in ((ANDROID_JSON, NEW / "google-services.json", android),
                          (IOS_PLIST, NEW / "GoogleService-Info.plist", ios)):
        if on:
            shutil.copy2(src, dest)
        elif dest.exists():
            dest.unlink()
    set_editor_plugin(PLUGIN_CFG, android or ios)
    flag = lambda on: "true" if on else "false"
    android_values = {f"firebase/enable_{m}": flag(android) for m in MODULES}
    android_values.update({"firebase/android_config_file": '"res://google-services.json"',
                           "firebase/privacy_safe_defaults": "true",
                           "permissions/post_notifications": flag(android)})
    if android or (NEW / "addons/godotx_firebase").exists():
        set_preset_options("Android", android_values)
    ios_values = {f"firebase/enable_{m}": flag(ios) for m in MODULES}
    ios_values.update({"firebase/ios_config_file": '"res://GoogleService-Info.plist"',
                       "firebase/privacy_safe_defaults": "true",
                       "entitlements/push_notifications": '"Production"' if ios else '"Disabled"'})
    if ios or (NEW / "addons/godotx_firebase").exists():
        set_preset_options("iOS", ios_values)
    patch_gradle(android)
    print(f"Firebase: Android {'on' if android else 'off'}, iOS {'on' if ios else 'off'}")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "auto"
    if mode == "off":
        switch(False, False)
    elif mode == "on" and not (ANDROID_JSON.exists() or IOS_PLIST.exists()):
        sys.exit("Put google-services.json and/or GoogleService-Info.plist in New/config/ first.")
    else:
        switch(ANDROID_JSON.exists(), IOS_PLIST.exists())
