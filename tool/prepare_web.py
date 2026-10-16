"""Install pinned browser runtime assets. Models still use llamadart downloads."""
from pathlib import Path
from urllib.request import urlopen
import hashlib
import re

BASE = "https://cdn.jsdelivr.net/gh/leehack/llama-web-bridge-assets@v0.1.59/"
DEST = Path(__file__).resolve().parents[1] / "web" / "runtime"
FILES = {
    "llama_webgpu_bridge.js", "llama_webgpu_bridge_worker.js",
    "llama_webgpu_core.js", "llama_webgpu_core.wasm",
}


def fetch(name):
    with urlopen(BASE + name, timeout=120) as response:
        return response.read()


def prepare(destination=DEST, download=fetch):
    manifest = {}
    for line in download("sha256sums.txt").decode().splitlines():
        parts = line.split()
        if len(parts) != 2:
            continue
        digest, name = parts
        name = name.lstrip("*")
        if name in FILES:
            if name in manifest or not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
                raise ValueError("Invalid checksum entry: " + name)
            manifest[name] = digest.lower()
    if manifest.keys() != FILES:
        raise ValueError("Runtime manifest is missing required files")
    destination.mkdir(parents=True, exist_ok=True)
    for name, digest in sorted(manifest.items()):
        target = destination / name
        if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == digest:
            print("Cached:", name)
            continue
        data = download(name)
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError("Checksum mismatch: " + name)
        temporary = target.with_suffix(target.suffix + ".partial")
        try:
            temporary.write_bytes(data)
            temporary.replace(target)
        finally:
            temporary.unlink(missing_ok=True)
        print("Installed:", name)


if __name__ == "__main__":
    prepare()
