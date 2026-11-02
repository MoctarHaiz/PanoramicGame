#!/usr/bin/env python3
"""Makes Godot's iOS engine library run in the iOS Simulator of Apple Silicon Macs.

The official Godot 4.7 export template only has an Intel (x86_64) library for the Simulator.
The arm64 *device* objects work in the arm64 Simulator once each object says "iOS Simulator"
instead of "iOS" (Mach-O LC_BUILD_VERSION platform 2 -> 7); this changes those 4 bytes in place.
Used by tools/build_ios.sh for Simulator test builds only, never for App Store builds.

Usage: python3 tools/ios_simulator_lib.py DEVICE_LIB.a OUTPUT_ARM64_SIMULATOR_LIB.a
"""
import struct
import sys

LC_BUILD_VERSION = 0x32
PLATFORM_IOS = 2
PLATFORM_IOS_SIMULATOR = 7
MACHO_64 = b"\xcf\xfa\xed\xfe"


def convert(data: bytearray) -> int:
    if data[:8] != b"!<arch>\n":
        raise SystemExit("not a static library")
    pos, patched = 8, 0
    while pos < len(data):
        header = data[pos:pos + 60]
        name = header[:16].decode().strip()
        size = int(header[48:58].decode().strip())
        start = pos + 60 + (int(name[3:]) if name.startswith("#1/") else 0)  # BSD long names
        if data[start:start + 4] == MACHO_64:
            ncmds = struct.unpack_from("<I", data, start + 16)[0]
            offset = start + 32
            for _ in range(ncmds):
                cmd, cmdsize = struct.unpack_from("<II", data, offset)
                if cmd == LC_BUILD_VERSION:
                    platform = struct.unpack_from("<I", data, offset + 8)[0]
                    if platform != PLATFORM_IOS:
                        raise SystemExit(f"{name}: unexpected platform {platform}")
                    struct.pack_into("<I", data, offset + 8, PLATFORM_IOS_SIMULATOR)
                    patched += 1
                offset += cmdsize
        end = pos + 60 + size
        pos = end + (end & 1)
    return patched


if __name__ == "__main__":
    library = bytearray(open(sys.argv[1], "rb").read())
    count = convert(library)
    open(sys.argv[2], "wb").write(library)
    print(f"{count} objects marked for the iOS Simulator")
