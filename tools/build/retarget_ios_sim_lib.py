#!/usr/bin/env python3
"""Workaround for the Godot 4.7.2 official iOS template (toolchain dry run, Phase 2).

Why: the template's simulator slice
`libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a` is x86_64 only
(`lipo -info` says "Non-fat file ... architecture: x86_64"), and the only simulator runtime on this
Mac (iOS 26.5) ships an arm64-only `dyld_sim`. An x86_64 simulator app cannot run there.

What: copies the arm64 *device* slice and rewrites every object's LC_BUILD_VERSION platform from
2 (iOS) to 7 (iOS Simulator), in place. Byte sizes do not change, so the archive's symbol table
stays valid. Same engine code as the device build, relinked against the simulator SDK.

Delete this file once an official template ships an arm64 simulator slice.

Usage: python3 -I retarget_ios_sim_lib.py <device libgodot.a> <output libgodot.a>
Exit 0 on success, 1 on any object it cannot retarget.
"""

import struct
import sys

AR_MAGIC: bytes = b"!<arch>\n"
AR_HEADER_SIZE: int = 60
MH_MAGIC_64: int = 0xFEEDFACF
LC_BUILD_VERSION: int = 0x32
LC_VERSION_MIN_IPHONEOS: int = 0x25
PLATFORM_IOS: int = 2
PLATFORM_IOS_SIMULATOR: int = 7


def retarget_object(buf: bytearray, start: int) -> str:
    """Returns 'patched', 'already', 'not_macho' or an error string."""
    if len(buf) - start < 32:
        return "not_macho"
    magic: int = struct.unpack_from("<I", buf, start)[0]
    if magic != MH_MAGIC_64:
        return "not_macho"
    ncmds: int = struct.unpack_from("<I", buf, start + 16)[0]
    off: int = start + 32
    found: bool = False
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", buf, off)
        if cmd == LC_VERSION_MIN_IPHONEOS:
            return "error: LC_VERSION_MIN_IPHONEOS cannot be retargeted in place"
        if cmd == LC_BUILD_VERSION:
            platform: int = struct.unpack_from("<I", buf, off + 8)[0]
            if platform == PLATFORM_IOS:
                struct.pack_into("<I", buf, off + 8, PLATFORM_IOS_SIMULATOR)
                found = True
            elif platform == PLATFORM_IOS_SIMULATOR:
                return "already"
            else:
                return "error: unexpected platform %d" % platform
        off += cmdsize
    return "patched" if found else "error: no LC_BUILD_VERSION"


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 1
    with open(argv[1], "rb") as f:
        buf: bytearray = bytearray(f.read())
    if not buf.startswith(AR_MAGIC):
        print("ERROR: not a static archive (fat or thin Mach-O archives only): " + argv[1])
        return 1
    counts: dict[str, int] = {}
    errors: int = 0
    off: int = len(AR_MAGIC)
    while off + AR_HEADER_SIZE <= len(buf):
        header: bytes = bytes(buf[off:off + AR_HEADER_SIZE])
        name: str = header[0:16].decode("ascii").strip()
        size: int = int(header[48:58].decode("ascii").strip())
        data_start: int = off + AR_HEADER_SIZE
        name_len: int = 0
        if name.startswith("#1/"):
            name_len = int(name[3:])
            name = buf[data_start:data_start + name_len].decode("ascii", "replace").rstrip("\0")
        result: str = retarget_object(buf, data_start + name_len)
        if result.startswith("error"):
            errors += 1
            print("ERROR: %s: %s" % (name, result))
        counts[result] = counts.get(result, 0) + 1
        off = data_start + size + (size % 2)
    with open(argv[2], "wb") as f:
        f.write(buf)
    print("retarget_ios_sim_lib: %s -> %s" % (argv[1], argv[2]))
    print("  members: " + ", ".join("%s=%d" % (k, v) for k, v in sorted(counts.items())))
    return 1 if errors > 0 or counts.get("patched", 0) == 0 else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
