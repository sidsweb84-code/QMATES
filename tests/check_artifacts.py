#!/usr/bin/env python3
"""
Checks the two Studio files in build/ that users import:

1. They are up to date: a fresh Rojo build of default.project.json and
   installer.project.json must be byte-identical to the committed files.
2. The binary installer model really saves ServerMain as Disabled (Studio only
   loads the legacy `Disabled` property from files; `Enabled` is not saved), so
   pressing Play before installing can't start a server from Workspace.
3. The place file's ServerMain is enabled.

Reads Roblox's binary format directly (header, LZ4/uncompressed chunks,
INST and PROP chunks).

Usage: python3 tests/check_artifacts.py [path/to/rojo]
"""
import os
import shutil
import struct
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILDS = [
    ("default.project.json", "build/StealPokemon.rbxl"),
    ("installer.project.json", "build/StealPokemon_Installer.rbxm"),
]


def lz4_block(src, size):
    dst = bytearray()
    i, n = 0, len(src)
    while i < n:
        token = src[i]
        i += 1
        lit = token >> 4
        if lit == 15:
            while True:
                b = src[i]
                i += 1
                lit += b
                if b != 255:
                    break
        dst += src[i:i + lit]
        i += lit
        if i >= n:
            break
        offset = src[i] | (src[i + 1] << 8)
        i += 2
        mlen = token & 15
        if mlen == 15:
            while True:
                b = src[i]
                i += 1
                mlen += b
                if b != 255:
                    break
        mlen += 4
        start = len(dst) - offset
        for k in range(mlen):
            dst.append(dst[start + k])
    if len(dst) != size:
        raise ValueError("LZ4 size mismatch")
    return bytes(dst)


def chunks(data):
    if data[:8] != b"<roblox!":
        raise ValueError("not a binary Roblox file")
    pos = 32
    while pos < len(data):
        name = data[pos:pos + 4]
        clen, ulen = struct.unpack_from("<II", data, pos + 4)
        pos += 16
        if clen == 0:
            payload = data[pos:pos + ulen]
            pos += ulen
        else:
            raw = data[pos:pos + clen]
            pos += clen
            if raw[:4] == b"\x28\xb5\x2f\xfd":
                raise ValueError("zstd-compressed chunk: install the 'zstandard' module to check it")
            payload = lz4_block(raw, ulen)
        yield name, payload
        if name == b"END\x00":
            break


def read_string(buf, pos):
    (n,) = struct.unpack_from("<I", buf, pos)
    return buf[pos + 4:pos + 4 + n].decode("utf-8", "replace"), pos + 4 + n


def script_props(path):
    """Returns {className: {"count": n, "props": {propName: (typeId, payload)}}}."""
    classes = {}
    by_id = {}
    with open(path, "rb") as fh:
        data = fh.read()
    for name, payload in chunks(data):
        if name == b"INST":
            (class_id,) = struct.unpack_from("<I", payload, 0)
            class_name, p = read_string(payload, 4)
            (count,) = struct.unpack_from("<I", payload, p + 1)
            by_id[class_id] = class_name
            classes[class_name] = {"count": count, "props": {}}
        elif name == b"PROP":
            (class_id,) = struct.unpack_from("<I", payload, 0)
            prop, p = read_string(payload, 4)
            classes[by_id[class_id]]["props"][prop] = (payload[p], payload[p + 1:])
    return classes


def names(entry):
    type_id, values = entry["props"]["Name"]
    out, p = [], 0
    for _ in range(entry["count"]):
        s, p = read_string(values, p)
        out.append(s)
    return out


def disabled_flags(entry):
    if "Disabled" not in entry["props"]:
        return [False] * entry["count"]
    type_id, values = entry["props"]["Disabled"]
    assert type_id == 0x02, "Disabled should be a bool property"
    return [b != 0 for b in values[: entry["count"]]]


def main():
    rojo = sys.argv[1] if len(sys.argv) > 1 else (os.environ.get("ROJO") or shutil.which("rojo") or "tools/rojo")
    errors = []
    tmp = tempfile.mkdtemp()
    try:
        for project, committed in BUILDS:
            fresh = os.path.join(tmp, os.path.basename(committed))
            subprocess.run([rojo, "build", os.path.join(ROOT, project), "-o", fresh], check=True, stdout=subprocess.DEVNULL)
            with open(fresh, "rb") as a, open(os.path.join(ROOT, committed), "rb") as b:
                if a.read() != b.read():
                    errors.append("%s is out of date: run scripts/build.sh" % committed)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    model = script_props(os.path.join(ROOT, "build/StealPokemon_Installer.rbxm"))
    scripts = model.get("Script")
    if not scripts:
        errors.append("installer model has no Script instances")
    else:
        for name, disabled in zip(names(scripts), disabled_flags(scripts)):
            if name == "ServerMain" and not disabled:
                errors.append("installer model: ServerMain is not saved as Disabled")
            print("installer model Script %-12s Disabled=%s" % (name, disabled))

    place = script_props(os.path.join(ROOT, "build/StealPokemon.rbxl"))
    for name, disabled in zip(names(place["Script"]), disabled_flags(place["Script"])):
        if disabled:
            errors.append("place file: Script %s is disabled" % name)
        print("place file      Script %-12s Disabled=%s" % (name, disabled))

    for e in errors:
        print("ERROR:", e)
    if errors:
        sys.exit(1)
    print("Build artifacts OK")


if __name__ == "__main__":
    main()
