#!/usr/bin/env python3
"""Remove non-visual text/EXIF metadata; compressed pixel payloads are unchanged."""
from pathlib import Path
import sys

def sanitize(path):
    data = path.read_bytes()
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        output = bytearray(data[:8])
        offset = 8
        while offset + 12 <= len(data):
            length = int.from_bytes(data[offset:offset+4], "big")
            end = offset + length + 12
            if end > len(data):
                raise ValueError("Invalid PNG chunk")
            if data[offset+4:offset+8] not in {b"eXIf", b"tEXt", b"zTXt", b"iTXt"}:
                output.extend(data[offset:end])
            offset = end
    elif data.startswith(b"\xff\xd8"):
        output = bytearray(data[:2])
        offset = 2
        while offset < len(data):
            if data[offset] != 0xFF:
                raise ValueError("Invalid JPEG marker")
            marker = data[offset+1]
            if marker in (0xDA, 0xD9):
                output.extend(data[offset:])
                break
            length = int.from_bytes(data[offset+2:offset+4], "big")
            end = offset + 2 + length
            if marker not in (0xE1, 0xED, 0xFE):
                output.extend(data[offset:end])
            offset = end
    else:
        raise ValueError("Only PNG and JPEG are supported")
    path.write_bytes(output)
    print(f"Cleaned metadata: {path.name}")

for argument in sys.argv[1:]:
    sanitize(Path(argument))
