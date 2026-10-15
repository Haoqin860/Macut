#!/usr/bin/env python3
"""Audit publishable files without echoing matching sensitive content."""
import argparse
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
RULES = {
    "personal home path": re.compile(rb"/(?:Users|home)/[A-Za-z0-9_.-]+/"),
    "private key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "GitHub credential": re.compile(rb"(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,})"),
    "API credential": re.compile(rb"sk-(?:proj-)?[A-Za-z0-9_-]{24,}"),
    "AWS access key": re.compile(rb"(?:AKIA|ASIA)[A-Z0-9]{16}"),
}
FORBIDDEN_PARTS = {".build", "build", ".codex", ".agents", "Blobs", "private"}
FORBIDDEN_SUFFIXES = {".p12", ".p8", ".key", ".mobileprovision", ".provisionprofile", ".log", ".ips", ".crash", ".sqlite", ".sqlite3", ".db"}
PNG_PRIVATE_CHUNKS = {b"eXIf", b"tEXt", b"zTXt", b"iTXt"}

def source_files(tracked):
    command = ["git", "ls-files", "-z"] if tracked else ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMR", "-z"]
    output = subprocess.check_output(command, cwd=ROOT)
    return [ROOT / item.decode() for item in output.split(b"\0") if item]

def png_has_metadata(data):
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        return False
    offset = 8
    while offset + 12 <= len(data):
        length = int.from_bytes(data[offset:offset+4], "big")
        kind = data[offset+4:offset+8]
        if kind in PNG_PRIVATE_CHUNKS:
            return True
        offset += length + 12
    return False

def jpeg_has_metadata(data):
    if not data.startswith(b"\xff\xd8"):
        return False
    offset = 2
    while offset + 4 <= len(data):
        marker = data[offset+1]
        if marker in (0xDA, 0xD9):
            return False
        if marker in (0xE1, 0xED, 0xFE):
            return True
        offset += 2 + int.from_bytes(data[offset+2:offset+4], "big")
    return False

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--tracked", action="store_true")
    parser.add_argument("--app", type=pathlib.Path)
    args = parser.parse_args()
    files = source_files(args.tracked)
    if not files:
        print("FAIL no publishable files selected")
        return 1
    errors = []
    for path in files:
        relative = path.relative_to(ROOT)
        if set(relative.parts) & FORBIDDEN_PARTS or path.suffix.lower() in FORBIDDEN_SUFFIXES or path.name.startswith(".env") or path.name == "history.json":
            errors.append((str(relative), "excluded file type or directory"))
        if not path.is_file() or path.is_symlink():
            errors.append((str(relative), "missing or non-regular source file"))
            continue
        # Inspect exactly what Git will publish, not a potentially different working copy.
        data = subprocess.check_output(["git", "show", f":{relative.as_posix()}"], cwd=ROOT)
        for label, pattern in RULES.items():
            if pattern.search(data):
                errors.append((str(relative), label))
        if png_has_metadata(data):
            errors.append((str(relative), "PNG text or EXIF metadata requires review"))
        if jpeg_has_metadata(data):
            errors.append((str(relative), "JPEG EXIF or comment metadata requires review"))
    if args.app:
        app = args.app.resolve()
        for path in app.rglob("*"):
            if not path.is_file():
                continue
            relative = "app/" + str(path.relative_to(app))
            data = path.read_bytes()
            for label, pattern in RULES.items():
                if pattern.search(data):
                    errors.append((relative, label))
            if png_has_metadata(data):
                errors.append((relative, "PNG text or EXIF metadata requires review"))
            attributes = subprocess.check_output(["xattr", str(path)], text=True)
            if attributes.strip():
                errors.append((relative, "extended attributes present"))
    for relative, reason in errors:
        print(f"FAIL {relative}: {reason}")
    if errors:
        print(f"{len(errors)} finding(s); no matching content printed")
        return 1
    print(f"PASS privacy patterns and artifact exclusions: {len(files)} source files" + (" and app payload" if args.app else ""))
    return 0

if __name__ == "__main__":
    sys.exit(main())
