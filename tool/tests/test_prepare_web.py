import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("prepare_web", Path(__file__).parents[1] / "prepare_web.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class RuntimeDownloads(unittest.TestCase):
    def setUp(self):
        self.assets = {name: name.encode() for name in module.FILES}
        self.manifest = "\n".join(f"{hashlib.sha256(data).hexdigest()}  {name}" for name, data in self.assets.items()).encode()
        self.calls = []

    def fetch(self, name):
        self.calls.append(name)
        return self.manifest if name == "sha256sums.txt" else self.assets[name]

    def test_verified_cache_skips_asset_downloads_and_repairs_corruption(self):
        with tempfile.TemporaryDirectory() as temp:
            dest = Path(temp)
            module.prepare(dest, self.fetch)
            self.calls.clear()
            module.prepare(dest, self.fetch)
            self.assertEqual(self.calls, ["sha256sums.txt"])
            name = sorted(module.FILES)[0]
            (dest / name).write_bytes(b"corrupt")
            module.prepare(dest, self.fetch)
            self.assertEqual((dest / name).read_bytes(), self.assets[name])

    def test_missing_manifest_file_fails_before_writing_assets(self):
        self.manifest = self.manifest.split(b"\n")[0]
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, "missing"):
                module.prepare(Path(temp), self.fetch)
            self.assertEqual(list(Path(temp).iterdir()), [])

    def test_bad_download_does_not_overwrite_existing_file(self):
        with tempfile.TemporaryDirectory() as temp:
            dest = Path(temp)
            name = sorted(module.FILES)[0]
            (dest / name).write_bytes(b"previous")
            self.assets[name] = b"bad download"
            with self.assertRaisesRegex(ValueError, "Checksum mismatch"):
                module.prepare(dest, self.fetch)
            self.assertEqual((dest / name).read_bytes(), b"previous")
