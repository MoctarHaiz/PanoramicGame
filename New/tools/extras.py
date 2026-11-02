#!/usr/bin/env python3
"""Adds or removes the plugins of the optional extras, following config/game_config.cfg:

    [remove_ads] enabled=true    Google Play Billing (Android) and StoreKit 2 (iOS)
    [leaderboards] enabled=true  Google Play Games Services (Android) and Game Center (iOS)

The plugins are pinned releases, downloaded when a switch is turned on and deleted when it is
turned off (they stay out of git). The build scripts run this before each export.

Usage (from New/): python3 tools/extras.py
"""
import sys

from project_files import (NEW, install_from_zip, read_config, remove, set_autoload, set_editor_plugin,
                           set_exclude, set_preset_options)

BILLING_URL = ("https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/"
               "3.3.0/godot-google-play-billing.zip")
GAMES_URL = "https://github.com/godot-sdk-integrations/godot-play-game-services/releases/download/v3.4.0/addons.zip"
APPLE_BUILD = "a6d667dda4d4f7b008009d3704f679b06f81424f"  # 2026-10-01
APPLE_URL = (f"https://github.com/xibbon/GodotApplePlugins/releases/download/build-{APPLE_BUILD}/"
             f"GodotApplePlugins-addons-{APPLE_BUILD}.zip")

ADDONS = NEW / "addons"
BILLING = ADDONS / "GodotGooglePlayBilling"
GAMES = ADDONS / "GodotPlayGameServices"
APPLE_RUNTIME = ADDONS / "GodotApplePluginsRuntime"
STOREKIT = ADDONS / "GodotApplePluginsStoreKit"
GAME_CENTER = ADDONS / "GodotApplePluginsGameCenter"
GAMES_AUTOLOAD = "GodotPlayGameServices"


def apple(folders: list) -> dict:
    return {f"dist/addons/{f.name}": f for f in folders}


def forget_missing_extensions() -> None:
    """Drops removed plugins from Godot's list of native extensions (else the next run reports them)."""
    path = NEW / ".godot/extension_list.cfg"
    if path.exists():
        lines = [l for l in path.read_text().splitlines() if (NEW / l.removeprefix("res://")).exists()]
        path.write_text("".join(l + "\n" for l in lines))


def main() -> None:
    config = read_config()
    store = config.get("remove_ads", {}).get("enabled", False)
    boards = config.get("leaderboards", {})
    leaderboards = boards.get("enabled", False)
    games_project = boards.get("android_games_project_id", "")
    android_boards = leaderboards and bool(boards.get("android_leaderboard_id"))
    if android_boards and not games_project:
        sys.exit("Leaderboards: set android_games_project_id in config/game_config.cfg "
                 "(Play Console > Play Games Services > Configuration).")

    # Android
    if store:
        install_from_zip(BILLING_URL, {"GodotGooglePlayBilling": BILLING}, "Google Play Billing 3.3.0")
    else:
        remove(BILLING)
    set_editor_plugin("res://addons/GodotGooglePlayBilling/plugin.cfg", store)

    if android_boards:
        install_from_zip(GAMES_URL, {"addons/GodotPlayGameServices": GAMES}, "Google Play Games Services 3.4.0")
    else:
        remove(GAMES)
    set_editor_plugin("res://addons/GodotPlayGameServices/plugin.cfg", android_boards)
    set_autoload(GAMES_AUTOLOAD, "res://addons/GodotPlayGameServices/scripts/autoloads/godot_play_game_services.gd"
                 if android_boards else None)
    set_preset_options("Android", {"godot_play_game_services/game_id": f'"{games_project}"' if android_boards else None})
    strings = NEW / "android/build/res/values/strings.xml"  # written by the Play Games export plugin
    if not android_boards and strings.exists():
        strings.unlink()

    # iOS (GDExtensions, also loaded by the editor on a Mac; left out of Android exports)
    ios_boards = leaderboards and bool(boards.get("ios_leaderboard_id"))
    wanted = [f for f, on in ((STOREKIT, store), (GAME_CENTER, ios_boards)) if on]
    if wanted:
        install_from_zip(APPLE_URL, apple([APPLE_RUNTIME] + wanted), "Godot Apple Plugins (about 50 MB)")
    for folder in (STOREKIT, GAME_CENTER):
        if folder not in wanted:
            remove(folder)
    if not wanted:
        remove(APPLE_RUNTIME)
    set_exclude("Android", "addons/GodotApplePlugins*", bool(wanted))
    forget_missing_extensions()
    set_preset_options("iOS", {"entitlements/game_center": "true" if ios_boards else "false",
                               "application/min_ios_version": '"17.0"' if wanted else '"16.0"'})  # the plugins need 17

    print(f"Remove ads: {'on' if store else 'off'}. Leaderboards: Android {'on' if android_boards else 'off'}, "
          f"iOS {'on' if ios_boards else 'off'}")


if __name__ == "__main__":
    main()
